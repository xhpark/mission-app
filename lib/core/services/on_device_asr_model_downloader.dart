import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'on_device_asr_model_info.dart';

sealed class AsrModelDownloadProgress {
  const AsrModelDownloadProgress();
}

class AsrModelDownloadCheckingWifi extends AsrModelDownloadProgress {
  const AsrModelDownloadCheckingWifi();
}

class AsrModelDownloadFetchingManifest extends AsrModelDownloadProgress {
  const AsrModelDownloadFetchingManifest();
}

class AsrModelDownloadInProgress extends AsrModelDownloadProgress {
  const AsrModelDownloadInProgress({
    required this.currentFile,
    required this.fileIndex,
    required this.fileCount,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final String currentFile;
  final int fileIndex;
  final int fileCount;
  final int receivedBytes;
  final int totalBytes;

  double get fraction => totalBytes <= 0 ? 0 : receivedBytes / totalBytes;
}

class AsrModelDownloadVerifying extends AsrModelDownloadProgress {
  const AsrModelDownloadVerifying();
}

class AsrModelDownloadCompleted extends AsrModelDownloadProgress {
  const AsrModelDownloadCompleted();
}

enum AsrModelDownloadFailureReason {
  wifiRequired,
  manifestUnavailable,
  checksumMismatch,
  storageFull,
  networkError,
  cancelled,
}

class AsrModelDownloadFailed extends AsrModelDownloadProgress {
  const AsrModelDownloadFailed(this.reason);

  final AsrModelDownloadFailureReason reason;
}

/// Downloads the on-device ASR model bundle from Firebase Storage into the
/// same on-disk location `on_device_asr_engine_sherpa.dart` already looks
/// for it in, gated to Wi-Fi. The model (~150MB) is never bundled into the
/// app build — see docs_content_update_checklist_2026-06-22.md for why.
class OnDeviceAsrModelDownloader {
  const OnDeviceAsrModelDownloader();

  static const _maxAttemptsPerFile = 3;

  Future<bool> isWifiConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  Future<bool> isModelInstalled() async {
    final dir = await _modelDir();
    for (final name in OnDeviceAsrModelInfo.requiredFiles) {
      if (!File('${dir.path}/$name').existsSync()) {
        return false;
      }
    }
    return true;
  }

  Stream<AsrModelDownloadProgress> download({bool requireWifi = true}) async* {
    if (requireWifi) {
      yield const AsrModelDownloadCheckingWifi();
      if (!await isWifiConnected()) {
        yield const AsrModelDownloadFailed(AsrModelDownloadFailureReason.wifiRequired);
        return;
      }
    }

    yield const AsrModelDownloadFetchingManifest();
    final manifest = await _fetchManifest();
    if (manifest == null) {
      yield const AsrModelDownloadFailed(AsrModelDownloadFailureReason.manifestUnavailable);
      return;
    }

    final dir = await _modelDir();
    await dir.create(recursive: true);
    final tmpDir = Directory('${dir.path}.download_tmp');
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
    await tmpDir.create(recursive: true);

    final files = manifest.files;
    final totalBytes = manifest.totalBytes;
    var completedBytes = 0;

    for (var i = 0; i < files.length; i++) {
      final fileMeta = files[i];
      final targetTmpFile = File('${tmpDir.path}/${fileMeta.name}');
      final baseCompletedBytes = completedBytes;
      var attempt = 0;
      var success = false;
      while (attempt < _maxAttemptsPerFile && !success) {
        attempt++;
        try {
          final task = FirebaseStorage.instance
              .ref('${OnDeviceAsrModelInfo.storagePrefix(OnDeviceAsrModelInfo.modelVersion)}/${fileMeta.name}')
              .writeToFile(targetTmpFile);
          // Let snapshotEvents close on its own (it does so once the task
          // reaches a terminal state). Breaking out of this loop early
          // cancels the underlying StreamSubscription, which firebase_storage
          // interprets as a user-initiated task cancellation — observed to
          // deadlock the subsequent `await task` when the task had already
          // succeeded by the time the break fired.
          await for (final snapshot in task.snapshotEvents) {
            yield AsrModelDownloadInProgress(
              currentFile: fileMeta.name,
              fileIndex: i + 1,
              fileCount: files.length,
              receivedBytes: baseCompletedBytes + snapshot.bytesTransferred,
              totalBytes: totalBytes,
            );
          }
          await task;
          if (!_verifyChecksum(targetTmpFile, fileMeta.sha256)) {
            throw const _ChecksumMismatchException();
          }
          success = true;
        } on _ChecksumMismatchException {
          if (attempt >= _maxAttemptsPerFile) {
            yield const AsrModelDownloadFailed(AsrModelDownloadFailureReason.checksumMismatch);
            await _safeDelete(tmpDir);
            return;
          }
        } on FileSystemException {
          yield const AsrModelDownloadFailed(AsrModelDownloadFailureReason.storageFull);
          await _safeDelete(tmpDir);
          return;
        } catch (_) {
          if (attempt >= _maxAttemptsPerFile) {
            yield const AsrModelDownloadFailed(AsrModelDownloadFailureReason.networkError);
            await _safeDelete(tmpDir);
            return;
          }
        }
      }
      completedBytes += fileMeta.size;
    }

    yield const AsrModelDownloadVerifying();

    // Atomically replace: move each verified file from tmp into the final
    // dir, then write model.version last so a half-written install can never
    // be mistaken for a complete, current one by the engine's version check.
    for (final fileMeta in files) {
      final src = File('${tmpDir.path}/${fileMeta.name}');
      final dst = File('${dir.path}/${fileMeta.name}');
      if (dst.existsSync()) {
        await dst.delete();
      }
      await src.rename(dst.path);
    }
    await File('${dir.path}/${OnDeviceAsrModelInfo.modelVersionFileName}')
        .writeAsString(manifest.modelVersion);
    await _safeDelete(tmpDir);

    yield const AsrModelDownloadCompleted();
  }

  bool _verifyChecksum(File file, String expectedSha256) {
    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes).toString();
    return digest == expectedSha256;
  }

  Future<_ModelManifest?> _fetchManifest() async {
    try {
      final ref = FirebaseStorage.instance.ref(
        '${OnDeviceAsrModelInfo.storagePrefix(OnDeviceAsrModelInfo.modelVersion)}/'
        '${OnDeviceAsrModelInfo.manifestFileName}',
      );
      final bytes = await ref.getData(2 * 1024 * 1024);
      if (bytes == null) {
        return null;
      }
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return _ModelManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _modelDir() async {
    final base = await getExternalStorageDirectory();
    final basePath = base?.path ?? (await getApplicationSupportDirectory()).path;
    return Directory('$basePath/${OnDeviceAsrModelInfo.localRelativeDir}');
  }

  Future<void> _safeDelete(Directory dir) async {
    try {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}

class _ChecksumMismatchException implements Exception {
  const _ChecksumMismatchException();
}

class _ModelFileMeta {
  const _ModelFileMeta({required this.name, required this.size, required this.sha256});

  final String name;
  final int size;
  final String sha256;

  factory _ModelFileMeta.fromJson(Map<String, dynamic> json) => _ModelFileMeta(
    name: json['name'] as String,
    size: json['size'] as int,
    sha256: json['sha256'] as String,
  );
}

class _ModelManifest {
  const _ModelManifest({required this.modelVersion, required this.files, required this.totalBytes});

  final String modelVersion;
  final List<_ModelFileMeta> files;
  final int totalBytes;

  factory _ModelManifest.fromJson(Map<String, dynamic> json) => _ModelManifest(
    modelVersion: json['modelVersion'] as String,
    files: (json['files'] as List<dynamic>)
        .map((e) => _ModelFileMeta.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalBytes: json['totalBytes'] as int,
  );
}
