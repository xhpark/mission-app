import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/services/recorder_service.dart';
import '../../../../core/widgets/app_hero_header.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../data/models/sentence_learning_item.dart';
import '../controllers/current_study_session_controller.dart';
import '../controllers/sentence_learning_controller.dart';

class SentenceLearningScreen extends ConsumerWidget {
  const SentenceLearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = _resolveL10n(context);
    final session = ref.watch(currentStudySessionProvider);
    final sentenceItemState = ref.watch(sentenceLearningControllerProvider);

    ref.listen(sentenceLearningControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(toUserFacingErrorMessage(error))),
          );
        },
      );
    });

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.sentenceLearningTitle)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStatusBanner(
                    tone: AppStatusTone.warning,
                    message: l10n.sentenceLearningNoSessionMessage,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/select'),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.sentenceLearningGoToSelect),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sentenceLearningTitle),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/select');
          },
          tooltip: l10n.interactiveBackTooltip,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppHeroHeader(
            title: l10n.sentenceLearningTitle,
            subtitle: l10n.sentenceLearningHeroSubtitle,
            icon: Icons.record_voice_over_outlined,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaTag(label: _categoryLabel(session.category, l10n)),
              _MetaTag(label: _levelLabel(session.level, l10n)),
              _MetaTag(label: _modeLabel(session.mode, l10n)),
            ],
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: l10n.sentenceLearningSectionTitle,
            description: l10n.sentenceLearningSectionDescription,
            icon: Icons.translate_outlined,
            child: session.mode == LearningMode.sentenceLearning
                ? sentenceItemState.when(
                    data: (item) => item == null
                        ? _PlaceholderCard(
                            message: l10n.sentenceLearningPlaceholder,
                          )
                        : _SentenceItemCard(
                            item: item,
                            category: session.category.name,
                            isLoading: sentenceItemState.isLoading,
                            onComplete: () => ref
                                .read(
                                  sentenceLearningControllerProvider.notifier,
                                )
                                .completeCurrentItem(),
                            onDone: () => context.go('/session-summary'),
                          ),
                    loading: () => const _LoadingCard(),
                    error: (error, _) => _PlaceholderCard(
                      message: l10n.sentenceLearningLoadError(error.toString()),
                    ),
                  )
                : _PlaceholderCard(
                    message: l10n.sentenceLearningPlaceholder,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SentenceItemCard extends StatefulWidget {
  const _SentenceItemCard({
    required this.item,
    required this.category,
    required this.isLoading,
    required this.onComplete,
    required this.onDone,
  });

  final SentenceLearningItem item;
  final String category;
  final bool isLoading;
  final VoidCallback onComplete;
  final VoidCallback onDone;

  @override
  State<_SentenceItemCard> createState() => _SentenceItemCardState();
}

class _SentenceItemCardState extends State<_SentenceItemCard> {
  late final RecorderService _recorderService;
  late final AudioPlayerService _audioPlayerService;

  Uint8List? _recordedWavBytes;
  bool _recording = false;
  bool _recordingSubmitting = false;
  bool _playbackSubmitting = false;
  bool _sentenceAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _recorderService = RecorderService();
    _audioPlayerService = AudioPlayerService();
  }

  @override
  void dispose() {
    _recorderService.dispose();
    _audioPlayerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _resolveL10n(context);
    final canonicalSentence = _resolveCanonicalSentence(
      category: widget.category,
      item: widget.item,
    );
    final sentenceAudioPath = canonicalSentence.audioPath.isNotEmpty
        ? canonicalSentence.audioPath
        : widget.item.audioPath;
    final relatedWords = _relatedWordsForSentence(
      category: widget.category,
      sentenceId: canonicalSentence.id,
      sentenceThaiText: canonicalSentence.thaiText,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canonicalSentence.koreanText,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.sentenceLearningPronunciationLabel}: ${canonicalSentence.phonetic} / ${canonicalSentence.hangulPronunciation}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _playbackSubmitting
                ? null
                : () => _playSentenceAudio(
                    sentenceAudioPath: sentenceAudioPath,
                    l10n: l10n,
                  ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _sentenceAudioPlaying
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sentenceAudioPlaying
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _sentenceAudioPlaying
                        ? Icons.graphic_eq
                        : Icons.volume_up_outlined,
                    size: 18,
                    color: _sentenceAudioPlaying
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canonicalSentence.thaiText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _sentenceAudioPlaying
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _playbackSubmitting
                ? null
                : () => _playSentenceAudio(
                    sentenceAudioPath: sentenceAudioPath,
                    l10n: l10n,
                  ),
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(l10n.sentenceLearningListenSentence),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _recordingSubmitting ? null : _onRecordPressed,
            icon: Icon(
              _recording ? Icons.stop_circle_outlined : Icons.mic_none,
            ),
            label: Text(
              _recording
                  ? l10n.interactiveRecordStop
                  : l10n.sentenceLearningReadWithMyVoice,
            ),
          ),
          if (_recordedWavBytes != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _playbackSubmitting
                  ? null
                  : () async {
                      final bytes = _recordedWavBytes;
                      if (bytes == null) {
                        return;
                      }
                      try {
                        setState(() => _playbackSubmitting = true);
                        await _audioPlayerService.playWavBytes(bytes);
                      } finally {
                        if (mounted) {
                          setState(() => _playbackSubmitting = false);
                        }
                      }
                    },
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(l10n.interactiveMyRecordingListen),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${l10n.sentenceLearningHintLabel}: ${canonicalSentence.hint}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (relatedWords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.sentenceLearningKeyWordsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relatedWords
                  .map(
                    (word) => ActionChip(
                      avatar: const Icon(Icons.hearing_outlined, size: 16),
                      label: Text('${word.koreanMeaning} · ${word.thaiWord}'),
                      onPressed: () => _audioPlayerService.playAsset(
                        _normalizeAssetPath(word.audioPath),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.sentenceLearningProgress(
              widget.item.currentStep,
              widget.item.totalSteps,
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          if (widget.item.sessionCompleted)
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.sentenceLearningSessionCompletedMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onDone,
                    child: Text(l10n.sentenceLearningGoToSummary),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onComplete,
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sentenceLearningCompleteAndContinue),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onRecordPressed() async {
    if (_recording) {
      await _onStopRecording();
      return;
    }
    await _onStartRecording();
  }

  Future<void> _onStartRecording() async {
    final l10n = _resolveL10n(context);
    setState(() => _recordingSubmitting = true);
    try {
      await _recorderService.start();
      if (!mounted) {
        return;
      }
      setState(() => _recording = true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sentenceLearningMicPermissionError)),
      );
    } finally {
      if (mounted) {
        setState(() => _recordingSubmitting = false);
      }
    }
  }

  Future<void> _onStopRecording() async {
    final l10n = _resolveL10n(context);
    setState(() => _recordingSubmitting = true);
    try {
      final clip = await _recorderService.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = false;
        _recordedWavBytes = clip?.wavBytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sentenceLearningRecordingProcessError)),
      );
    } finally {
      if (mounted) {
        setState(() => _recordingSubmitting = false);
      }
    }
  }

  Future<void> _playSentenceAudio({
    required String sentenceAudioPath,
    required AppLocalizations l10n,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (sentenceAudioPath.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.sentenceLearningAudioNotReady)),
      );
      return;
    }
    try {
      setState(() {
        _playbackSubmitting = true;
        _sentenceAudioPlaying = true;
      });
      await _audioPlayerService.playAsset(
        _normalizeAssetPath(sentenceAudioPath),
      );
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.sentenceLearningAudioFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _playbackSubmitting = false;
          _sentenceAudioPlaying = false;
        });
      }
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = _resolveL10n(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.sentenceLearningLoading)),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

