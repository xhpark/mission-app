import 'dart:typed_data';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/services/learning_preferences_controller.dart';
import '../../../../core/services/recorder_service.dart';
import '../../../../core/services/recording_storage_service.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../../core/widgets/learning_action_styles.dart';
import '../../../../core/widgets/learning_text_emphasis.dart';
import '../../../../core/widgets/selection_summary_line.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/domain/learning_selection_labels.dart'
    as labels;
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../data/models/sentence_learning_item.dart';
import '../auto_scroll_timing.dart';
import '../controllers/current_study_session_controller.dart';
import '../controllers/sentence_learning_controller.dart';

class SentenceLearningScreen extends ConsumerStatefulWidget {
  const SentenceLearningScreen({super.key});

  @override
  ConsumerState<SentenceLearningScreen> createState() =>
      _SentenceLearningScreenState();
}

class _SentenceLearningScreenState
    extends ConsumerState<SentenceLearningScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _advanceButtonKey = GlobalKey();
  Timer? _autoScrollTimer;
  String _scheduledItemId = '';
  bool _userEngagedThisItem = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면이 백그라운드로 가면 예약된 자동 스크롤을 취소한다(플래시 화면과 동일 정책).
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _autoScrollTimer?.cancel();
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  /// 새 아이템이 들어오면 자동 스크롤을 (재)예약한다. itemId가 같으면 무시(중복 방지).
  void _maybeScheduleAutoScroll(SentenceLearningItem? item) {
    if (item == null) {
      return;
    }
    if (item.itemId == _scheduledItemId) {
      return;
    }
    _scheduledItemId = item.itemId;
    _userEngagedThisItem = false;
    _autoScrollTimer?.cancel();

    if (!ref.read(learningPreferencesProvider).autoScrollEnabled) {
      return;
    }

    final contentCharCount =
        item.nativeText.length +
        item.thaiText.length +
        item.pronunciation.length +
        item.hint.length;
    final delay = computeAutoScrollDelay(contentCharCount: contentCharCount);

    _autoScrollTimer = Timer(delay, () {
      if (!mounted || _userEngagedThisItem) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _userEngagedThisItem) {
          return;
        }
        final targetContext = _advanceButtonKey.currentContext;
        if (targetContext == null) {
          return;
        }
        // alignment: 1.0 -> 버튼을 화면 하단에 띄우며 위쪽 내용은 그대로 남긴다.
        Scrollable.ensureVisible(
          targetContext,
          alignment: 1.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  /// 사용자가 직접 스크롤하거나 녹음을 시작하면 이번 아이템의 자동 스크롤을 무효화한다.
  void _markUserEngaged() {
    _userEngagedThisItem = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _resolveL10n(context);
    final session = ref.watch(currentStudySessionProvider);
    final sentenceItemState = ref.watch(sentenceLearningControllerProvider);

    ref.listen(sentenceLearningControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (item) => _maybeScheduleAutoScroll(item),
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(toUserFacingErrorMessage(error))),
          );
        },
      );
    });
    // 첫 빌드에서 데이터가 이미 준비된 경우 listen이 안 잡으므로 보조 예약.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeScheduleAutoScroll(sentenceItemState.asData?.value);
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
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          // 사용자가 직접 스크롤하면 이번 아이템 자동 스크롤을 취소한다.
          if (notification.direction != ScrollDirection.idle) {
            _markUserEngaged();
          }
          return false;
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            SelectionSummaryLine(
              labels: [
                labels.categoryLabel(session.category, l10n),
                labels.levelLabel(session.level, l10n),
                labels.modeLabel(session.mode, l10n),
              ],
            ),
            const SizedBox(height: 12),
            AppSectionCard(
              title: l10n.sentenceLearningSectionTitle,
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
                              advanceButtonKey: _advanceButtonKey,
                              onUserEngaged: _markUserEngaged,
                              onComplete: () => ref
                                  .read(
                                    sentenceLearningControllerProvider.notifier,
                                  )
                                  .completeCurrentItem(),
                              onDone: () => context.go('/session-summary'),
                            ),
                      loading: () => const _LoadingCard(),
                      error: (error, _) => _PlaceholderCard(
                        message: l10n.sentenceLearningLoadError(
                          error.toString(),
                        ),
                      ),
                    )
                  : _PlaceholderCard(message: l10n.sentenceLearningPlaceholder),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceItemCard extends StatefulWidget {
  const _SentenceItemCard({
    required this.item,
    required this.category,
    required this.isLoading,
    required this.advanceButtonKey,
    required this.onUserEngaged,
    required this.onComplete,
    required this.onDone,
  });

  final SentenceLearningItem item;
  final String category;
  final bool isLoading;
  final GlobalKey advanceButtonKey;
  final VoidCallback onUserEngaged;
  final VoidCallback onComplete;
  final VoidCallback onDone;

  @override
  State<_SentenceItemCard> createState() => _SentenceItemCardState();
}

