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
    final dataUri = Uri.dataFromBytes(bytes, mimeType: 'audio/wav');
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
}