String _normalizeAssetPath(String path) {
  var normalized = path.trim();
  if (normalized.startsWith('assets/')) {
    normalized = normalized.substring('assets/'.length);
  }
  if (normalized.startsWith('audio/sentences/')) {
    normalized = normalized.replaceFirst('audio/sentences/', 'audio/sentence/');
  }
  if (normalized.startsWith('audio/words/')) {
    normalized = normalized.replaceFirst('audio/words/', 'audio/word/');
  }
  return 'assets/$normalized';
}

List<ThaiWordContent> _relatedWordsForSentence({
  required String category,
  required String sentenceId,
  required String sentenceThaiText,
}) {
  final normalizedSentence = _normalizeThaiTextForWordMatch(sentenceThaiText);
  final matchedWords = wordsByCategory(category)
      .where((word) => _containsSentenceId(word.linkedSentenceIds, sentenceId))
      .where((word) {
        final normalizedWord = _normalizeThaiTextForWordMatch(word.thaiWord);
        if (normalizedWord.isEmpty || normalizedSentence.isEmpty) {
          return false;
        }
        return normalizedSentence.contains(normalizedWord);
      })
      .toList();

  final majorWords = matchedWords
      .where((word) => word.wordType.toLowerCase() != 'particle')
      .toList();
  final wordsForUi = majorWords.isNotEmpty ? majorWords : matchedWords;
  return wordsForUi.take(8).toList();
}