class _SentenceItemCardState extends State<_SentenceItemCard>
    with WidgetsBindingObserver {
  static const double _maxRecordingSeconds = 5;

  late final RecorderService _recorderService;
  late final AudioPlayerService _audioPlayerService;
  late final RecordingStorageService _recordingStorageService;

  Timer? _recordingTimer;
  Uint8List? _recordedWavBytes;
  String? _currentRecordingPath;
  bool _recording = false;
  bool _recordingSubmitting = false;
  bool _playbackSubmitting = false;
  bool _sentenceAudioPlaying = false;
  bool _recordingPlayedOnce = false;
  double _remainingRecordSeconds = _maxRecordingSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorderService = RecorderService();
    _audioPlayerService = AudioPlayerService();
    _recordingStorageService = RecordingStorageService();
    _refreshCurrentRecordingState();
  }

  @override
  void didUpdateWidget(covariant _SentenceItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.sessionId != widget.item.sessionId ||
        oldWidget.item.itemId != widget.item.itemId) {
      _resetRecordingStateForCurrentSentence();
      _refreshCurrentRecordingState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _recorderService.dispose();
    _audioPlayerService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _pauseForLifecycle();
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _pauseForLifecycle() {
    _recordingTimer?.cancel();
    unawaited(_audioPlayerService.stop());
    if (_recorderService.isRecording) {
      unawaited(_recorderService.stop());
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _recording = false;
      _recordingSubmitting = false;
      _playbackSubmitting = false;
      _sentenceAudioPlaying = false;
      _remainingRecordSeconds = _maxRecordingSeconds;
    });
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 680;
              final sentenceInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canonicalSentence.koreanText,
                    style: LearningTextEmphasis.supportingMeaning(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${l10n.sentenceLearningPronunciationLabel}: ${canonicalSentence.phonetic} / ${canonicalSentence.hangulPronunciation}',
                    style: LearningTextEmphasis.pronunciation(context),
                  ),
                ],
              );
              final listenButton = OutlinedButton.icon(
                onPressed: _playbackSubmitting
                    ? null
                    : () => _playSentenceAudio(
                        sentenceAudioPath: sentenceAudioPath,
                        l10n: l10n,
                      ),
                style: LearningActionStyles.prominentOutlined(context),
                icon: const Icon(Icons.volume_up_outlined, size: 22),
                label: Text(l10n.sentenceLearningListenSentence),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sentenceInfo,
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: listenButton),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: sentenceInfo),
                  const SizedBox(width: 16),
                  SizedBox(width: 260, child: listenButton),
                ],
              );
            },
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
                  Expanded(
                    child: Text(
                      canonicalSentence.thaiText,
                      style: LearningTextEmphasis.foreignScript(context)
                          ?.copyWith(
                            color: _sentenceAudioPlaying
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
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
          if (_recording) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (_remainingRecordSeconds / _maxRecordingSeconds).clamp(
                  0,
                  1,
                ),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '녹음 남은 시간: ${_remainingRecordSeconds.ceil()}초',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if (_recordedWavBytes != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _playbackSubmitting || !_recordingPlayedOnce
                  ? null
                  : _playMyRecording,
              style: LearningActionStyles.prominentOutlined(context),
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(
                _recordingPlayedOnce
                    ? l10n.interactiveMyRecordingListen
                    : '자동 재생 중...',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${l10n.sentenceLearningHintLabel}: ${formatThaiTokensForLearners(canonicalSentence.hint)}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 20),
          ),
          if (relatedWords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.sentenceLearningKeyWordsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final labelMaxWidth = constraints.maxWidth < 560
                    ? constraints.maxWidth - 56
                    : 500.0;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: relatedWords
                      .map(
                        (word) => _KeyWordChip(
                          label: _relatedWordLabel(word),
                          maxWidth: labelMaxWidth < 180 ? 180 : labelMaxWidth,
                          onTap: () => _audioPlayerService.playAsset(
                            _normalizeAssetPath(word.audioPath),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.sentenceLearningProgress(
              widget.item.currentStep,
              widget.item.totalSteps,
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 16),
          if (widget.item.sessionCompleted)
            Column(
              key: widget.advanceButtonKey,
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
              key: widget.advanceButtonKey,
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
    widget.onUserEngaged();
    setState(() => _recordingSubmitting = true);
    try {
      await _recorderService.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _recording = true;
        _remainingRecordSeconds = _maxRecordingSeconds;
      });
      _startRecordingTimer();
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
    final sentenceKey = _currentSentenceRecordingKey();
    if (!_recording || _recordingSubmitting) {
      return;
    }
    _recordingTimer?.cancel();
    setState(() => _recordingSubmitting = true);
    try {
      final clip = await _recorderService.stop();
      if (!mounted) {
        return;
      }
      final bytes = clip?.wavBytes;
      final recordingPath = bytes == null
          ? null
          : await _recordingStorageService.saveRecording(
              lessonId: sentenceKey.lessonId,
              sentenceId: sentenceKey.sentenceId,
              bytes: bytes,
            );
      if (!mounted || !_isSameSentenceKey(sentenceKey)) {
        return;
      }
      setState(() {
        _recording = false;
        _recordedWavBytes = bytes;
        _currentRecordingPath = recordingPath;
        _remainingRecordSeconds = 0;
        _recordingPlayedOnce = false;
      });
      await _playMyRecording(autoplay: true);
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

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || !_recording) {
        timer.cancel();
        return;
      }

      final next = _remainingRecordSeconds - 0.1;
      if (next <= 0) {
        setState(() => _remainingRecordSeconds = 0);
        timer.cancel();
        _onStopRecording();
        return;
      }

      setState(() => _remainingRecordSeconds = next);
    });
  }

  Future<void> _playMyRecording({bool autoplay = false}) async {
    final bytes = _recordedWavBytes;
    if (_currentRecordingPath == null || bytes == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('먼저 녹음해 주세요.')));
      return;
    }
    if (_playbackSubmitting) {
      return;
    }
    var played = false;
    try {
      setState(() => _playbackSubmitting = true);
      await _audioPlayerService.playWavBytes(bytes);
      played = true;
    } finally {
      if (mounted) {
        setState(() {
          _playbackSubmitting = false;
          if (autoplay && played) {
            _recordingPlayedOnce = true;
          }
        });
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

  void _resetRecordingStateForCurrentSentence() {
    _recordingTimer?.cancel();
    _recordedWavBytes = null;
    _currentRecordingPath = null;
    _recording = false;
    _recordingSubmitting = false;
    _playbackSubmitting = false;
    _recordingPlayedOnce = false;
    _remainingRecordSeconds = _maxRecordingSeconds;
  }

  Future<void> _refreshCurrentRecordingState() async {
    final sentenceKey = _currentSentenceRecordingKey();
    if (mounted) {
      setState(() {
        _recordedWavBytes = null;
        _currentRecordingPath = null;
        _recordingPlayedOnce = false;
      });
    }

    final recordingPath = await _recordingStorageService.findRecordingPath(
      lessonId: sentenceKey.lessonId,
      sentenceId: sentenceKey.sentenceId,
    );
    final bytes = recordingPath == null
        ? null
        : await _recordingStorageService.readRecording(
            lessonId: sentenceKey.lessonId,
            sentenceId: sentenceKey.sentenceId,
          );

    if (!mounted || !_isSameSentenceKey(sentenceKey)) {
      return;
    }
    setState(() {
      _currentRecordingPath = bytes == null ? null : recordingPath;
      _recordedWavBytes = bytes;
      _recordingPlayedOnce = bytes != null;
    });
  }

  _SentenceRecordingKey _currentSentenceRecordingKey() {
    return _SentenceRecordingKey(
      lessonId: widget.item.sessionId,
      sentenceId: widget.item.itemId,
    );
  }

  bool _isSameSentenceKey(_SentenceRecordingKey key) {
    return key.lessonId == widget.item.sessionId &&
        key.sentenceId == widget.item.itemId;
  }
}

class _SentenceRecordingKey {
  const _SentenceRecordingKey({
    required this.lessonId,
    required this.sentenceId,
  });

  final String lessonId;
  final String sentenceId;
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

/// A chip-like label for a key word, built from scratch instead of
/// [ActionChip]. Material's [Chip] forces its label into a
/// `DefaultTextStyle(maxLines: 1, softWrap: false)`, which clips long
/// Korean/Thai word explanations to a single line no matter what the inner
/// [Text] requests. This widget has no such constraint, so the chip grows to
/// fit however many lines the label needs.
class _KeyWordChip extends StatelessWidget {
  const _KeyWordChip({
    required this.label,
    required this.maxWidth,
    required this.onTap,
  });

  final String label;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.volume_up_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    style: LearningTextEmphasis.optionPronunciation(
                      context,
                    )?.copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  final matchedWords =
      wordsByCategory(category)
          .where(
            (word) => _containsSentenceId(word.linkedSentenceIds, sentenceId),
          )
          .where((word) {
            final normalizedWord = _normalizeThaiTextForWordMatch(
              word.thaiWord,
            );
            if (normalizedWord.isEmpty || normalizedSentence.isEmpty) {
              return false;
            }
            return normalizedSentence.contains(normalizedWord);
          })
          .toList()
        ..sort((a, b) {
          final aPos = normalizedSentence.indexOf(
            _normalizeThaiTextForWordMatch(a.thaiWord),
          );
          final bPos = normalizedSentence.indexOf(
            _normalizeThaiTextForWordMatch(b.thaiWord),
          );
          final aIndex = aPos < 0 ? 9999 : aPos;
          final bIndex = bPos < 0 ? 9999 : bPos;
          if (aIndex != bIndex) {
            return aIndex.compareTo(bIndex);
          }
          return a.orderNo.compareTo(b.orderNo);
        });

  // Previously, any particle-typed word (e.g. honorific helpers) was dropped
  // outright whenever another non-particle word also matched the same
  // sentence. That made some linked word entries (like "ทรง") permanently
  // unreachable in the UI even though they were correctly tagged to a
  // sentence. Keep every matched word, already sorted by where it appears in
  // the sentence, so learners can see every linked word that's actually
  // present in the text.
  return _dedupeRelatedWords(matchedWords).take(8).toList();
}

List<ThaiWordContent> _dedupeRelatedWords(List<ThaiWordContent> words) {
  final seenThaiTokens = <String>{};
  final deduped = <ThaiWordContent>[];
  for (final word in words) {
    final normalizedThai = _normalizeThaiTextForWordMatch(word.thaiWord);
    if (normalizedThai.isEmpty || seenThaiTokens.add(normalizedThai)) {
      deduped.add(word);
    }
  }
  return deduped;
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

String _relatedWordLabel(ThaiWordContent word) {
  if (word.id == 'THW_D001') {
    return '남성 공손: 크랍';
  }
  if (word.id == 'THW_D002') {
    return '여성 공손: 카';
  }
  return '${word.koreanMeaning}: ${formatThaiWithHangul(word.thaiWord, fallbackHangul: word.hangulPronunciation)}';
}

AppLocalizations _resolveL10n(BuildContext context) {
  return AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ko'));
}

