import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import 'app_bottom_action_bar.dart';
import 'app_section_card.dart';
import 'app_status_banner.dart';
import 'learning_action_styles.dart';
import 'learning_text_emphasis.dart';

enum ChoiceTimeoutBehavior {
  block,
  retrySameQuestion,
  autoAdvance,
  autoAdvanceAsWrong,
}

class InteractiveLearningScreen extends StatefulWidget {
  const InteractiveLearningScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.promptTitle,
    required this.foreignText,
    required this.nativeText,
    required this.pronunciation,
    required this.hint,
    required this.primaryButtonLabel,
    required this.primaryRoute,
    this.showBackButton = false,
    this.backFallbackRoute = '/select',
    this.onBackPressed,
    this.options = const <String>[],
    this.correctOptionIndex,
    this.showMicSection = false,
    this.showAudioSection = true,
    this.showPromptDescription = true,
    this.showNativeText = true,
    this.showPromptInfoChips = true,
    this.showHintInfoChip = true,
    this.promptSupportContent,
    this.showChoiceFeedback = true,
    this.requireSpeakingScoreValidation = false,
    this.timeLimitSeconds,
    this.choiceTimeoutBehavior = ChoiceTimeoutBehavior.block,
    this.allowAnyOptionToProceed = false,
    this.autoAdvanceOnOptionSelect = false,
    this.showBottomActionBar = true,
    this.showProgressAtBottom = false,
    this.autoAdvanceWhenReady = false,
    this.showTimerPauseControl = false,
    this.pauseTimerLabel,
    this.resumeTimerLabel,
    this.autoPlayPromptAudioOnOpen = false,
    this.onScreenOpened,
    this.onAppBackgrounded,
    this.onAppResumed,
    this.onPrimaryAction,
    this.onPlayPromptAudio,
    this.onStartRecording,
    this.onStopRecordingOnly,
    this.onStopRecordingAndValidate,
    this.onPlayMyRecording,
    this.onReviewRecordingAndValidate,
    this.onOptionSelected,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
    this.tertiaryButtonLabel,
    this.onTertiaryPressed,
    this.recordStartLabel,
    this.recordStopLabel,
    this.recordingGuidanceIdleText,
    this.showSpeakingStatusMessage = true,
    this.recordingTimeLimitSeconds,
    this.autoPlayMyRecordingAfterValidate = false,
    this.timeLimitBannerLabel,
    this.myRecordingReviewLabel,
    this.revealSpeakingResultOnReviewTap = false,
    this.primaryActionErrorMessage,
    this.stopButtonLabel,
    this.onStopPressed,
    this.showBlockedTimeLimitBar = true,
    this.showBlockedStatusBanner = true,
    this.showProgressDescription = false,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final String promptTitle;
  final String foreignText;
  final String nativeText;
  final String pronunciation;
  final String hint;
  final String primaryButtonLabel;
  final String primaryRoute;
  final bool showBackButton;
  final String backFallbackRoute;
  final VoidCallback? onBackPressed;
  final List<String> options;
  final int? correctOptionIndex;
  final bool showMicSection;
  final bool showAudioSection;
  final bool showPromptDescription;
  final bool showNativeText;
  final bool showPromptInfoChips;
  final bool showHintInfoChip;
  final Widget? promptSupportContent;
  final bool showChoiceFeedback;
  final bool requireSpeakingScoreValidation;
  final int? timeLimitSeconds;
  final ChoiceTimeoutBehavior choiceTimeoutBehavior;
  final bool allowAnyOptionToProceed;
  final bool autoAdvanceOnOptionSelect;
  final bool showBottomActionBar;
  final bool showProgressAtBottom;
  final bool autoAdvanceWhenReady;
  final bool showTimerPauseControl;
  final String? pauseTimerLabel;
  final String? resumeTimerLabel;
  final bool autoPlayPromptAudioOnOpen;
  final Future<void> Function()? onScreenOpened;
  final Future<void> Function()? onAppBackgrounded;
  final Future<void> Function()? onAppResumed;
  final Future<String?> Function(InteractivePrimaryPayload payload)?
  onPrimaryAction;
  final Future<void> Function()? onPlayPromptAudio;
  final Future<void> Function()? onStartRecording;
  final Future<SpeakingValidationResult> Function()? onStopRecordingOnly;
  final Future<SpeakingValidationResult> Function()? onStopRecordingAndValidate;
  final Future<void> Function()? onPlayMyRecording;
  final Future<SpeakingValidationResult> Function()?
  onReviewRecordingAndValidate;
  final Future<void> Function(int index, String option)? onOptionSelected;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;
  final String? tertiaryButtonLabel;
  final VoidCallback? onTertiaryPressed;
  final String? recordStartLabel;
  final String? recordStopLabel;
  final String? recordingGuidanceIdleText;
  final bool showSpeakingStatusMessage;
  final int? recordingTimeLimitSeconds;
  final bool autoPlayMyRecordingAfterValidate;
  final String? timeLimitBannerLabel;
  final String? myRecordingReviewLabel;
  final bool revealSpeakingResultOnReviewTap;
  final String? primaryActionErrorMessage;
  final String? stopButtonLabel;
  final VoidCallback? onStopPressed;
  final bool showBlockedTimeLimitBar;
  final bool showBlockedStatusBanner;
  final bool showProgressDescription;

