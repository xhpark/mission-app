import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/learning_action_styles.dart';
import '../../../../core/widgets/learning_text_emphasis.dart';
import '../../../../core/widgets/selection_summary_line.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/domain/learning_selection_labels.dart'
    as labels;
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashSentenceLearningScreen extends ConsumerStatefulWidget {
  const FlashSentenceLearningScreen({super.key});

  @override
  ConsumerState<FlashSentenceLearningScreen> createState() =>
      _FlashSentenceLearningScreenState();
}

class _FlashSentenceLearningScreenState
    extends ConsumerState<FlashSentenceLearningScreen>
    with WidgetsBindingObserver {
  AudioPlayerService? _audioPlayerService;
  bool _audioReady = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timerPaused = false;
  String _activeItemId = '';
  int _activeTimeLimit = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _audioPlayerService = AudioPlayerService();
      _audioReady = true;
    } catch (_) {
      _audioReady = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayerService?.dispose();
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
    _timer?.cancel();
    unawaited(_audioPlayerService?.stop());
    if (!mounted) {
      return;
    }
    if (_remainingSeconds > 0 && !_timerPaused) {
      setState(() => _timerPaused = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentStudySessionProvider);
    final flow = ref.watch(studyFlowControllerProvider);
    final category = session?.category.name ?? 'daily';
    final sentences = sentencesByCategory(category);
    final effectiveTotal = _effectiveTotal(flow.totalItems, sentences.length);

    if (sentences.isEmpty || effectiveTotal <= 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.flashSentenceLearningTitle ?? '플래시 문장 학습'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/select'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            AppSectionCard(
              title: '콘텐츠 확인 필요',
              description: '현재 카테고리에서 학습 가능한 문장이 없습니다.',
              icon: Icons.warning_amber_outlined,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    final maxIndex = effectiveTotal - 1;
    final targetIndex = flow
        .indexOf(StudyFlowTrack.flashSentenceLearning)
        .clamp(0, maxIndex);
    final target = sentences[targetIndex];
    final timeLimitSeconds = _itemTimeLimitByLevel(session?.level.name);

    _ensureActiveItem(
      itemId: target.id,
      timeLimitSeconds: timeLimitSeconds,
      audioPath: target.audioPath,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.flashSentenceLearningTitle ?? '플래시 문장 학습'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () {
            final moved = ref
                .read(studyFlowControllerProvider.notifier)
                .retreatTrack(track: StudyFlowTrack.flashSentenceLearning);
            if (moved) {
              return;
            }
            context.go('/select');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (session != null && l10n != null) ...[
            SelectionSummaryLine(
              labels: [
                labels.categoryLabel(session.category, l10n),
                labels.levelLabel(session.level, l10n),
                labels.modeLabel(session.mode, l10n),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...[
            AppSectionCard(
              title: '진행 상태',
              description: '현재 문장을 확인하세요.',
              icon: Icons.timelapse_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (targetIndex + 1) / effectiveTotal,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '문장 ${targetIndex + 1} / $effectiveTotal',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackButtons = constraints.maxWidth < 560;
                      final pauseButton = OutlinedButton.icon(
                        onPressed: _toggleTimerPause,
                        icon: Icon(
                          _timerPaused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(_timerPaused ? '다시 시작' : '잠시 중지'),
                      );
                      final stopButton = OutlinedButton.icon(
                        onPressed: () => context.go('/select'),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(stackButtons ? '중지' : '학습 중지'),
                      );

                      if (stackButtons) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: pauseButton,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: stopButton),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: pauseButton),
                          const SizedBox(width: 12),
                          Expanded(child: stopButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: AppSectionCard(
                key: ValueKey('flash-sentence-learning-${target.id}'),
                title: '오늘의 문장',
                description: '짧은 시간 안에 문장을 보고 듣고 익히세요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.thaiText,
                      style: LearningTextEmphasis.foreignScript(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      target.koreanText,
                      style: LearningTextEmphasis.supportingMeaning(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '발음: ${target.phonetic} / ${target.hangulPronunciation}',
                      style: LearningTextEmphasis.pronunciation(context),
                    ),
                    if (target.hint.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '힌트: ${formatThaiTokensForLearners(target.hint)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _audioReady
                            ? () => _playPromptAudio(target.audioPath)
                            : null,
                        style: LearningActionStyles.prominentOutlined(context),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('원어민 음성 재생'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ].reversed,
        ],
      ),
    );
  }

  void _ensureActiveItem({
    required String itemId,
    required int timeLimitSeconds,
    required String audioPath,
  }) {
    if (_activeItemId == itemId && _activeTimeLimit == timeLimitSeconds) {
      return;
    }
    _activeItemId = itemId;
    _activeTimeLimit = timeLimitSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _activeItemId != itemId) {
        return;
      }
      _startTimer(timeLimitSeconds);
      await _syncResumeState();
      if (_audioReady) {
        await _playPromptAudio(audioPath);
      }
    });
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
      _timerPaused = false;
    });
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _timerPaused) {
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        await _advanceToNext();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  void _toggleTimerPause() {
    if (_remainingSeconds <= 0) {
      return;
    }
    final resuming = _timerPaused;
    setState(() => _timerPaused = !_timerPaused);
    // A lifecycle pause (app backgrounded) cancels the Timer outright, not
    // just the _timerPaused flag, so resuming from that state needs a fresh
    // Timer — toggling the flag alone leaves the countdown permanently stuck.
    if (resuming && (_timer == null || !_timer!.isActive)) {
      _runTimer();
    }
  }

  Future<void> _playPromptAudio(String audioPath) async {
    final player = _audioPlayerService;
    if (!_audioReady || player == null || audioPath.isEmpty) {
      return;
    }
    try {
      await player.playAsset(audioPath);
    } catch (_) {}
  }

  Future<void> _syncResumeState() async {
    final session = ref.read(currentStudySessionProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (session == null ||
        user == null ||
        user.isAnonymous ||
        developmentSession) {
      return;
    }
    await ref
        .read(sessionRuntimeRepositoryProvider)
        .saveResumeState(
          userId: user.uid,
          sessionId: session.sessionId,
          route: '/flash-sentence-learning',
        );
  }

  Future<void> _advanceToNext() async {
    final session = ref.read(currentStudySessionProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    final flow = ref.read(studyFlowControllerProvider);
    final sentences = sentencesByCategory(session?.category.name ?? 'daily');
    final effectiveTotal = _effectiveTotal(flow.totalItems, sentences.length);
    final hasNext = ref
        .read(studyFlowControllerProvider.notifier)
        .advanceTrack(
          track: StudyFlowTrack.flashSentenceLearning,
          totalCount: effectiveTotal,
        );

    if (!hasNext) {
      if (session != null &&
          user != null &&
          !user.isAnonymous &&
          !developmentSession) {
        await ref
            .read(sessionRuntimeRepositoryProvider)
            .discardResumeState(userId: user.uid, sessionId: session.sessionId);
      }
      if (mounted) {
        context.go('/flash-sentence-test-select');
      }
    }
  }
}

int _effectiveTotal(int requestedTotal, int availableCount) {
  if (availableCount <= 0) {
    return 0;
  }
  if (requestedTotal <= 0 || requestedTotal > availableCount) {
    return availableCount;
  }
  return requestedTotal;
}

int _itemTimeLimitByLevel(String? levelName) {
  switch (levelName) {
    case 'intermediate':
      return 8;
    case 'advanced':
      return 6;
    default:
      return 10;
  }
}