ThaiSentenceContent _resolveCanonicalSentence({
  required String category,
  required SentenceLearningItem item,
}) {
  final sentences = sentencesByCategory(category);
  if (sentences.isEmpty) {
    return sentenceAt(category, 0);
  }

  for (final sentence in sentences) {
    if (sentence.id == item.itemId) {
      return sentence;
    }
  }

  if (item.order > 0 && item.order <= sentences.length) {
    return sentences[item.order - 1];
  }

  final trailingNumber = RegExp(r'(\d+)$').firstMatch(item.itemId)?.group(1);
  final parsedOrder = trailingNumber == null
      ? null
      : int.tryParse(trailingNumber);
  if (parsedOrder != null &&
      parsedOrder > 0 &&
      parsedOrder <= sentences.length) {
    return sentences[parsedOrder - 1];
  }

  final normalizedItemThai = _normalizeThaiText(item.thaiText);
  for (final sentence in sentences) {
    if (_normalizeThaiText(sentence.thaiText) == normalizedItemThai) {
      return sentence;
    }
  }

  return sentences.first;
}

String _normalizeThaiText(String text) {
  return text.replaceAll(RegExp(r'\s+'), '').trim();
}

String _normalizeThaiTextForWordMatch(String text) {
  return text
      .replaceAll(RegExp("[\\s\\(\\)\\[\\]\\{\\}/,.;:!?_\"']"), '')
      .replaceAll('ๆ', '')
      .replaceAll('ฯ', '')
      .trim();
}

bool _containsSentenceId(String linkedSentenceIds, String sentenceId) {
  return linkedSentenceIds
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .contains(sentenceId);
}

AppLocalizations _resolveL10n(BuildContext context) {
  return AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ko'));
}

String _categoryLabel(LearningCategory category, AppLocalizations l10n) =>
    switch (category) {
      LearningCategory.daily => l10n.learningSelectCategoryDaily,
      LearningCategory.mission => l10n.learningSelectCategoryMission,
    };

String _levelLabel(LearningLevel level, AppLocalizations l10n) =>
    switch (level) {
      LearningLevel.beginner => l10n.learningSelectLevelBeginner,
      LearningLevel.intermediate => l10n.learningSelectLevelIntermediate,
      LearningLevel.advanced => l10n.learningSelectLevelAdvanced,
    };

String _modeLabel(LearningMode mode, AppLocalizations l10n) => switch (mode) {
      LearningMode.sentenceLearning => l10n.learningSelectModeSentenceLearning,
      LearningMode.sentenceTest => l10n.learningSelectModeSentenceTest,
      LearningMode.flashWordLearning => l10n.learningSelectModeFlashWordLearning,
      LearningMode.flashWordTest => l10n.learningSelectModeFlashWordTest,
      LearningMode.flashSentenceLearning =>
        l10n.learningSelectModeFlashSentenceLearning,
      LearningMode.flashSentenceTest => l10n.learningSelectModeFlashSentenceTest,
    };
