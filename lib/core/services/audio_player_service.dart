import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  AudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;

  Future<void> playAsset(String assetPath) async {
    if (assetPath.isEmpty) {
      return;
    }
    final normalized = _normalizeAssetPath(assetPath);
    await _player.stop();
    await _player.setAsset(normalized);
    await _player.play();
  }

  Future<void> playUrl(String url) async {
    if (url.isEmpty) {
      return;
    }
    await _player.stop();
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> playWavBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return;
    }
    await _player.stop();
    await _player.setVolume(1.0);
    final boosted = _boostRecordedWavPcm16(bytes, gain: 1.8);
    final dataUri = Uri.dataFromBytes(boosted, mimeType: 'audio/wav');
    await _player.setAudioSource(AudioSource.uri(dataUri));
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  String _normalizeAssetPath(String path) {
    if (path.startsWith('assets/')) {
      return path;
    }
    return 'assets/$path';
  }

  Uint8List _boostRecordedWavPcm16(Uint8List bytes, {required double gain}) {
    if (bytes.length < 44 || gain <= 1.0) {
      return bytes;
    }
    final out = Uint8List.fromList(bytes);
    final data = ByteData.sublistView(out);

    final isPcm = data.getUint16(20, Endian.little) == 1;
    final bitsPerSample = data.getUint16(34, Endian.little);
    if (!isPcm || bitsPerSample != 16) {
      return out;
    }

    final dataOffset = _findWavDataOffset(out);
    if (dataOffset < 0 || dataOffset + 1 >= out.length) {
      return out;
    }

    final sampleCount = (out.length - dataOffset) ~/ 2;
    for (var i = 0; i < sampleCount; i++) {
      final offset = dataOffset + (i * 2);
      final sample = data.getInt16(offset, Endian.little);
      final boosted = (sample * gain).round().clamp(-32768, 32767);
      data.setInt16(offset, boosted, Endian.little);
    }
    return out;
  }

  int _findWavDataOffset(Uint8List wav) {
    if (wav.length < 44) {
      return -1;
    }

    var cursor = 12;
    while (cursor + 8 <= wav.length) {
      final id0 = wav[cursor];
      final id1 = wav[cursor + 1];
      final id2 = wav[cursor + 2];
      final id3 = wav[cursor + 3];
      final size = ByteData.sublistView(wav, cursor + 4, cursor + 8)
          .getUint32(0, Endian.little);
      final chunkDataStart = cursor + 8;
      if (id0 == 0x64 && id1 == 0x61 && id2 == 0x74 && id3 == 0x61) {
        return chunkDataStart;
      }
      cursor = chunkDataStart + size;
      if (cursor.isOdd) {
        cursor += 1;
      }
    }
    return -1;
  }
}
