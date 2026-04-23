import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class RecorderService {
  RecorderService() : _recorder = AudioRecorder();
  static const _sampleRate = 16000;
  static const _channels = 1;
  static const _bitsPerSample = 16;

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _streamSubscription;
  final List<Uint8List> _chunks = <Uint8List>[];
  bool _recording = false;
  DateTime? _startedAt;

  bool get isRecording => _recording;

  Future<void> start() async {
    if (_recording) {
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('MIC_PERMISSION_DENIED');
    }

    _chunks.clear();
    _startedAt = DateTime.now();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channels,
      ),
    );
    _streamSubscription = stream.listen((chunk) {
      _chunks.add(chunk);
    });
    _recording = true;
  }

  Future<RecordedClip?> stop() async {
    if (!_recording) {
      return null;
    }
    await _recorder.stop();
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    _recording = false;
    if (_chunks.isEmpty) {
      return null;
    }

    final rawPcm = _concatChunks(_chunks);
    final wavBytes = _wrapPcmAsWav(
      rawPcm,
      sampleRate: _sampleRate,
      channels: _channels,
      bitsPerSample: _bitsPerSample,
    );
    final floatSamples = _pcm16ToFloat32(rawPcm);
    final startedAt = _startedAt;
    _startedAt = null;
    final durationMs = startedAt == null ? null : DateTime.now().difference(startedAt).inMilliseconds;

    return RecordedClip(
      wavBytes: wavBytes,
      floatSamples: floatSamples,
      sampleRate: _sampleRate,
      mimeType: 'audio/wav',
      durationMs: durationMs,
    );
  }

  Future<void> dispose() async {
    await _streamSubscription?.cancel();
    if (_recording) {
      await _recorder.stop();
    }
    await _recorder.dispose();
  }

  Uint8List _concatChunks(List<Uint8List> chunks) {
    var total = 0;
    for (final chunk in chunks) {
      total += chunk.length;
    }
    final output = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      output.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return output;
  }

  Uint8List _wrapPcmAsWav(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final fileSize = 44 + dataSize;

    final builder = BytesBuilder(copy: false);
    builder.add(_ascii('RIFF'));
    builder.add(_le32(fileSize - 8));
    builder.add(_ascii('WAVE'));
    builder.add(_ascii('fmt '));
    builder.add(_le32(16));
    builder.add(_le16(1));
    builder.add(_le16(channels));
    builder.add(_le32(sampleRate));
    builder.add(_le32(byteRate));
    builder.add(_le16(blockAlign));
    builder.add(_le16(bitsPerSample));
    builder.add(_ascii('data'));
    builder.add(_le32(dataSize));
    builder.add(pcm);

    return builder.toBytes();
  }

  Uint8List _ascii(String value) => Uint8List.fromList(value.codeUnits);

  Uint8List _le16(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Uint8List _le32(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Float32List _pcm16ToFloat32(Uint8List pcm) {
    final sampleCount = pcm.length ~/ 2;
    final out = Float32List(sampleCount);
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(i * 2, Endian.little);
      out[i] = sample / 32768.0;
    }
    return out;
  }
}

class RecordedClip {
  const RecordedClip({
    required this.wavBytes,
    required this.floatSamples,
    required this.sampleRate,
    required this.mimeType,
    this.durationMs,
  });

  final Uint8List wavBytes;
  final Float32List floatSamples;
  final int sampleRate;
  final String mimeType;
  final int? durationMs;
}
