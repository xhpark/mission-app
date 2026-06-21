import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'on_device_asr_types.dart';

OnDeviceAsrEngine createOnDeviceAsrEngine() => _SherpaOnnxAsrEngine();

class _SherpaOnnxAsrEngine implements OnDeviceAsrEngine {
  _SherpaOnnxAsrEngine();

  static const _androidPackageName = 'com.thaimission.app';
  static const _modelDirEnv = String.fromEnvironment('SHERPA_ONNX_MODEL_DIR');
  static const _tokensPathEnv = String.fromEnvironment(
    'SHERPA_ONNX_TOKENS_PATH',
  );
  static const _modelPathEnv = String.fromEnvironment('SHERPA_ONNX_MODEL_PATH');
  static const _encoderPathEnv = String.fromEnvironment(
    'SHERPA_ONNX_ENCODER_PATH',
  );
  static const _decoderPathEnv = String.fromEnvironment(
    'SHERPA_ONNX_DECODER_PATH',
  );
  static const _joinerPathEnv = String.fromEnvironment(
    'SHERPA_ONNX_JOINER_PATH',
  );
  static const _modelTypeEnv = String.fromEnvironment(
    'SHERPA_ONNX_MODEL_TYPE',
    defaultValue: 'zipformer2_ctc',
  );
  static const _requiredModelVersionEnv = String.fromEnvironment(
    'SHERPA_ONNX_MODEL_VERSION',
    defaultValue: 'sherpa-onnx-zipformer-thai-2024-06-20-int8',
  );
  static const _requireModelVersionEnv = bool.fromEnvironment(
    'SHERPA_ONNX_REQUIRE_MODEL_VERSION',
    defaultValue: false,
  );
  static const _modelVersionFileName = 'model.version';

  sherpa.OfflineRecognizer? _recognizer;
  String? _unavailableReason;