  @override
  State<InteractiveLearningScreen> createState() =>
      _InteractiveLearningScreenState();
}

class _InteractiveLearningScreenState extends State<InteractiveLearningScreen>
    with WidgetsBindingObserver {
  int? _selectedIndex;
  bool _recording = false;
  bool _hasRecordedOnce = false;
  bool _speakingPassed = false;
  bool _audioPlaying = false;
  bool _primarySubmitting = false;
  bool _recordingSubmitting = false;
  bool _playbackSubmitting = false;
  String? _speakingStatusMessage;
  String? _speakingReviewNotice;
  int? _similarityScore;
  String? _recognizedText;
  bool _showSpeakingResult = true;
  bool _speakingReviewCompleted = false;
  Timer? _timer;
  int? _remainingSeconds;
  Timer? _recordingTimer;
  int? _recordingRemainingMs;
  bool _timeoutHandlingInProgress = false;
  bool _timeoutAutoHandled = false;
  bool _timerPaused = false;

  bool _didQuestionChange(InteractiveLearningScreen oldWidget) {
    if (oldWidget.progressLabel != widget.progressLabel) {
      return true;
    }
    if (oldWidget.foreignText != widget.foreignText) {
      return true;
    }
    if (oldWidget.nativeText != widget.nativeText) {
      return true;
    }
    if (oldWidget.promptTitle != widget.promptTitle) {
      return true;
    }
    if (oldWidget.options.length != widget.options.length) {
      return true;
    }
    for (var i = 0; i < widget.options.length; i++) {
      if (oldWidget.options[i] != widget.options[i]) {
        return true;
      }
    }
    return false;
  }

  bool get _isCorrect {
    if (_selectedIndex == null || widget.correctOptionIndex == null) {
      return false;
    }
    return _selectedIndex == widget.correctOptionIndex;
  }

  bool get _requiresOptionValidation =>
      widget.options.isNotEmpty && widget.correctOptionIndex != null;

  bool get _optionSelectionSatisfied {
    if (!_requiresOptionValidation) {
      return true;
    }
    if (widget.allowAnyOptionToProceed) {
      return _selectedIndex != null;
    }
    return _isCorrect;
  }

  bool get _requiresSpeakingValidation => widget.showMicSection;

  bool get _requiresExplicitSpeakingReview =>
      _requiresSpeakingValidation &&
      widget.onReviewRecordingAndValidate != null;

  double? get _recordingRemainingRatio {
    final total = widget.recordingTimeLimitSeconds;
    final remainingMs = _recordingRemainingMs;
    if (total == null || remainingMs == null || total <= 0) {
      return null;
    }
    return (remainingMs / (total * 1000)).clamp(0.0, 1.0);
  }

  bool get _canProceed {
    if (_remainingSeconds != null && _remainingSeconds! <= 0) {
      return false;
    }
    if (_primarySubmitting ||
        _recordingSubmitting ||
        _playbackSubmitting ||
        _recording) {
      return false;
    }
    if (_requiresOptionValidation && !_optionSelectionSatisfied) {
      return false;
    }
    if (_requiresSpeakingValidation && !_hasRecordedOnce) {
      return false;
    }
    if (_requiresExplicitSpeakingReview && !_speakingReviewCompleted) {
      return false;
    }
    if (_requiresSpeakingValidation &&
        widget.requireSpeakingScoreValidation &&
        !_speakingPassed) {
      return false;
    }
    return true;
  }

  bool get _isRetryTimeoutState =>
      _remainingSeconds != null &&
      _remainingSeconds! <= 0 &&
      widget.choiceTimeoutBehavior == ChoiceTimeoutBehavior.retrySameQuestion;

  bool get _canProceedAfterRetryTimeout {
    if (!_isRetryTimeoutState) {
      return false;
    }
    if (_primarySubmitting ||
        _recordingSubmitting ||
        _playbackSubmitting ||
        _recording ||
        _timeoutHandlingInProgress) {
      return false;
    }
    return true;
  }

  bool get _shouldSuppressTimeoutWarning {
    final remaining = _remainingSeconds;
    if (remaining == null || remaining > 0) {
      return false;
    }
    return widget.choiceTimeoutBehavior == ChoiceTimeoutBehavior.autoAdvance ||
        widget.choiceTimeoutBehavior ==
            ChoiceTimeoutBehavior.autoAdvanceAsWrong;
  }

  Color _timeBarColor(ThemeData theme, double ratio) {
    if (ratio <= 0.1) {
      return theme.colorScheme.error;
    }
    if (ratio <= 0.3) {
      return Colors.orange;
    }
    return theme.colorScheme.primary;
  }

  String _primaryBlockedReason(AppLocalizations l10n) {
    if (_remainingSeconds != null && _remainingSeconds! <= 0) {
      return '제한 시간이 종료되었습니다.';
    }
    if (_requiresOptionValidation && !_optionSelectionSatisfied) {
      return l10n.interactiveBlockedSelectCorrect;
    }
    if (_requiresSpeakingValidation && !_hasRecordedOnce) {
      return '';
    }
    if (_requiresExplicitSpeakingReview && !_speakingReviewCompleted) {
      return '유사도 확인 후 진행할 수 있습니다.';
    }
    if (_requiresSpeakingValidation &&
        widget.requireSpeakingScoreValidation &&
        !_speakingPassed) {
      return l10n.interactiveBlockedNeedSpeakingPass;
    }
    return '';
  }

  TextStyle? _promptTextStyle(BuildContext context) {
    if (widget.options.isNotEmpty ||
        (widget.showMicSection && !widget.showNativeText)) {
      return LearningTextEmphasis.meaningPrompt(context);
    }
    return LearningTextEmphasis.foreignScript(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final onScreenOpened = widget.onScreenOpened;
    if (onScreenOpened != null) {
      Future.microtask(() async {
        try {
          await onScreenOpened();
        } catch (_) {}
      });
    }

    _remainingSeconds = widget.timeLimitSeconds;
    _startTimer();
    _scheduleAutoPlayPrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _handleAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
    }
  }

  void _handleAppBackgrounded() {
    _timer?.cancel();
    _recordingTimer?.cancel();
    unawaited(widget.onAppBackgrounded?.call());
    if (!mounted) {
      return;
    }
    setState(() {
      if (_remainingSeconds != null && (_remainingSeconds ?? 0) > 0) {
        _timerPaused = true;
      }
      if (_recording) {
        _recording = false;
        _recordingSubmitting = false;
        _recordingRemainingMs = null;
        _speakingStatusMessage = '앱이 백그라운드로 이동해 녹음이 중단되었습니다. 다시 녹음해 주세요.';
      }
      _audioPlaying = false;
      _playbackSubmitting = false;
    });
  }

  void _handleAppResumed() {
    unawaited(widget.onAppResumed?.call());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _resolveL10n(context);
    final promptTextStyle = _promptTextStyle(context);
    final nativeTextStyle = widget.showMicSection
        ? LearningTextEmphasis.supportingMeaning(context)
        : theme.textTheme.bodyLarge;
    final optionTextStyle = LearningTextEmphasis.optionPronunciation(context);
    final progressDescription = widget.showProgressDescription
        ? l10n.interactiveProgressDescription
        : null;
    final blockedReason = _primaryBlockedReason(l10n);

    void defaultBackPressed() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(widget.backFallbackRoute);
    }

    final progressSection = AppSectionCard(
      title: l10n.interactiveProgressTitle,
      description: progressDescription,
      icon: Icons.timelapse_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: widget.progress,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final showPauseButton =
                  widget.showTimerPauseControl &&
                  _remainingSeconds != null &&
                  (_remainingSeconds ?? 0) > 0;
              final pauseButton = OutlinedButton.icon(
                onPressed: _toggleTimerPause,
                icon: Icon(_timerPaused ? Icons.play_arrow : Icons.pause),
                label: Text(
                  _timerPaused
                      ? (widget.resumeTimerLabel ?? '\uB2E4\uC2DC \uC2DC\uC791')
                      : (widget.pauseTimerLabel ?? '\uC7A0\uC2DC \uC911\uC9C0'),
                ),
              );

              if (showPauseButton && constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.progressLabel,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: pauseButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.progressLabel,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (showPauseButton) ...[
                    const SizedBox(width: 8),
                    pauseButton,
                  ],
                ],
              );
            },
          ),
          if (widget.onStopPressed != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: widget.onStopPressed,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  widget.stopButtonLabel ?? '\uD559\uC2B5 \uC911\uC9C0',
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.title),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed ?? defaultBackPressed,
                tooltip: l10n.interactiveBackTooltip,
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!widget.showProgressAtBottom) ...[
            AppSectionCard(
              title: l10n.interactiveProgressTitle,
              description: progressDescription,
              icon: Icons.timelapse_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showPauseButton =
                          widget.showTimerPauseControl &&
                          _remainingSeconds != null &&
                          (_remainingSeconds ?? 0) > 0;
                      final pauseButton = OutlinedButton.icon(
                        onPressed: _toggleTimerPause,
                        icon: Icon(
                          _timerPaused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(
                          _timerPaused
                              ? (widget.resumeTimerLabel ?? '다시 시작')
                              : (widget.pauseTimerLabel ?? '잠시 중지'),
                        ),
                      );

                      if (showPauseButton && constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.progressLabel,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: pauseButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.progressLabel,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (showPauseButton) ...[
                            const SizedBox(width: 8),
                            pauseButton,
                          ],
                        ],
                      );
                    },
                  ),
                  if (widget.onStopPressed != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: widget.onStopPressed,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(widget.stopButtonLabel ?? '학습 중지'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppSectionCard(
            title: widget.promptTitle,
            description: widget.showPromptDescription
                ? l10n.interactivePromptDescription
                : '',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.foreignText, style: promptTextStyle),
                if (widget.showNativeText) ...[
                  const SizedBox(height: 10),
                  Text(widget.nativeText, style: nativeTextStyle),
                ],
                if (widget.promptSupportContent != null) ...[
                  const SizedBox(height: 12),
                  widget.promptSupportContent!,
                ],
                if (widget.showPromptInfoChips) ...[
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.record_voice_over_outlined,
                            label: widget.pronunciation,
                            maxWidth: constraints.maxWidth,
                          ),
                          if (widget.showHintInfoChip &&
                              widget.hint.trim().isNotEmpty)
                            _InfoChip(
                              icon: Icons.lightbulb_outline,
                              label: widget.hint,
                              maxWidth: constraints.maxWidth,
                            ),
                        ],
                      );
                    },
                  ),
                ],
                if (widget.showAudioSection) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _playbackSubmitting
                          ? null
                          : _onPromptAudioPressed,
                      style: LearningActionStyles.prominentOutlined(context),
                      icon: Icon(
                        _audioPlaying
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      label: Text(
                        _audioPlaying
                            ? l10n.interactiveNativeAudioPause
                            : l10n.interactiveNativeAudioPlay,
                      ),
                    ),
                  ),
                ],
                if (widget.showMicSection) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _recordingSubmitting ? null : _onRecordPressed,
                      icon: Icon(
                        _recording
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none,
                      ),
                      label: Text(
                        _recording
                            ? (widget.recordStopLabel ??
                                  l10n.interactiveRecordStop)
                            : (widget.recordStartLabel ??
                                  l10n.interactiveRecordStart),
                      ),
                    ),
                  ),
                  if (_recording &&
                      widget.recordingTimeLimitSeconds != null &&
                      _recordingRemainingRatio != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('말하기 제한 시간', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _recordingRemainingRatio,
                              minHeight: 8,
                              color: _timeBarColor(
                                theme,
                                _recordingRemainingRatio!,
                              ),
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.interactiveRemainingSeconds(
                              ((_recordingRemainingMs ?? 0) / 1000).ceil(),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_hasRecordedOnce &&
                      (widget.onPlayMyRecording != null ||
                          widget.onReviewRecordingAndValidate != null)) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _playbackSubmitting
                            ? null
                            : _onPlayMyRecordingPressed,
                        style: LearningActionStyles.prominentOutlined(context),
                        icon:
                            _playbackSubmitting &&
                                widget.onReviewRecordingAndValidate != null
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_outlined),
                        label: Text(
                          _playbackSubmitting &&
                                  widget.onReviewRecordingAndValidate != null
                              ? '유사도 분석 중...'
                              : widget.myRecordingReviewLabel ??
                                    l10n.interactiveMyRecordingListen,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _recording
                        ? l10n.interactiveRecordingGuidanceActive
                        : (widget.recordingGuidanceIdleText ??
                              l10n.interactiveRecordingGuidanceIdle),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (widget.showSpeakingStatusMessage &&
                      _speakingStatusMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _speakingStatusMessage!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (_showSpeakingResult && _speakingReviewNotice != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        _speakingReviewNotice!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  if (_showSpeakingResult &&
                      (_recognizedText != null ||
                          _similarityScore != null)) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_similarityScore != null)
                            Text(
                              l10n.interactiveSimilarityScore(
                                _similarityScore!,
                              ),
                            ),
                          if (_recognizedText != null &&
                              _recognizedText!.isNotEmpty)
                            Text(
                              l10n.interactiveRecognizedText(_recognizedText!),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (widget.options.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(widget.options.length, (index) {
              final selected = _selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                    ),
                    onPressed: () async {
                      setState(() => _selectedIndex = index);
                      final onOptionSelected = widget.onOptionSelected;
                      if (onOptionSelected != null) {
                        final messenger = ScaffoldMessenger.of(context);
                        final audioFailureMessage = _resolveL10n(
                          context,
                        ).interactiveNativeAudioPlayFailed;
                        try {
                          await onOptionSelected(index, widget.options[index]);
                        } catch (error, stackTrace) {
                          debugPrint(
                            'Choice option audio/action failed: $error\n$stackTrace',
                          );
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(audioFailureMessage)),
                            );
                          }
                        }
                      }
                      if (widget.autoAdvanceOnOptionSelect &&
                          !_primarySubmitting &&
                          !_timeoutHandlingInProgress &&
                          _canProceed) {
                        if (!mounted) {
                          return;
                        }
                        await _onPrimaryPressed();
                      }
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.options[index],
                        style: optionTextStyle,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (widget.showChoiceFeedback &&
                _selectedIndex != null &&
                widget.correctOptionIndex != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isCorrect
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _isCorrect
                      ? l10n.interactiveCorrectFeedback
                      : l10n.interactiveIncorrectFeedback,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
          if (!_canProceed && !_shouldSuppressTimeoutWarning) ...[
            const SizedBox(height: 16),
            if (widget.showBlockedTimeLimitBar &&
                _remainingSeconds != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l10n.interactiveRemainingSeconds(_remainingSeconds!),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (widget.showBlockedStatusBanner && blockedReason.isNotEmpty)
              AppStatusBanner(
                tone: AppStatusTone.warning,
                message: blockedReason,
              ),
            if (_remainingSeconds != null &&
                _remainingSeconds! <= 0 &&
                widget.choiceTimeoutBehavior ==
                    ChoiceTimeoutBehavior.retrySameQuestion) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _timeoutHandlingInProgress
                      ? null
                      : _retrySameQuestion,
                  icon: const Icon(Icons.refresh),
                  label: const Text('같은 문항 다시 테스트'),
                ),
              ),
            ],
          ],
          if (widget.showProgressAtBottom) ...[
            const SizedBox(height: 16),
            progressSection,
          ],
        ],
      ),
      bottomNavigationBar: widget.showBottomActionBar
          ? AppBottomActionBar(
              secondaryLabel:
                  widget.secondaryButtonLabel ??
                  l10n.interactiveSecondaryToSelect,
              onSecondaryPressed: () {
                final secondary =
                    widget.onSecondaryPressed ?? () => context.go('/select');
                secondary();
              },
              primaryLabel: widget.primaryButtonLabel,
              onPrimaryPressed: (_canProceed || _canProceedAfterRetryTimeout)
                  ? _onPrimaryPressed
                  : null,
              tertiaryLabel: widget.tertiaryButtonLabel,
              onTertiaryPressed: widget.onTertiaryPressed,
            )
          : null,
    );
  }

  Future<void> _onPrimaryPressed() async {
    final l10n = _resolveL10n(context);
    final timedOutByRetry = _isRetryTimeoutState;
    if (widget.onPrimaryAction != null) {
      setState(() => _primarySubmitting = true);
      try {
        final nextRoute = await widget.onPrimaryAction!(
          InteractivePrimaryPayload(
            selectedIndex: _selectedIndex,
            correctOptionIndex: widget.correctOptionIndex,
            elapsedSeconds: timedOutByRetry
                ? (widget.timeLimitSeconds ?? 0)
                : widget.timeLimitSeconds == null
                ? 0
                : (widget.timeLimitSeconds! -
                      (_remainingSeconds ?? widget.timeLimitSeconds!)),
            timedOut: timedOutByRetry,
          ),
        );
        if (nextRoute != null && mounted) {
          context.go(nextRoute);
          setState(() => _primarySubmitting = false);
          return;
        }
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.primaryActionErrorMessage ?? l10n.interactiveActionError,
            ),
          ),
        );
        setState(() => _primarySubmitting = false);
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() => _primarySubmitting = false);
    }
    if (!mounted) {
      return;
    }
    context.go(widget.primaryRoute);
  }

  Future<void> _onPromptAudioPressed() async {
    final l10n = _resolveL10n(context);
    if (widget.onPlayPromptAudio == null) {
      setState(() => _audioPlaying = !_audioPlaying);
      return;
    }
    setState(() => _playbackSubmitting = true);
    try {
      await widget.onPlayPromptAudio!();
      if (!mounted) {
        return;
      }
      setState(() => _audioPlaying = !_audioPlaying);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.interactiveNativeAudioPlayFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _playbackSubmitting = false);
      }
    }
  }

  Future<void> _onPlayMyRecordingPressed() async {
    final l10n = _resolveL10n(context);
    if (widget.onReviewRecordingAndValidate != null) {
      await _runSpeakingReview();
      return;
    }
    final onPlayMyRecording = widget.onPlayMyRecording;
    if (onPlayMyRecording == null) {
      return;
    }
    if (!_showSpeakingResult) {
      setState(() => _showSpeakingResult = true);
    }
    setState(() => _speakingReviewNotice = null);
    setState(() => _playbackSubmitting = true);
    try {
      await onPlayMyRecording();
      if (!mounted) {
        return;
      }
      final hasReviewResult =
          _similarityScore != null ||
          (_recognizedText != null && _recognizedText!.trim().isNotEmpty);
      if (!hasReviewResult) {
        setState(() {
          _speakingReviewNotice =
              _speakingStatusMessage ??
              '아직 표시할 유사도 결과가 없습니다. 녹음을 완료한 뒤 다시 확인해 주세요.';
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.interactiveMyRecordingPlayFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _playbackSubmitting = false);
      }
    }
  }

  Future<void> _runSpeakingReview() async {
    final l10n = _resolveL10n(context);
    final onReviewRecordingAndValidate = widget.onReviewRecordingAndValidate;
    if (onReviewRecordingAndValidate == null || _playbackSubmitting) {
      return;
    }
    if (!_showSpeakingResult) {
      setState(() => _showSpeakingResult = true);
    }
    setState(() {
      _playbackSubmitting = true;
      _speakingReviewCompleted = false;
      _speakingReviewNotice = '유사도를 분석하고 있습니다.';
    });
    try {
      final result = await onReviewRecordingAndValidate();
      if (!mounted) {
        return;
      }
      final hasReviewPayload =
          result.similarityScore != null ||
          (result.transcript != null && result.transcript!.trim().isNotEmpty);
      final resolvedStatusMessage =
          result.message ??
          (result.passed
              ? l10n.interactiveSpeakingPassed
              : l10n.interactiveSpeakingFailed);
      setState(() {
        _hasRecordedOnce = result.hasRecording;
        _speakingPassed = result.passed;
        _similarityScore = result.similarityScore;
        _recognizedText = result.transcript;
        _speakingStatusMessage = resolvedStatusMessage;
        _speakingReviewNotice = hasReviewPayload ? null : resolvedStatusMessage;
        _showSpeakingResult = true;
        _speakingReviewCompleted = result.hasRecording;
      });
      if (_speakingReviewCompleted) {
        _scheduleAutoAdvanceWhenReady();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingReviewCompleted = false;
        _speakingReviewNotice = '유사도 분석에 실패했습니다. 다시 시도해 주세요.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.interactiveRecordingProcessFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _playbackSubmitting = false);
      }
    }
  }

  Future<void> _onRecordPressed() async {
    if (_recording) {
      await _onStopRecordingPressed();
      return;
    }
    await _onStartRecordingPressed();
  }

  Future<void> _onStartRecordingPressed() async {
    final l10n = _resolveL10n(context);
    setState(() => _recordingSubmitting = true);
    try {
      if (widget.onStartRecording != null) {
        await widget.onStartRecording!();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = true;
        _speakingReviewCompleted = false;
        _speakingStatusMessage = l10n.interactiveRecordingStatusActive;
        _speakingReviewNotice = null;
        _recordingRemainingMs = widget.recordingTimeLimitSeconds == null
            ? null
            : widget.recordingTimeLimitSeconds! * 1000;
      });
      _startRecordingTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.interactiveStartRecordingFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _recordingSubmitting = false);
      }
    }
  }

  Future<void> _onStopRecordingPressed({bool stopByTimeout = false}) async {
    final l10n = _resolveL10n(context);
    _recordingTimer?.cancel();
    setState(() => _recordingSubmitting = true);
    try {
      final stopRecording =
          widget.onStopRecordingOnly ?? widget.onStopRecordingAndValidate;
      final result = stopRecording != null
          ? await stopRecording()
          : const SpeakingValidationResult(hasRecording: true, passed: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = false;
        _hasRecordedOnce = result.hasRecording;
        _speakingPassed = result.passed;
        _similarityScore = result.similarityScore;
        _recognizedText = result.transcript;
        _speakingReviewNotice = null;
        _speakingReviewCompleted =
            widget.onReviewRecordingAndValidate == null && result.hasRecording;
        _speakingStatusMessage =
            result.message ??
            (result.passed
                ? l10n.interactiveSpeakingPassed
                : l10n.interactiveSpeakingFailed);
        _recordingRemainingMs = null;
        _showSpeakingResult = stopByTimeout
            ? true
            : !widget.revealSpeakingResultOnReviewTap;
      });
      if ((stopByTimeout || widget.autoPlayMyRecordingAfterValidate) &&
          result.hasRecording &&
          widget.onPlayMyRecording != null) {
        try {
          await widget.onPlayMyRecording!();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _recordingSubmitting = false);
      }
      if (!_requiresExplicitSpeakingReview || _speakingReviewCompleted) {
        _scheduleAutoAdvanceWhenReady();
      } else {
        if (result.hasRecording) {
          await _runSpeakingReview();
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.interactiveRecordingProcessFailed)),
      );
    } finally {
      if (mounted && _recordingSubmitting) {
        setState(() => _recordingSubmitting = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timerPaused = false;
    final current = _remainingSeconds;
    if (current == null || current <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final now = _remainingSeconds;
      if (now == null) {
        return;
      }
      if (now <= 1) {
        setState(() => _remainingSeconds = 0);
        _timer?.cancel();
        _handleTimeExpired();
        return;
      }
      setState(() => _remainingSeconds = now - 1);
    });
  }

  void _toggleTimerPause() {
    final remaining = _remainingSeconds;
    if (remaining == null || remaining <= 0) {
      return;
    }
    if (_timerPaused) {
      setState(() {
        _timerPaused = false;
      });
      _startTimer();
      return;
    }
    _timer?.cancel();
    setState(() {
      _timerPaused = true;
    });
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    if (widget.recordingTimeLimitSeconds == null ||
        widget.recordingTimeLimitSeconds! <= 0) {
      return;
    }
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_recording || _recordingSubmitting) {
        return;
      }
      final remaining = _recordingRemainingMs ?? 0;
      if (remaining <= 100) {
        setState(() => _recordingRemainingMs = 0);
        _recordingTimer?.cancel();
        _onStopRecordingPressed(stopByTimeout: true);
        return;
      }
      setState(() => _recordingRemainingMs = remaining - 100);
    });
  }

  Future<void> _handleTimeExpired() async {
    if (_timeoutAutoHandled || _timeoutHandlingInProgress) {
      return;
    }
    if (widget.choiceTimeoutBehavior !=
            ChoiceTimeoutBehavior.autoAdvanceAsWrong &&
        widget.choiceTimeoutBehavior != ChoiceTimeoutBehavior.autoAdvance) {
      return;
    }
    if (widget.onPrimaryAction == null || !mounted) {
      return;
    }
    _timeoutHandlingInProgress = true;
    _timeoutAutoHandled = true;
    try {
      if (widget.showMicSection) {
        if (_recording) {
          await _onStopRecordingPressed(stopByTimeout: true);
        }
        if (!mounted) {
          return;
        }
        if (_playbackSubmitting ||
            (_requiresExplicitSpeakingReview &&
                _hasRecordedOnce &&
                !_speakingReviewCompleted)) {
          _timeoutAutoHandled = false;
          return;
        }
        final nextRoute = await widget.onPrimaryAction!(
          InteractivePrimaryPayload(
            selectedIndex: null,
            correctOptionIndex: widget.correctOptionIndex,
            elapsedSeconds: widget.timeLimitSeconds ?? 0,
            timedOut: true,
            speakingTimedOutWithoutRecording: !_hasRecordedOnce,
          ),
        );
        if (!mounted) {
          return;
        }
        if (nextRoute != null) {
          context.go(nextRoute);
        }
        return;
      }
      final nextRoute = await widget.onPrimaryAction!(
        InteractivePrimaryPayload(
          selectedIndex: null,
          correctOptionIndex: widget.correctOptionIndex,
          elapsedSeconds: widget.timeLimitSeconds ?? 0,
          timedOut: true,
        ),
      );
      if (!mounted) {
        return;
      }
      if (nextRoute != null) {
        context.go(nextRoute);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      final l10n = _resolveL10n(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.interactiveActionError)));
      _timeoutAutoHandled = false;
    } finally {
      _timeoutHandlingInProgress = false;
    }
  }

  void _retrySameQuestion() {
    final total = widget.timeLimitSeconds;
    if (total == null) {
      return;
    }
    setState(() {
      _selectedIndex = null;
      _remainingSeconds = total;
      _timeoutAutoHandled = false;
    });
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant InteractiveLearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldResetTimer =
        oldWidget.timeLimitSeconds != widget.timeLimitSeconds ||
        _didQuestionChange(oldWidget);
    if (shouldResetTimer) {
      _timer?.cancel();
      _recordingTimer?.cancel();
      _selectedIndex = null;
      _recording = false;
      _hasRecordedOnce = false;
      _speakingPassed = false;
      _audioPlaying = false;
      _speakingStatusMessage = null;
      _speakingReviewNotice = null;
      _similarityScore = null;
      _recognizedText = null;
      _showSpeakingResult = true;
      _speakingReviewCompleted = false;
      _recordingRemainingMs = null;
      _timeoutHandlingInProgress = false;
      _timeoutAutoHandled = false;
      _timerPaused = false;
      _remainingSeconds = widget.timeLimitSeconds;
      _startTimer();
      _scheduleAutoPlayPrompt();
    }
    if (oldWidget.autoAdvanceWhenReady != widget.autoAdvanceWhenReady ||
        oldWidget.showMicSection != widget.showMicSection ||
        oldWidget.requireSpeakingScoreValidation !=
            widget.requireSpeakingScoreValidation) {
      _scheduleAutoAdvanceWhenReady();
    }
  }

  void _scheduleAutoAdvanceWhenReady() {
    if (!widget.autoAdvanceWhenReady ||
        !_canProceed ||
        _primarySubmitting ||
        _timeoutHandlingInProgress) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !widget.autoAdvanceWhenReady ||
          !_canProceed ||
          _primarySubmitting ||
          _timeoutHandlingInProgress) {
        return;
      }
      await _onPrimaryPressed();
    });
  }

  void _scheduleAutoPlayPrompt() {
    if (!widget.autoPlayPromptAudioOnOpen || widget.onPlayPromptAudio == null) {
      return;
    }
    Future.delayed(const Duration(milliseconds: 220), () async {
      if (!mounted) {
        return;
      }
      try {
        await widget.onPlayPromptAudio!.call();
      } catch (_) {}
    });
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeMaxWidth = maxWidth.isFinite
        ? maxWidth.clamp(160.0, 720.0)
        : (MediaQuery.sizeOf(context).width - 96).clamp(160.0, 720.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: safeMaxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                softWrap: true,
                overflow: TextOverflow.visible,
                textWidthBasis: TextWidthBasis.parent,
                style: LearningTextEmphasis.optionPronunciation(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InteractivePrimaryPayload {
  const InteractivePrimaryPayload({
    required this.selectedIndex,
    required this.correctOptionIndex,
    required this.elapsedSeconds,
    this.timedOut = false,
    this.speakingTimedOutWithoutRecording = false,
  });

  final int? selectedIndex;
  final int? correctOptionIndex;
  final int elapsedSeconds;
  final bool timedOut;
  final bool speakingTimedOutWithoutRecording;
}

class SpeakingValidationResult {
  const SpeakingValidationResult({
    required this.hasRecording,
    required this.passed,
    this.similarityScore,
    this.transcript,
    this.message,
    this.errorCode,
  });

  final bool hasRecording;
  final bool passed;
  final int? similarityScore;
  final String? transcript;
  final String? message;
  final String? errorCode;
}

AppLocalizations _resolveL10n(BuildContext context) {
  return AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ko'));
}
