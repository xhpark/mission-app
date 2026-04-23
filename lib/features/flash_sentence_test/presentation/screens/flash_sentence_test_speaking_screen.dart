import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/asr_policy_controller.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/services/on_device_asr_engine.dart';
import '../../../../core/services/on_device_asr_reason.dart';
import '../../../../core/services/on_device_asr_types.dart';
import '../../../../core/services/recorder_service.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashSentenceTestSpeakingScreen extends ConsumerStatefulWidget {
  const FlashSentenceTestSpeakingScreen({super.key});

  @override
  ConsumerState<FlashSentenceTestSpeakingScreen> createState() =>
      _FlashSentenceTestSpeakingScreenState();
}

class _FlashSentenceTestSpeakingScreenState
    extends ConsumerState<FlashSentenceTestSpeakingScreen> {
  late final RecorderService _recorderService;
  late final AudioPlayerService _audioPlayerService;
  late final OnDeviceAsrEngine _onDeviceAsrEngine;

  Uint8List? _recordedWavBytes;
  String? _lastUploadedAudioPath;

  @override
  void initState() {
    super.initState();
    _recorderService = RecorderService();
    _audioPlayerService = AudioPlayerService();
    _onDeviceAsrEngine = createOnDeviceAsrEngine();
  }

  @override
  void dispose() {
    _recorderService.dispose();
    _audioPlayerService.dispose();
    _onDeviceAsrEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final category = session?.category.name ?? 'daily';
    final sentences = sentencesByCategory(category);
    final effectiveTotal = flow.totalItems > 0 && flow.totalItems < sentences.length
        ? flow.totalItems
        : sentences.length;
    final maxIndex = effectiveTotal > 0 ? effectiveTotal - 1 : 0;
    final targetIndexRaw = flow.indexOf(StudyFlowTrack.flashSentenceTestSpeaking);
    final targetIndex = targetIndexRaw > maxIndex ? maxIndex : targetIndexRaw;
    final target = sentenceAt(category, targetIndex);

    return InteractiveLearningScreen(
      title: l10n?.flashSentenceTestSpeakingTitle ??
          'Flash Sentence Test - Speaking',
      subtitle: l10n?.flashSentenceTestSpeakingSubtitle ??
          'Speak quickly and review your score.',
      progress: sentences.isEmpty ? 0 : ((targetIndex + 1) / sentences.length),
      progressLabel: l10n?.flashSentenceTestSpeakingProgressLabel(
            targetIndex + 1,
            sentences.length,
          ) ??
          'Speaking ${targetIndex + 1} / ${sentences.length}',
      promptTitle:
          l10n?.flashSentenceTestSpeakingPromptTitle ?? 'Speaking Prompt',
      foreignText: target.thaiText,
      nativeText: target.koreanText,
      pronunciation: '${target.phonetic} / ${target.hangulPronunciation}',
      hint: target.cultureNote,
      showMicSection: true,
      showAudioSection: true,
      requireSpeakingScoreValidation: true,
      primaryButtonLabel:
          l10n?.flashSentenceTestSpeakingPrimaryButton ?? 'Done',
      primaryRoute: '/session-summary',
      showBackButton: true,
      backFallbackRoute: '/flash-sentence-test/choice',
      timeLimitSeconds: 50,
      onPlayPromptAudio: () => _audioPlayerService.playAsset(target.audioPath),
      onPlayMyRecording: () async {
        final bytes = _recordedWavBytes;
        if (bytes == null) {
          return;
        }
        await _audioPlayerService.playWavBytes(bytes);
      },
      onStartRecording: () async {
        await _recorderService.start();
      },
      onStopRecordingAndValidate: () async {
        final clip = await _recorderService.stop();
        if (clip == null) {
          return SpeakingValidationResult(
            hasRecording: false,
            passed: false,
            message: l10n?.speakingNoRecordingData ??
                'No recording data. Please try again.',
          );
        }
        _recordedWavBytes = clip.wavBytes;

        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: true,
            message: l10n?.speakingDevModePass ??
                'In development mode, this is marked as completed.',
          );
        }

        final asrPolicy = ref.read(asrPolicyProvider);
        if (!asrPolicy.decided) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message: l10n?.speakingSelectAsrPolicyFirst ??
                'Select ASR policy from learning selection first.',
            errorCode: 'ASR_POLICY_NOT_DECIDED',
          );
        }

        final repo = ref.read(sessionRuntimeRepositoryProvider);
        try {
          final cloudResult = await repo.evaluateSpeakingAttempt(
            userId: user.uid,
            sessionId: session.sessionId,
            itemId: target.id,
            expectedText: target.thaiText,
            mode: 'flash_sentence_test_speaking',
            audioBytes: clip.wavBytes,
            mimeType: clip.mimeType,
            durationMs: clip.durationMs,
          );
          _lastUploadedAudioPath = cloudResult.audioPath;

          final hasServerTranscript =
              cloudResult.transcript != null && cloudResult.transcript!.trim().isNotEmpty;
          final mustFallback =
              cloudResult.errorCode == 'STT_UNAVAILABLE' || !hasServerTranscript;
          if (!mustFallback) {
            return SpeakingValidationResult(
              hasRecording: true,
              passed: cloudResult.passed,
              similarityScore: cloudResult.similarityScore,
              transcript: cloudResult.transcript,
              message: cloudResult.message ??
                  (cloudResult.passed
                      ? (l10n?.interactiveSpeakingPassed ??
                          'Speaking validation passed.')
                      : (l10n?.interactiveSpeakingFailed ??
                          'Speaking validation did not pass.')),
              errorCode: cloudResult.errorCode,
            );
          }

          if (!asrPolicy.allowOnDeviceFallback) {
            return SpeakingValidationResult(
              hasRecording: true,
              passed: false,
              message: l10n?.speakingServerOnlyRequiresNetwork ??
                  'Server STT only mode. Connect network and try again.',
              errorCode: 'NETWORK_REQUIRED_SERVER_ONLY',
            );
          }
        } catch (_) {
          if (!asrPolicy.allowOnDeviceFallback) {
            return SpeakingValidationResult(
              hasRecording: true,
              passed: false,
              message: l10n?.speakingNetworkOrServerFailed ??
                  'Could not evaluate speech due to network/server issue.',
              errorCode: 'NETWORK_REQUIRED_SERVER_ONLY',
            );
          }
        }

        final onDeviceResult = await _onDeviceAsrEngine.transcribeThai(
          samples: clip.floatSamples,
          sampleRate: clip.sampleRate,
        );
        if (onDeviceResult == null || onDeviceResult.transcript.trim().isEmpty) {
          final reason = onDeviceAsrReasonToKorean(_onDeviceAsrEngine.unavailableReason);
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message: l10n?.speakingServerAndOnDeviceUnavailable(reason) ??
                'Server and on-device ASR are unavailable. $reason',
            errorCode: _onDeviceAsrEngine.unavailableReason ?? 'ON_DEVICE_ASR_UNAVAILABLE',
          );
        }

        try {
          final fallbackSaved = await repo.submitOnDeviceSpeakingFallback(
            userId: user.uid,
            sessionId: session.sessionId,
            itemId: target.id,
            expectedText: target.thaiText,
            transcript: onDeviceResult.transcript,
            mode: 'flash_sentence_test_speaking',
            audioPath: _lastUploadedAudioPath ?? '',
            engine: onDeviceResult.engine,
            durationMs: clip.durationMs,
          );
          if (fallbackSaved.errorCode == 'QUEUED_OFFLINE') {
            ref.read(speakingFallbackSyncWorkerProvider.notifier).refreshPendingCount();
          }
          return SpeakingValidationResult(
            hasRecording: true,
            passed: fallbackSaved.passed,
            similarityScore: fallbackSaved.similarityScore,
            transcript: fallbackSaved.transcript,
            message: fallbackSaved.message ??
                (l10n?.speakingOnDeviceSaved ?? 'Processed by on-device ASR.'),
            errorCode: fallbackSaved.errorCode,
          );
        } catch (_) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message: l10n?.speakingOnDeviceSaveFailed ??
                'Failed to save on-device result. Try again.',
            errorCode: 'ON_DEVICE_SAVE_FAILED',
          );
        }
      },
      onScreenOpened: () async {
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return;
        }
        await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: '/flash-sentence-test/speaking',
            );
      },
      onPrimaryAction: (_) async {
        final hasNext = ref.read(studyFlowControllerProvider.notifier).advanceTrack(
              track: StudyFlowTrack.flashSentenceTestSpeaking,
              totalCount: effectiveTotal,
            );
        if (session == null || user == null || user.isAnonymous || developmentSession) {
          return hasNext ? '/flash-sentence-test/speaking' : '/session-summary';
        }
        if (hasNext) {
          await ref.read(sessionRuntimeRepositoryProvider).saveResumeState(
                userId: user.uid,
                sessionId: session.sessionId,
                route: '/flash-sentence-test/speaking',
              );
        } else {
          await ref.read(sessionRuntimeRepositoryProvider).discardResumeState(
                userId: user.uid,
                sessionId: session.sessionId,
              );
        }
        return hasNext ? '/flash-sentence-test/speaking' : '/session-summary';
      },
    );
  }
}
