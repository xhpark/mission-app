import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import 'app_bottom_action_bar.dart';
import 'app_hero_header.dart';
import 'app_section_card.dart';
import 'app_status_banner.dart';

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
    this.options = const <String>[],
    this.correctOptionIndex,
    this.showMicSection = false,
    this.showAudioSection = true,
    this.requireSpeakingScoreValidation = false,
    this.timeLimitSeconds,
    this.onScreenOpened,
    this.onPrimaryAction,
    this.onPlayPromptAudio,
    this.onStartRecording,
    this.onStopRecordingAndValidate,
    this.onPlayMyRecording,
    this.primaryActionErrorMessage,
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
  final List<String> options;
  final int? correctOptionIndex;
  final bool showMicSection;
  final bool showAudioSection;
  final bool requireSpeakingScoreValidation;
  final int? timeLimitSeconds;
  final Future<void> Function()? onScreenOpened;
  final Future<String?> Function(InteractivePrimaryPayload payload)?
  onPrimaryAction;
  final Future<void> Function()? onPlayPromptAudio;
  final Future<void> Function()? onStartRecording;
  final Future<SpeakingValidationResult> Function()? onStopRecordingAndValidate;
  final Future<void> Function()? onPlayMyRecording;
  final String? primaryActionErrorMessage;

  @override
  State<InteractiveLearningScreen> createState() =>
      _InteractiveLearningScreenState();
}

class _InteractiveLearningScreenState extends State<InteractiveLearningScreen> {
  int? _selectedIndex;
  bool _recording = false;
  bool _hasRecordedOnce = false;
  bool _speakingPassed = false;
  bool _audioPlaying = false;
  bool _primarySubmitting = false;
  bool _recordingSubmitting = false;
  bool _playbackSubmitting = false;
  String? _speakingStatusMessage;
  int? _similarityScore;
  String? _recognizedText;
  Timer? _timer;
  int? _remainingSeconds;

  bool get _isCorrect {
    if (_selectedIndex == null || widget.correctOptionIndex == null) {
      return false;
    }
    return _selectedIndex == widget.correctOptionIndex;
  }

  bool get _requiresOptionValidation =>
      widget.options.isNotEmpty && widget.correctOptionIndex != null;

  bool get _requiresSpeakingValidation => widget.showMicSection;

  bool get _canProceed {
    if (_remainingSeconds != null && _remainingSeconds! <= 0) {
      return false;
    }
    if (_primarySubmitting || _recordingSubmitting) {
      return false;
    }
    if (_requiresOptionValidation && !_isCorrect) {
      return false;
    }
    if (_requiresSpeakingValidation && !_hasRecordedOnce) {
      return false;
    }
    if (_requiresSpeakingValidation &&
        widget.requireSpeakingScoreValidation &&
        !_speakingPassed) {
      return false;
    }
    return true;
  }