  @override
  bool get isSupported => _unavailableReason == null;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  Future<OnDeviceAsrResult?> transcribeThai({
    required Float32List samples,
    required int sampleRate,
  }) async {
    final recognizer = await _ensureRecognizer();
    if (recognizer == null) {
      return null;
    }

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      if (text.isEmpty) {
        return null;
      }
      return OnDeviceAsrResult(transcript: text, engine: 'sherpa_onnx');
    } finally {
      stream.free();
    }
  }

  @override
  Future<void> dispose() async {
    _recognizer?.free();
    _recognizer = null;
  }

  Future<sherpa.OfflineRecognizer?> _ensureRecognizer() async {
    if (_recognizer != null) {
      return _recognizer;
    }
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isLinux &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      _unavailableReason = 'unsupported_platform';
      return null;
    }

    final resolvedModel = _resolveModelFiles();
    final tokensPath = resolvedModel.tokensPath;
    final modelPath = resolvedModel.modelPath;
    final encoderPath = resolvedModel.encoderPath;
    final decoderPath = resolvedModel.decoderPath;
    final joinerPath = resolvedModel.joinerPath;

    if (tokensPath.isEmpty) {
      _unavailableReason = 'model_path_not_configured';
      return null;
    }

    final hasTransducerFiles =
        encoderPath.isNotEmpty &&
        decoderPath.isNotEmpty &&
        joinerPath.isNotEmpty &&
        File(encoderPath).existsSync() &&
        File(decoderPath).existsSync() &&
        File(joinerPath).existsSync();
    final hasSingleModelFile =
        modelPath.isNotEmpty && File(modelPath).existsSync();
    final hasTokens = File(tokensPath).existsSync();
    if (!hasTokens || (!hasTransducerFiles && !hasSingleModelFile)) {
      _unavailableReason = 'model_files_not_found';
      return null;
    }
    if (!_isModelVersionCurrent(resolvedModel)) {
      _unavailableReason = 'model_update_required';
      return null;
    }

    try {
      sherpa.initBindings();
      final model = hasTransducerFiles
          ? sherpa.OfflineModelConfig(
              transducer: sherpa.OfflineTransducerModelConfig(
                encoder: encoderPath,
                decoder: decoderPath,
                joiner: joinerPath,
              ),
              tokens: tokensPath,
              numThreads: 2,
              debug: false,
              provider: 'cpu',
            )
          : sherpa.OfflineModelConfig(
              zipformerCtc: sherpa.OfflineZipformerCtcModelConfig(
                model: modelPath,
              ),
              tokens: tokensPath,
              modelType: _modelTypeEnv,
              numThreads: 2,
              debug: false,
              provider: 'cpu',
            );
      final config = sherpa.OfflineRecognizerConfig(model: model);
      _recognizer = sherpa.OfflineRecognizer(config);
      _unavailableReason = null;
      return _recognizer;
    } catch (_) {
      _unavailableReason = 'engine_init_failed';
      return null;
    }
  }

  _ResolvedSherpaModel _resolveModelFiles() {
    final explicitDir = _modelDirEnv.trim();
    final modelDirs = <String>[
      if (explicitDir.isNotEmpty) explicitDir,
      ..._defaultModelDirs(),
    ];

    for (final dir in modelDirs) {
      final resolved = _resolveFromDir(dir);
      if (resolved.hasRequiredFiles) {
        return resolved;
      }
    }

    if (modelDirs.isNotEmpty) {
      return _resolveFromDir(modelDirs.first);
    }

    return const _ResolvedSherpaModel();
  }

  List<String> _defaultModelDirs() {
    if (Platform.isAndroid) {
      const relative = 'sherpa-onnx/sherpa-th/active-int8';
      return const [
        '/storage/emulated/0/Android/data/$_androidPackageName/files/$relative',
        '/sdcard/Android/data/$_androidPackageName/files/$relative',
      ];
    }
    if (Platform.isWindows) {
      return const ['D:/AI/sherpa-onnx/sherpa-th/active-int8'];
    }
    return const [];
  }

  _ResolvedSherpaModel _resolveFromDir(String dir) {
    if (dir.isEmpty) {
      return const _ResolvedSherpaModel();
    }

    final tokensPath = _firstExistingPath([
      _tokensPathEnv.trim(),
      '$dir/tokens.txt',
    ]);
    final modelPath = _firstExistingPath([
      _modelPathEnv.trim(),
      '$dir/model.onnx',
    ]);
    final encoderPath = _firstExistingPath([
      _encoderPathEnv.trim(),
      '$dir/encoder.int8.onnx',
      '$dir/encoder-epoch-12-avg-5.int8.onnx',
      '$dir/encoder.onnx',
    ]);
    final decoderPath = _firstExistingPath([
      _decoderPathEnv.trim(),
      '$dir/decoder.int8.onnx',
      '$dir/decoder-epoch-12-avg-5.onnx',
      '$dir/decoder.onnx',
    ]);
    final joinerPath = _firstExistingPath([
      _joinerPathEnv.trim(),
      '$dir/joiner.int8.onnx',
      '$dir/joiner-epoch-12-avg-5.int8.onnx',
      '$dir/joiner.onnx',
    ]);

    return _ResolvedSherpaModel(
      modelDir: dir,
      tokensPath: tokensPath,
      modelPath: modelPath,
      encoderPath: encoderPath,
      decoderPath: decoderPath,
      joinerPath: joinerPath,
    );
  }

  bool _isModelVersionCurrent(_ResolvedSherpaModel resolvedModel) {
    final requiredVersion = _requiredModelVersionEnv.trim();
    if (requiredVersion.isEmpty || resolvedModel.modelDir.isEmpty) {
      return true;
    }

    final versionFile = File(
      '${resolvedModel.modelDir}/$_modelVersionFileName',
    );
    if (!versionFile.existsSync()) {
      // Keep manually installed legacy models working unless the build
      // explicitly requires version enforcement.
      return !_requireModelVersionEnv;
    }

    final installedVersion = versionFile.readAsStringSync().trim();
    return installedVersion == requiredVersion;
  }

  String _firstExistingPath(List<String> candidates) {
    final normalized = candidates
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    for (final path in normalized) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return normalized.firstOrNull ?? '';
  }
}

class _ResolvedSherpaModel {
  const _ResolvedSherpaModel({
    this.modelDir = '',
    this.tokensPath = '',
    this.modelPath = '',
    this.encoderPath = '',
    this.decoderPath = '',
    this.joinerPath = '',
  });

  final String modelDir;
  final String tokensPath;
  final String modelPath;
  final String encoderPath;
  final String decoderPath;
  final String joinerPath;

  bool get hasTokens => tokensPath.isNotEmpty && File(tokensPath).existsSync();

  bool get hasTransducerFiles =>
      encoderPath.isNotEmpty &&
      decoderPath.isNotEmpty &&
      joinerPath.isNotEmpty &&
      File(encoderPath).existsSync() &&
      File(decoderPath).existsSync() &&
      File(joinerPath).existsSync();

  bool get hasSingleModelFile =>
      modelPath.isNotEmpty && File(modelPath).existsSync();

  bool get hasRequiredFiles =>
      hasTokens && (hasTransducerFiles || hasSingleModelFile);
}
