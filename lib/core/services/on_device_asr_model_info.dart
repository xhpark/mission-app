/// Single source of truth for the on-device ASR model identity, shared by
/// the inference engine (on_device_asr_engine_sherpa.dart, which looks for
/// the files on disk) and the downloader (on_device_asr_model_downloader.dart,
/// which fetches them from Firebase Storage into the same location).
class OnDeviceAsrModelInfo {
  const OnDeviceAsrModelInfo._();

  /// Must match the `model.version` content the engine checks for, and the
  /// Storage path the model was uploaded to via scripts/upload_asr_model.py.
  static const modelVersion = String.fromEnvironment(
    'SHERPA_ONNX_MODEL_VERSION',
    defaultValue: 'sherpa-onnx-zipformer-thai-2024-06-20-int8',
  );

  /// Relative path under the app's external files dir, matching the engine's
  /// `_defaultModelDirs()`.
  static const localRelativeDir = 'sherpa-onnx/sherpa-th/active-int8';

  /// Storage prefix the model files live under (see upload_asr_model.py).
  static String storagePrefix(String version) => 'asr_models/$version';

  static const requiredFiles = <String>[
    'tokens.txt',
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
  ];

  static const modelVersionFileName = 'model.version';
  static const manifestFileName = 'manifest.json';

  /// Approximate total size for the consent dialog. The authoritative size
  /// (used for the actual progress bar) comes from manifest.json at download
  /// time; this is only a fallback if the manifest fetch fails before the
  /// user has even decided whether to proceed.
  static const approxTotalBytes = 157052569;
}