  String _primaryBlockedReason(AppLocalizations l10n) {
    if (_remainingSeconds != null && _remainingSeconds! <= 0) {
      return l10n.interactiveBlockedTimeExpired;
    }
    if (_requiresOptionValidation && !_isCorrect) {
      return l10n.interactiveBlockedSelectCorrect;
    }
    if (_requiresSpeakingValidation && !_hasRecordedOnce) {
      return l10n.interactiveBlockedNeedRecording;
    }
    if (_requiresSpeakingValidation &&
        widget.requireSpeakingScoreValidation &&
        !_speakingPassed) {
      return l10n.interactiveBlockedNeedSpeakingPass;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final onScreenOpened = widget.onScreenOpened;
    if (onScreenOpened != null) {
      Future.microtask(() async {
        try {
          await onScreenOpened();
        } catch (_) {}
      });
    }

    _remainingSeconds = widget.timeLimitSeconds;
    if (_remainingSeconds != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        final current = _remainingSeconds;
        if (current == null) {
          return;
        }
        if (current <= 1) {
          setState(() => _remainingSeconds = 0);
          _timer?.cancel();
          return;
        }
        setState(() => _remainingSeconds = current - 1);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _resolveL10n(context);

    void onBackPressed() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(widget.backFallbackRoute);
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.title),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed,
                tooltip: l10n.interactiveBackTooltip,
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppHeroHeader(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: 12),
          AppSectionCard(
            title: l10n.interactiveProgressTitle,
            description: l10n.interactiveProgressDescription,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.progressLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (_remainingSeconds != null)
                      Text(
                        l10n.interactiveRemainingSeconds(_remainingSeconds!),
                        style: theme.textTheme.labelLarge,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: widget.promptTitle,
            description: l10n.interactivePromptDescription,
            icon: Icons.auto_awesome_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.foreignText, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(widget.nativeText, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.record_voice_over_outlined,
                      label: widget.pronunciation,
                    ),
                    _InfoChip(
                      icon: Icons.lightbulb_outline,
                      label: widget.hint,
                    ),
                  ],
                ),
                if (widget.showAudioSection) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _playbackSubmitting
                          ? null
                          : _onPromptAudioPressed,
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
                            ? l10n.interactiveRecordStop
                            : l10n.interactiveRecordStart,
                      ),
                    ),
                  ),
                  if (_hasRecordedOnce && widget.onPlayMyRecording != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _playbackSubmitting
                            ? null
                            : _onPlayMyRecordingPressed,
                        icon: const Icon(Icons.play_arrow_outlined),
                        label: Text(l10n.interactiveMyRecordingListen),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _recording
                        ? l10n.interactiveRecordingGuidanceActive
                        : l10n.interactiveRecordingGuidanceIdle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_speakingStatusMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _speakingStatusMessage!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (_recognizedText != null || _similarityScore != null) ...[
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
                    onPressed: () => setState(() => _selectedIndex = index),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.options[index],
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_selectedIndex != null &&
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
          if (!_canProceed) ...[
            const SizedBox(height: 16),
            AppStatusBanner(
              tone: AppStatusTone.warning,
              message: _primaryBlockedReason(l10n),
            ),
          ],
        ],
      ),
      bottomNavigationBar: AppBottomActionBar(
        secondaryLabel: l10n.interactiveSecondaryToSelect,
        onSecondaryPressed: () => context.go('/select'),
        primaryLabel: widget.primaryButtonLabel,
        onPrimaryPressed: _canProceed ? () => _onPrimaryPressed(context) : null,
      ),
    );
  }

  Future<void> _onPrimaryPressed(BuildContext context) async {
    final l10n = _resolveL10n(context);
    if (widget.onPrimaryAction != null) {
      setState(() => _primarySubmitting = true);
      try {
        final nextRoute = await widget.onPrimaryAction!(
          InteractivePrimaryPayload(
            selectedIndex: _selectedIndex,
            correctOptionIndex: widget.correctOptionIndex,
            elapsedSeconds: widget.timeLimitSeconds == null
                ? 0
                : (widget.timeLimitSeconds! -
                      (_remainingSeconds ?? widget.timeLimitSeconds!)),
          ),
        );
        if (nextRoute != null && context.mounted) {
          context.go(nextRoute);
          setState(() => _primarySubmitting = false);
          return;
        }
      } catch (_) {
        if (!context.mounted) {
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
    if (!context.mounted) {
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
    final onPlayMyRecording = widget.onPlayMyRecording;
    if (onPlayMyRecording == null) {
      return;
    }
    setState(() => _playbackSubmitting = true);
    try {
      await onPlayMyRecording();
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
        _speakingStatusMessage = l10n.interactiveRecordingStatusActive;
      });
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

  Future<void> _onStopRecordingPressed() async {
    final l10n = _resolveL10n(context);
    setState(() => _recordingSubmitting = true);
    try {
      final result = widget.onStopRecordingAndValidate != null
          ? await widget.onStopRecordingAndValidate!()
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
        _speakingStatusMessage =
            result.message ??
            (result.passed
                ? l10n.interactiveSpeakingPassed
                : l10n.interactiveSpeakingFailed);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.interactiveRecordingProcessFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _recordingSubmitting = false);
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class InteractivePrimaryPayload {
  const InteractivePrimaryPayload({
    required this.selectedIndex,
    required this.correctOptionIndex,
    required this.elapsedSeconds,
  });

  final int? selectedIndex;
  final int? correctOptionIndex;
  final int elapsedSeconds;
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
