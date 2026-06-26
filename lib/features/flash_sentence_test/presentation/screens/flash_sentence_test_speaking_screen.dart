import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/asr_policy_controller.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/services/on_device_asr_engine.dart';
import '../../../../core/services/on_device_asr_reason.dart';
import '../../../../core/services/on_device_asr_types.dart';
import '../../../../core/services/recorder_service.dart';
import '../../../../core/widgets/interactive_learning_screen.dart';
import '../../../../core/widgets/learning_action_styles.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/domain/learning_selection_labels.dart'
    as labels;
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/domain/test_item_order.dart';
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
  RecorderService? _recorderService;
  AudioPlayerService? _audioPlayerService;
  OnDeviceAsrEngine? _onDeviceAsrEngine;

  Uint8List? _recordedWavBytes;
  RecordedClip? _recordedClip;
  String? _lastUploadedAudioPath;
  int _retryEpoch = 0;
  String? _hintRevealedItemId;
  String? _activeItemId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _recorderService?.dispose();
    _audioPlayerService?.dispose();
    _onDeviceAsrEngine?.dispose();
    super.dispose();
  }

  RecorderService get _recorder {
    return _recorderService ??= RecorderService();
  }

  AudioPlayerService get _audioPlayer {
    return _audioPlayerService ??= AudioPlayerService();
  }

  OnDeviceAsrEngine get _onDeviceAsr {
    return _onDeviceAsrEngine ??= createOnDeviceAsrEngine();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final developmentSession = ref.watch(developmentSessionProvider);
    final shouldUseServer =
        session != null &&
        user != null &&
        !user.isAnonymous &&
        !developmentSession;
    final flow = ref.watch(studyFlowControllerProvider);
    final category = session?.category.name ?? 'daily';
    final sentences = sentencesByCategory(category);
    final effectiveTotal =
        flow.totalItems > 0 && flow.totalItems < sentences.length
        ? flow.totalItems
        : sentences.length;
    final maxIndex = effectiveTotal > 0 ? effectiveTotal - 1 : 0;
    final targetIndexRaw = flow.indexOf(
      StudyFlowTrack.flashSentenceTestSpeaking,
    );
    final displayIndex = targetIndexRaw > maxIndex ? maxIndex : targetIndexRaw;
    final targetIndex = resolveTestContentIndex(
      displayIndex: displayIndex,
      itemCount: effectiveTotal,
      levelName: session?.level.name,
      seedKey: session?.sessionId ?? 'dev',
      orderKey: 'flash-sentence-test',
    );
    final target = sentenceAt(category, targetIndex);
    final overallLimitSeconds = switch (session?.level.name ?? 'beginner') {
      'intermediate' => 30,
      'advanced' => 20,
      _ => 40,
    };
    final speakingLimitSeconds = switch (session?.level.name ?? 'beginner') {
      'intermediate' => 8,
      'advanced' => 4,
      _ => 12,
    };
    _syncItemState(target.id);
    final hintRevealed = _hintRevealedItemId == target.id;

    return InteractiveLearningScreen(
      key: ValueKey(
        'flash-sentence-test-speaking-$displayIndex-$targetIndex-$_retryEpoch',
      ),
      selectionSummaryLabels: session == null || l10n == null
          ? null
          : [
              labels.categoryLabel(session.category, l10n),
              labels.levelLabel(session.level, l10n),
              labels.modeLabel(session.mode, l10n),
            ],
      title:
          l10n?.flashSentenceTestSpeakingTitle ??
          'Flash Sentence Test - Speaking',
      subtitle:
          l10n?.flashSentenceTestSpeakingSubtitle ??
          'Speak quickly and review your score.',
      progress: effectiveTotal <= 0 ? 0 : ((displayIndex + 1) / effectiveTotal),
      progressLabel:
          l10n?.flashSentenceTestSpeakingProgressLabel(
            displayIndex + 1,
            effectiveTotal,
          ) ??
          'Speaking ${displayIndex + 1} / $effectiveTotal',
      promptTitle: '말하기 제시문',
      foreignText: target.thaiText,
      nativeText: target.koreanText,
      pronunciation: '${target.phonetic} / ${target.hangulPronunciation}',
      hint: formatThaiTokensForLearners(target.cultureNote),
      showPromptDescription: false,
      promptSupportContent: hintRevealed
          ? null
          : OutlinedButton.icon(
              onPressed: () async {
                setState(() => _hintRevealedItemId = target.id);
                await _audioPlayer.playAsset(target.audioPath);
              },
              style: LearningActionStyles.prominentOutlined(context),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text.rich(
                TextSpan(
                  text: '잘 모르겠으면 ',
                  children: [
                    TextSpan(
                      text: '여기',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize:
                            (Theme.of(
                                  context,
                                ).textTheme.titleMedium?.fontSize ??
                                16) +
                            2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '에서 "힌트"를 확인해 보세요'),
                  ],
                ),
              ),
            ),
      showPromptInfoChips: hintRevealed,
      showHintInfoChip: false,
      showProgressAtBottom: true,
      showMicSection: true,
      showAudioSection: hintRevealed,
      requireSpeakingScoreValidation: false,
      recordStartLabel: '말하기 테스트 시작',
      recordStopLabel: '녹음 중지',
      recordingGuidanceIdleText: '제한 시간 안에 녹음하세요',
      recordingTimeLimitSeconds: speakingLimitSeconds,
      autoPlayMyRecordingAfterValidate: false,
      myRecordingReviewLabel: '유사도 확인',
      revealSpeakingResultOnReviewTap: true,
      primaryButtonLabel: '다음 문장 테스트',
      secondaryButtonLabel: '같은 문장 다시 테스트',
      onSecondaryPressed: () {
        setState(() {
          _retryEpoch += 1;
          _recordedWavBytes = null;
          _recordedClip = null;
          _lastUploadedAudioPath = null;
          _hintRevealedItemId = null;
        });
      },
      tertiaryButtonLabel: '학습 종료',
      onTertiaryPressed: () => context.go('/session-summary'),
      primaryRoute: '/session-summary',
      showBackButton: true,
      backFallbackRoute: '/flash-sentence-test-select',
      timeLimitSeconds: overallLimitSeconds,
      showTimerPauseControl: true,
      pauseTimerLabel: '\uC7A0\uC2DC \uC911\uC9C0',
      resumeTimerLabel: '\uB2E4\uC2DC \uC2DC\uC791',
      autoPlayPromptAudioOnOpen: false,
      showBlockedTimeLimitBar: false,
      showBlockedStatusBanner: false,
      showBottomActionBar: true,
      autoAdvanceWhenReady: false,
      choiceTimeoutBehavior: ChoiceTimeoutBehavior.autoAdvance,
      onAppBackgrounded: _stopMediaForLifecycle,
      onAppResumed: _stopMediaForLifecycle,
      onPlayPromptAudio: () => _audioPlayer.playAsset(target.audioPath),
      onPlayMyRecording: () async {
        final bytes = _recordedWavBytes;
        if (bytes == null) {
          return;
        }
        await _audioPlayer.playWavBytes(bytes);
      },
      onStartRecording: () async {
        await _recorder.start();
      },
      onStopRecordingOnly: () async {
        final clip = await _recorder.stop();
        if (clip == null) {
          return SpeakingValidationResult(
            hasRecording: false,
            passed: false,
            message:
                l10n?.speakingNoRecordingData ??
                'No recording data. Please try again.',
          );
        }
        _recordedWavBytes = clip.wavBytes;
        _recordedClip = clip;
        _lastUploadedAudioPath = null;
        return const SpeakingValidationResult(
          hasRecording: true,
          passed: false,
          message: '녹음이 완료되었습니다. 유사도 확인을 눌러 결과를 확인하세요.',
        );
      },
      onReviewRecordingAndValidate: () async {
        final clip = _recordedClip;
        if (clip == null) {
          return const SpeakingValidationResult(
            hasRecording: false,
            passed: false,
            message: '먼저 녹음해 주세요.',
          );
        }
        return _evaluateRecording(
          clip: clip,
          target: target,
          sessionId: session?.sessionId,
          userId: user?.uid,
          shouldUseServer: shouldUseServer,
          l10n: l10n,
        );
      },
      onStopRecordingAndValidate: () async {
        final clip = await _recorder.stop();
        if (clip == null) {
          return SpeakingValidationResult(
            hasRecording: false,
            passed: false,
            message:
                l10n?.speakingNoRecordingData ??
                'No recording data. Please try again.',
          );
        }
        _recordedWavBytes = clip.wavBytes;

        if (!shouldUseServer) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: true,
            message:
                l10n?.speakingDevModePass ??
                'In development mode, this is marked as completed.',
          );
        }

        final asrPolicy = ref.read(asrPolicyProvider);
        if (!asrPolicy.decided) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message: '음성 인식 설정을 불러오지 못했습니다. 다시 시도해 주세요.',
            errorCode: 'ASR_POLICY_NOT_DECIDED',
          );
        }

        final repo = ref.read(sessionRuntimeRepositoryProvider);
        var serverAsrFailedBeforeFallback = false;
        String? serverFailureErrorCode;
        if (asrPolicy.useServerFirst) {
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
                cloudResult.transcript != null &&
                cloudResult.transcript!.trim().isNotEmpty;
            final mustFallback =
                cloudResult.errorCode == 'STT_UNAVAILABLE' ||
                !hasServerTranscript;
            if (!mustFallback) {
              if (cloudResult.similarityScore != null) {
                ref
                    .read(studyFlowControllerProvider.notifier)
                    .recordSpeakingSimilarity(
                      itemId: target.id,
                      score: cloudResult.similarityScore!,
                    );
              }
              return SpeakingValidationResult(
                hasRecording: true,
                passed: cloudResult.passed,
                similarityScore: cloudResult.similarityScore,
                transcript: cloudResult.transcript,
                message:
                    cloudResult.message ??
                    (cloudResult.passed
                        ? (l10n?.interactiveSpeakingPassed ??
                              'Speaking validation passed.')
                        : (l10n?.interactiveSpeakingFailed ??
                              'Speaking validation did not pass.')),
                errorCode: cloudResult.errorCode,
              );
            }
            serverAsrFailedBeforeFallback = true;
            serverFailureErrorCode =
                cloudResult.errorCode ??
                (hasServerTranscript ? null : 'SERVER_STT_EMPTY_TRANSCRIPT');

            if (!asrPolicy.allowOnDeviceFallback) {
              return SpeakingValidationResult(
                hasRecording: true,
                passed: false,
                message:
                    l10n?.speakingServerOnlyRequiresNetwork ??
                    'Server STT only mode. Connect network and try again.',
                errorCode: 'NETWORK_REQUIRED_SERVER_ONLY',
              );
            }
          } catch (_) {
            serverAsrFailedBeforeFallback = true;
            serverFailureErrorCode = 'SERVER_STT_REQUEST_FAILED';
            if (!asrPolicy.allowOnDeviceFallback) {
              return SpeakingValidationResult(
                hasRecording: true,
                passed: false,
                message:
                    l10n?.speakingNetworkOrServerFailed ??
                    'Could not evaluate speech due to network/server issue.',
                errorCode: 'NETWORK_REQUIRED_SERVER_ONLY',
              );
            }
          }
        }

        final onDeviceResult = await _onDeviceAsr.transcribeThai(
          samples: clip.floatSamples,
          sampleRate: clip.sampleRate,
        );
        if (onDeviceResult == null ||
            onDeviceResult.transcript.trim().isEmpty) {
          return _asrUnavailableResult(
            asrPolicy: asrPolicy,
            l10n: l10n,
            serverAsrFailedBeforeFallback: serverAsrFailedBeforeFallback,
            serverFailureErrorCode: serverFailureErrorCode,
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
            ref
                .read(speakingFallbackSyncWorkerProvider.notifier)
                .refreshPendingCount();
          }
          if (fallbackSaved.similarityScore != null) {
            ref
                .read(studyFlowControllerProvider.notifier)
                .recordSpeakingSimilarity(
                  itemId: target.id,
                  score: fallbackSaved.similarityScore!,
                );
          }
          return SpeakingValidationResult(
            hasRecording: true,
            passed: fallbackSaved.passed,
            similarityScore: fallbackSaved.similarityScore,
            transcript: fallbackSaved.transcript,
            message:
                fallbackSaved.message ??
                (l10n?.speakingOnDeviceSaved ?? 'Processed by on-device ASR.'),
            errorCode: fallbackSaved.errorCode,
          );
        } catch (_) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message:
                l10n?.speakingOnDeviceSaveFailed ??
                'Failed to save on-device result. Try again.',
            errorCode: 'ON_DEVICE_SAVE_FAILED',
          );
        }
      },
      onScreenOpened: () async {
        if (!shouldUseServer) {
          return;
        }
        await ref
            .read(sessionRuntimeRepositoryProvider)
            .saveResumeState(
              userId: user.uid,
              sessionId: session.sessionId,
              route: '/flash-sentence-test/speaking',
            );
      },
      onPrimaryAction: (payload) async {
        if (payload.speakingTimedOutWithoutRecording) {
          ref
              .read(studyFlowControllerProvider.notifier)
              .recordSpeakingSimilarity(itemId: target.id, score: 0);
        }
        final hasNext = ref
            .read(studyFlowControllerProvider.notifier)
            .advanceTrack(
              track: StudyFlowTrack.flashSentenceTestSpeaking,
              totalCount: effectiveTotal,
            );
        if (shouldUseServer) {
          try {
            if (hasNext) {
              await ref
                  .read(sessionRuntimeRepositoryProvider)
                  .saveResumeState(
                    userId: user.uid,
                    sessionId: session.sessionId,
                    route: '/flash-sentence-test/speaking',
                  );
            } else {
              await ref
                  .read(sessionRuntimeRepositoryProvider)
                  .discardResumeState(
                    userId: user.uid,
                    sessionId: session.sessionId,
                  );
            }
          } catch (_) {
            // Resume sync failure should not block screen navigation.
          }
        }
        return hasNext ? '/flash-sentence-test/speaking' : '/session-summary';
      },
    );
  }

  void _syncItemState(String itemId) {
    if (_activeItemId == itemId) {
      return;
    }
    _activeItemId = itemId;
    _recordedWavBytes = null;
    _recordedClip = null;
    _lastUploadedAudioPath = null;
    _hintRevealedItemId = null;
  }

  SpeakingValidationResult _asrUnavailableResult({
    required AsrPolicyState asrPolicy,
    required AppLocalizations? l10n,
    required bool serverAsrFailedBeforeFallback,
    String? serverFailureErrorCode,
  }) {
    final reasonCode = _onDeviceAsr.unavailableReason;
    final reason = onDeviceAsrReasonToKorean(reasonCode);
    if (asrPolicy.useServerFirst &&
        serverAsrFailedBeforeFallback &&
        reasonCode == 'model_path_not_configured') {
      return SpeakingValidationResult(
        hasRecording: true,
        passed: false,
        message:
            l10n?.speakingNetworkOrServerFailed ??
            'Could not evaluate speech due to network/server issue.',
        errorCode: serverFailureErrorCode ?? 'SERVER_STT_UNAVAILABLE',
      );
    }

    return SpeakingValidationResult(
      hasRecording: true,
      passed: false,
      message:
          l10n?.speakingServerAndOnDeviceUnavailable(reason) ??
          'Server and on-device ASR are unavailable. $reason',
      errorCode: reasonCode ?? 'ON_DEVICE_ASR_UNAVAILABLE',
    );
  }

  Future<SpeakingValidationResult> _evaluateRecording({
    required RecordedClip clip,
    required ThaiSentenceContent target,
    required String? sessionId,
    required String? userId,
    required bool shouldUseServer,
    required AppLocalizations? l10n,
  }) async {
    if (!shouldUseServer || sessionId == null || userId == null) {
      return SpeakingValidationResult(
        hasRecording: true,
        passed: true,
        message:
            l10n?.speakingDevModePass ??
            'In development mode, this is marked as completed.',
      );
    }

    final asrPolicy = ref.read(asrPolicyProvider);
    if (!asrPolicy.decided) {
      return const SpeakingValidationResult(
        hasRecording: true,
        passed: false,
        message: '음성 인식 설정을 불러오지 못했습니다. 다시 시도해 주세요.',
        errorCode: 'ASR_POLICY_NOT_DECIDED',
      );
    }

    final repo = ref.read(sessionRuntimeRepositoryProvider);
    var serverAsrFailedBeforeFallback = false;
    String? serverFailureErrorCode;
    if (asrPolicy.useServerFirst) {
      try {
        final cloudResult = await repo.evaluateSpeakingAttempt(
          userId: userId,
          sessionId: sessionId,
          itemId: target.id,
          expectedText: target.thaiText,
          mode: 'flash_sentence_test_speaking',
          audioBytes: clip.wavBytes,
          mimeType: clip.mimeType,
          durationMs: clip.durationMs,
        );
        _lastUploadedAudioPath = cloudResult.audioPath;

        final hasServerTranscript =
            cloudResult.transcript != null &&
            cloudResult.transcript!.trim().isNotEmpty;
        final mustFallback =
            cloudResult.errorCode == 'STT_UNAVAILABLE' || !hasServerTranscript;
        if (!mustFallback) {
          _recordSpeakingSimilarity(target.id, cloudResult.similarityScore);
          return SpeakingValidationResult(
            hasRecording: true,
            passed: cloudResult.passed,
            similarityScore: cloudResult.similarityScore,
            transcript: cloudResult.transcript,
            message:
                cloudResult.message ??
                (cloudResult.passed
                    ? (l10n?.interactiveSpeakingPassed ??
                          'Speaking validation passed.')
                    : (l10n?.interactiveSpeakingFailed ??
                          'Speaking validation did not pass.')),
            errorCode: cloudResult.errorCode,
          );
        }
        serverAsrFailedBeforeFallback = true;
        serverFailureErrorCode =
            cloudResult.errorCode ??
            (hasServerTranscript ? null : 'SERVER_STT_EMPTY_TRANSCRIPT');

        if (!asrPolicy.allowOnDeviceFallback) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message:
                l10n?.speakingServerOnlyRequiresNetwork ??
                'Server STT only mode. Connect network and try again.',
            errorCode: 'NETWORK_REQUIRED_SERVER_ONLY',
          );
        }
      } catch (_) {
        serverAsrFailedBeforeFallback = true;
        serverFailureErrorCode = 'SERVER_STT_REQUEST_FAILED';
        if (!asrPolicy.allowOnDeviceFallback) {
          return SpeakingValidationResult(
            hasRecording: true,
            passed: false,
            message:
                l10n?.speakingNetworkOrServerFailed ??
                'Could not evaluate speech due to network/server issue.',
            errorCode: 'NETWORK_REQUIRED_SERVER_ONLY',
          );
        }
      }
    }

    final onDeviceResult = await _onDeviceAsr.transcribeThai(
      samples: clip.floatSamples,
      sampleRate: clip.sampleRate,
    );
    if (onDeviceResult == null || onDeviceResult.transcript.trim().isEmpty) {
      return _asrUnavailableResult(
        asrPolicy: asrPolicy,
        l10n: l10n,
        serverAsrFailedBeforeFallback: serverAsrFailedBeforeFallback,
        serverFailureErrorCode: serverFailureErrorCode,
      );
    }

    try {
      final fallbackSaved = await repo.submitOnDeviceSpeakingFallback(
        userId: userId,
        sessionId: sessionId,
        itemId: target.id,
        expectedText: target.thaiText,
        transcript: onDeviceResult.transcript,
        mode: 'flash_sentence_test_speaking',
        audioPath: _lastUploadedAudioPath ?? '',
        engine: onDeviceResult.engine,
        durationMs: clip.durationMs,
      );
      if (fallbackSaved.errorCode == 'QUEUED_OFFLINE') {
        ref
            .read(speakingFallbackSyncWorkerProvider.notifier)
            .refreshPendingCount();
      }
      _recordSpeakingSimilarity(target.id, fallbackSaved.similarityScore);
      return SpeakingValidationResult(
        hasRecording: true,
        passed: fallbackSaved.passed,
        similarityScore: fallbackSaved.similarityScore,
        transcript: fallbackSaved.transcript,
        message:
            fallbackSaved.message ??
            (l10n?.speakingOnDeviceSaved ?? 'Processed by on-device ASR.'),
        errorCode: fallbackSaved.errorCode,
      );
    } catch (_) {
      return SpeakingValidationResult(
        hasRecording: true,
        passed: false,
        message:
            l10n?.speakingOnDeviceSaveFailed ??
            'Failed to save on-device result. Try again.',
        errorCode: 'ON_DEVICE_SAVE_FAILED',
      );
    }
  }

  void _recordSpeakingSimilarity(String itemId, int? score) {
    if (score == null) {
      return;
    }
    ref
        .read(studyFlowControllerProvider.notifier)
        .recordSpeakingSimilarity(itemId: itemId, score: score);
  }

  Future<void> _stopMediaForLifecycle() async {
    await _audioPlayerService?.stop();
    final recorder = _recorderService;
    if (recorder?.isRecording ?? false) {
      await recorder?.stop();
    }
  }
}
