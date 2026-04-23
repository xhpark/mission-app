import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'on_device_asr_types.dart';

OnDeviceAsrEngine createOnDeviceAsrEngine() => _SherpaOnnxAsrEngine();

class _SherpaOnnxAsrEngine implements OnDeviceAsrEngine {
  _SherpaOnnxAsrEngine();

  static const _modelDirEnv = String.fromEnvironment('SHERPA_ONNX_MODEL_DIR');
  static const _tokensPathEnv = String.fromEnvironment('SHERPA_ONNX_TOKENS_PATH');
  static const _modelPathEnv = String.fromEnvironment('SHERPA_ONNX_MODEL_PATH');
  static const _encoderPathEnv = String.fromEnvironment('SHERPA_ONNX_ENCODER_PATH');
  static const _decoderPathEnv = String.fromEnvironment('SHERPA_ONNX_DECODER_PATH');
  static const _joinerPathEnv = String.fromEnvironment('SHERPA_ONNX_JOINER_PATH');
  static const _modelTypeEnv = String.fromEnvironment(
    'SHERPA_ONNX_MODEL_TYPE',
    defaultValue: 'zipformer2_ctc',
  );

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

    final modelDir = _modelDirEnv.trim();
    final tokensPath = _tokensPathEnv.trim().isNotEmpty
        ? _tokensPathEnv.trim()
        : (modelDir.isNotEmpty ? '$modelDir/tokens.txt' : '');
    final modelPath = _modelPathEnv.trim().isNotEmpty
        ? _modelPathEnv.trim()
        : (modelDir.isNotEmpty ? '$modelDir/model.onnx' : '');
    final encoderPath = _encoderPathEnv.trim().isNotEmpty
        ? _encoderPathEnv.trim()
        : (modelDir.isNotEmpty ? '$modelDir/encoder-epoch-12-avg-5.int8.onnx' : '');
    final decoderPath = _decoderPathEnv.trim().isNotEmpty
        ? _decoderPathEnv.trim()
        : (modelDir.isNotEmpty ? '$modelDir/decoder-epoch-12-avg-5.onnx' : '');
    final joinerPath = _joinerPathEnv.trim().isNotEmpty
        ? _joinerPathEnv.trim()
        : (modelDir.isNotEmpty ? '$modelDir/joiner-epoch-12-avg-5.int8.onnx' : '');

    if (tokensPath.isEmpty) {
      _unavailableReason = 'model_path_not_configured';
      return null;
    }

    final hasTransducerFiles = encoderPath.isNotEmpty &&
        decoderPath.isNotEmpty &&
        joinerPath.isNotEmpty &&
        File(encoderPath).existsSync() &&
        File(decoderPath).existsSync() &&
        File(joinerPath).existsSync();
    final hasSingleModelFile = modelPath.isNotEmpty && File(modelPath).existsSync();
    final hasTokens = File(tokensPath).existsSync();
    if (!hasTokens || (!hasTransducerFiles && !hasSingleModelFile)) {
      _unavailableReason = 'model_files_not_found';
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
              zipformerCtc: sherpa.OfflineZipformerCtcModelConfig(model: modelPath),
              tokens: tokensPath,
              modelType: _modelTypeEnv,
              numThreads: 2,
              debug: false,
              provider: 'cpu',
            );
      final config = sherpa.OfflineRecognizerConfig(
        model: model,
      );
      _recognizer = sherpa.OfflineRecognizer(config);
      _unavailableReason = null;
      return _recognizer;
    } catch (_) {
      _unavailableReason = 'engine_init_failed';
      return null;
    }
  }
}
