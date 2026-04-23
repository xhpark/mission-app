import 'on_device_asr_engine_stub.dart'
    if (dart.library.io) 'on_device_asr_engine_sherpa.dart' as impl;
import 'on_device_asr_types.dart';

OnDeviceAsrEngine createOnDeviceAsrEngine() => impl.createOnDeviceAsrEngine();
