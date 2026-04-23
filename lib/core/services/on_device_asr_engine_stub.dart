import 'dart:typed_data';

import 'on_device_asr_types.dart';

OnDeviceAsrEngine createOnDeviceAsrEngine() => const _UnavailableOnDeviceAsrEngine();

class _UnavailableOnDeviceAsrEngine implements OnDeviceAsrEngine {
  const _UnavailableOnDeviceAsrEngine();

  @override
  bool get isSupported => false;

  @override
  String? get unavailableReason => 'unsupported_platform';

  @override
  Future<OnDeviceAsrResult?> transcribeThai({
    required Float32List samples,
    required int sampleRate,
  }) async {
    return null;
  }

  @override
  Future<void> dispose() async {}
}
