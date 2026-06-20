import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionRuntimeRepository {
  SessionRuntimeRepository(this._functions, this._storage);

  static const _offlineQueueStorageKey = 'speaking.offline_fallback_queue.v1';
  static const _offlineQueueTtl = Duration(days: 7);
  static const _offlineQueueMaxEntries = 100;
  static const _directSpeakingAudioMaxBytes = 3 * 1024 * 1024;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  Future<Map<String, dynamic>> generateReportPreview({
    required String userId,
    required String sessionId,
  }) async {
    final callable = _functions.httpsCallable(
      'generateReportPreview',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    final response = await callable.call(<String, dynamic>{
      'userId': userId,
      'sessionId': sessionId,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> submitChoiceTestItem({
    required String userId,
    required String sessionId,
    required String itemId,
    required int selectedIndex,
    required int correctIndex,
    required int elapsedSeconds,
    String selectedItemId = '',
  }) async {
    final callable = _functions.httpsCallable(
      'submitChoiceTestItem',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    await callable.call(<String, dynamic>{
      'userId': userId,
      'sessionId': sessionId,
      'itemId': itemId,
      // selectedItemId is the authoritative grading signal; the indices are kept
      // for backward compatibility with older deployed functions.
      'selectedItemId': selectedItemId,
      'selectedIndex': selectedIndex,
      'correctIndex': correctIndex,
      'elapsedSeconds': elapsedSeconds,
    });
  }

  Future<void> saveResumeState({
    required String userId,
    required String sessionId,
    required String route,
  }) async {
    final callable = _functions.httpsCallable(
      'saveResumeState',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    await callable.call(<String, dynamic>{
      'userId': userId,
      'sessionId': sessionId,
      'route': route,
    });
  }

  Future<void> discardResumeState({
    required String userId,
    required String sessionId,
  }) async {
    final callable = _functions.httpsCallable(
      'discardResumeState',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    await callable.call(<String, dynamic>{
      'userId': userId,
      'sessionId': sessionId,
    });
  }

  Future<void> abandonStudySession({
    required String userId,
    required String sessionId,
    String reason = 'user_started_new_session',
  }) async {
    final callable = _functions.httpsCallable(
      'abandonStudySession',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    await callable.call(<String, dynamic>{
      'userId': userId,
      'sessionId': sessionId,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> checkWeeklyReportGate({
    required String userId,
  }) async {
    final callable = _functions.httpsCallable(
      'checkWeeklyReportGate',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    final response = await callable.call(<String, dynamic>{'userId': userId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<SpeakingEvaluationResult> evaluateSpeakingAttempt({
    required String userId,
    required String sessionId,
    required String itemId,
    required String expectedText,
    required String mode,
    required Uint8List audioBytes,
    required String mimeType,
    int? durationMs,
  }) async {
    if (audioBytes.length <= _directSpeakingAudioMaxBytes) {
      try {
        return await _callEvaluateSpeakingAttempt(<String, dynamic>{
          'userId': userId,
          'sessionId': sessionId,
          'itemId': itemId,
          'expectedText': expectedText,
          'mode': mode,
          'audioBase64': base64Encode(audioBytes),
          'mimeType': mimeType,
          'durationMs': durationMs ?? 0,
        }, fallbackAudioPath: '');
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'unauthenticated' ||
            error.code == 'permission-denied') {
          rethrow;
        }
        // Older deployed functions may not accept direct audio payloads yet.
        // Fall back to the storage-based path so speaking evaluation still works.
      }
    }

    final objectPath =
        'speaking_attempts/$userId/$sessionId/$itemId-${DateTime.now().millisecondsSinceEpoch}.wav';
    final ref = _storage.ref(objectPath);
    await ref.putData(
      audioBytes,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: <String, String>{
          'userId': userId,
          'sessionId': sessionId,
          'itemId': itemId,
          'mode': mode,
          if (durationMs != null) 'durationMs': '$durationMs',
        },
      ),
    );

    try {
      return await _callEvaluateSpeakingAttempt(<String, dynamic>{
        'userId': userId,
        'sessionId': sessionId,
        'itemId': itemId,
        'expectedText': expectedText,
        'mode': mode,
        'audioPath': objectPath,
        'durationMs': durationMs ?? 0,
      }, fallbackAudioPath: objectPath);
    } catch (_) {
      await ref.delete().catchError((_) {});
      rethrow;
    }
  }

  Future<SpeakingEvaluationResult> _callEvaluateSpeakingAttempt(
    Map<String, dynamic> payload, {
    required String fallbackAudioPath,
  }) async {
    final callable = _functions.httpsCallable(
      'evaluateSpeakingAttempt',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 12)),
    );
    final response = await callable.call(payload);
    final data = Map<String, dynamic>.from(response.data as Map);
    return SpeakingEvaluationResult(
      passed: data['passed'] == true,
      similarityScore: (data['similarityScore'] as num?)?.round(),
      transcript: data['transcript'] as String?,
      errorCode: data['errorCode'] as String?,
      message: data['message'] as String?,
      audioPath: data['audioPath'] as String? ?? fallbackAudioPath,
    );
  }

  Future<SpeakingEvaluationResult> submitOnDeviceSpeakingFallback({
    required String userId,
    required String sessionId,
    required String itemId,
    required String expectedText,
    required String transcript,
    required String mode,
    required String audioPath,
    required String engine,
    int? durationMs,
  }) async {
    final payload = OfflineSpeakingFallbackEntry(
      userId: userId,
      sessionId: sessionId,
      itemId: itemId,
      expectedText: expectedText,
      transcript: transcript,
      mode: mode,
      audioPath: audioPath,
      engine: engine,
      durationMs: durationMs ?? 0,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      return await _submitOnDeviceSpeakingFallbackRemote(payload);
    } on FirebaseFunctionsException catch (error) {
      final shouldQueue =
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'internal';
      if (!shouldQueue) {
        rethrow;
      }
    } on TimeoutException {
      // queue below
    } catch (_) {
      // queue below
    }

    await _enqueueOfflineFallback(payload);
    final similarityScore = _calculateSimilarityScore(expectedText, transcript);
    return SpeakingEvaluationResult(
      passed: similarityScore >= 70,
      similarityScore: similarityScore,
      transcript: transcript,
      errorCode: 'QUEUED_OFFLINE',
      message: '네트워크가 불안정하여 결과를 임시 저장했습니다. 연결 복구 시 자동 동기화됩니다.',
      audioPath: audioPath,
    );
  }

  Future<SpeakingEvaluationResult> _submitOnDeviceSpeakingFallbackRemote(
    OfflineSpeakingFallbackEntry payload,
  ) async {
    final callable = _functions.httpsCallable(
      'submitOnDeviceSpeakingFallback',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );
    final response = await callable.call(<String, dynamic>{
      'userId': payload.userId,
      'sessionId': payload.sessionId,
      'itemId': payload.itemId,
      'expectedText': payload.expectedText,
      'transcript': payload.transcript,
      'mode': payload.mode,
      'audioPath': payload.audioPath,
      'engine': payload.engine,
      'durationMs': payload.durationMs,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return SpeakingEvaluationResult(
      passed: data['passed'] == true,
      similarityScore: (data['similarityScore'] as num?)?.round(),
      transcript: data['transcript'] as String?,
      errorCode: data['errorCode'] as String?,
      message: data['message'] as String?,
      audioPath: payload.audioPath,
    );
  }

  Future<int> queuedSpeakingFallbackCount({String? userId}) async {
    final queue = await _readOfflineQueue(userId: userId);
    return queue.length;
  }

  Future<OfflineFallbackSyncReport> syncQueuedSpeakingFallbacks({
    int maxItems = 20,
    String? userId,
  }) async {
    final allQueue = await _readOfflineQueue(dropExpired: true);
    final targetQueue = userId == null
        ? allQueue
        : allQueue.where((entry) => entry.userId == userId).toList();
    if (targetQueue.isEmpty) {
      return const OfflineFallbackSyncReport(
        synced: 0,
        failed: 0,
        pendingAfterSync: 0,
      );
    }

    final keep = <OfflineSpeakingFallbackEntry>[];
    var synced = 0;
    var failed = 0;
    var processed = 0;
    for (final entry in targetQueue) {
      if (processed >= maxItems) {
        keep.add(entry);
        continue;
      }
      processed += 1;
      try {
        await _submitOnDeviceSpeakingFallbackRemote(entry);
        synced += 1;
      } catch (_) {
        failed += 1;
        keep.add(entry);
      }
    }

    if (userId == null) {
      if (keep.length != allQueue.length) {
        await _writeOfflineQueue(keep);
      }
    } else {
      final untouched = allQueue
          .where((entry) => entry.userId != userId)
          .toList();
      final merged = <OfflineSpeakingFallbackEntry>[...untouched, ...keep];
      if (merged.length != allQueue.length ||
          keep.length != targetQueue.length) {
        await _writeOfflineQueue(merged);
      }
    }

    return OfflineFallbackSyncReport(
      synced: synced,
      failed: failed,
      pendingAfterSync: keep.length,
    );
  }

  Future<void> _enqueueOfflineFallback(
    OfflineSpeakingFallbackEntry payload,
  ) async {
    final queue = await _readOfflineQueue();
    queue.add(payload);
    await _writeOfflineQueue(queue);
  }

  Future<List<OfflineSpeakingFallbackEntry>> _readOfflineQueue({
    String? userId,
    bool dropExpired = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineQueueStorageKey);
    if (raw == null || raw.isEmpty) {
      return <OfflineSpeakingFallbackEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <OfflineSpeakingFallbackEntry>[];
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final queue = decoded
          .whereType<Map>()
          .map((map) => Map<String, dynamic>.from(map))
          .map(OfflineSpeakingFallbackEntry.fromJson)
          .where((entry) => userId == null || entry.userId == userId)
          .where((entry) {
            if (!dropExpired) {
              return true;
            }
            if (entry.createdAtMs <= 0) {
              return true;
            }
            return nowMs - entry.createdAtMs <= _offlineQueueTtl.inMilliseconds;
          })
          .toList();
      return queue;
    } catch (_) {
      return <OfflineSpeakingFallbackEntry>[];
    }
  }

  Future<void> _writeOfflineQueue(
    List<OfflineSpeakingFallbackEntry> queue,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final boundedQueue = _trimOfflineQueue(queue);
    final encoded = jsonEncode(
      boundedQueue.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_offlineQueueStorageKey, encoded);
  }

  static List<OfflineSpeakingFallbackEntry> _trimOfflineQueue(
    List<OfflineSpeakingFallbackEntry> queue,
  ) {
    if (queue.length <= _offlineQueueMaxEntries) {
      return queue;
    }
    return queue.sublist(queue.length - _offlineQueueMaxEntries);
  }

  static int get offlineQueueMaxEntriesForTesting => _offlineQueueMaxEntries;

  static List<OfflineSpeakingFallbackEntry> trimOfflineQueueForTesting(
    List<OfflineSpeakingFallbackEntry> queue,
  ) {
    return _trimOfflineQueue(queue);
  }

  int _calculateSimilarityScore(String expected, String transcript) {
    final normalizedExpected = _normalizeForSimilarity(expected);
    final normalizedTranscript = _normalizeForSimilarity(transcript);
    if (normalizedExpected.isEmpty || normalizedTranscript.isEmpty) {
      return 0;
    }
    final maxLen = normalizedExpected.length > normalizedTranscript.length
        ? normalizedExpected.length
        : normalizedTranscript.length;
    final distance = _levenshteinDistance(
      normalizedExpected,
      normalizedTranscript,
    );
    final ratio = 1 - (distance / maxLen);
    final bounded = ratio < 0 ? 0 : ratio;
    return (bounded * 100).round();
  }

  String _normalizeForSimilarity(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
    return cleaned.trim();
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i += 1) {
      current[0] = i;
      for (var j = 1; j <= b.length; j += 1) {
        final substitutionCost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
            ? 0
            : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + substitutionCost;
        var best = deletion < insertion ? deletion : insertion;
        if (substitution < best) {
          best = substitution;
        }
        current[j] = best;
      }
      for (var j = 0; j <= b.length; j += 1) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }
}

class OfflineSpeakingFallbackEntry {
  const OfflineSpeakingFallbackEntry({
    required this.userId,
    required this.sessionId,
    required this.itemId,
    required this.expectedText,
    required this.transcript,
    required this.mode,
    required this.audioPath,
    required this.engine,
    required this.durationMs,
    required this.createdAtMs,
  });

  final String userId;
  final String sessionId;
  final String itemId;
  final String expectedText;
  final String transcript;
  final String mode;
  final String audioPath;
  final String engine;
  final int durationMs;
  final int createdAtMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'sessionId': sessionId,
      'itemId': itemId,
      'expectedText': expectedText,
      'transcript': transcript,
      'mode': mode,
      'audioPath': audioPath,
      'engine': engine,
      'durationMs': durationMs,
      'createdAtMs': createdAtMs,
    };
  }

  factory OfflineSpeakingFallbackEntry.fromJson(Map<String, dynamic> json) {
    return OfflineSpeakingFallbackEntry(
      userId: json['userId'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      itemId: json['itemId'] as String? ?? '',
      expectedText: json['expectedText'] as String? ?? '',
      transcript: json['transcript'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      audioPath: json['audioPath'] as String? ?? '',
      engine: json['engine'] as String? ?? 'sherpa_onnx',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class OfflineFallbackSyncReport {
  const OfflineFallbackSyncReport({
    required this.synced,
    required this.failed,
    required this.pendingAfterSync,
  });

  final int synced;
  final int failed;
  final int pendingAfterSync;
}

class SpeakingEvaluationResult {
  const SpeakingEvaluationResult({
    required this.passed,
    this.similarityScore,
    this.transcript,
    this.errorCode,
    this.message,
    this.audioPath,
  });

  final bool passed;
  final int? similarityScore;
  final String? transcript;
  final String? errorCode;
  final String? message;
  final String? audioPath;
}
