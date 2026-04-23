import 'dart:typed_data';

class OnDeviceAsrResult {
  const OnDeviceAsrResult({
    required this.transcript,
    this.engine = 'sherpa_onnx',
  });

  final String transcript;
  final String engine;
}

abstract class OnDeviceAsrEngine {
  bool get isSupported;
  String? get unavailableReason;

  Future<OnDeviceAsrResult?> transcribeThai({
    required Float32List samples,
    required int sampleRate,
  });

  Future<void> dispose();
}
