import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mission_app/l10n/app_localizations.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/app_status_banner.dart';
import '../../../../core/widgets/learning_text_emphasis.dart';
import '../../../../core/widgets/selection_summary_line.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/domain/learning_selection_labels.dart'
    as labels;
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/domain/test_item_order.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashWordTestScreen extends ConsumerStatefulWidget {
  const FlashWordTestScreen({super.key});

  @override
  ConsumerState<FlashWordTestScreen> createState() =>
      _FlashWordTestScreenState();
}

class _FlashWordTestScreenState extends ConsumerState<FlashWordTestScreen>
    with WidgetsBindingObserver {
  AudioPlayerService? _audioPlayerService;
  bool _audioReady = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _timerPaused = false;
  String _activeItemId = '';
  int _activeTimeLimit = 0;
  bool _submitting = false;

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
    final words = wordsByCategory(category);
    final effectiveTotal = _effectiveTotal(flow.totalItems, words.length);

    if (words.isEmpty || effectiveTotal <= 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.flashWordTestTitle ?? '플래시 단어 테스트'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/flash-word-test-select'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            AppSectionCard(
              title: '콘텐츠 확인 필요',
              description: '현재 카테고리에서 테스트 가능한 단어가 없습니다.',
              icon: Icons.warning_amber_outlined,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    final maxIndex = effectiveTotal - 1;
    final displayIndex = flow
        .indexOf(StudyFlowTrack.flashWordTest)
        .clamp(0, maxIndex)
        .toInt();
    final targetIndex = resolveTestContentIndex(
      displayIndex: displayIndex,
      itemCount: effectiveTotal,
      levelName: session?.level.name,
      seedKey: session?.sessionId ?? 'dev',
      orderKey: 'flash-word-test',
    );
    final target = words[targetIndex];
    final optionsSet = wordThaiOptions(
      category: category,
      correctIndex: targetIndex,
      seedKey: session?.sessionId ?? 'dev',
    );
    final optionAudioPaths = optionsSet.options
        .map(
          (thaiWord) => _findWordAudioPath(
            category: category,
            thaiWord: thaiWord,
            fallbackAudioPath: target.audioPath,
          ),
        )
        .toList();
    final timeLimitSeconds = _choiceTimeLimitByLevel(session?.level.name);

    _ensureActiveItem(itemId: target.id, timeLimitSeconds: timeLimitSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.flashWordTestTitle ?? '플래시 단어 테스트'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () {
            final moved = ref
                .read(studyFlowControllerProvider.notifier)
                .retreatTrack(track: StudyFlowTrack.flashWordTest);
            if (moved) {
              return;
            }
            context.go('/flash-word-test-select');
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
              description: '현재 문제를 확인하세요.',
              icon: Icons.timelapse_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (displayIndex + 1) / effectiveTotal,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '문항 ${displayIndex + 1} / $effectiveTotal',
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
                        label: Text(stackButtons ? '중지' : '테스트 중지'),
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
                key: ValueKey('flash-word-test-${target.id}'),
                title: '뜻 보고 고르기',
                description: '제시된 뜻에 맞는 태국어 단어를 선택하세요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.koreanMeaning,
                      style: LearningTextEmphasis.meaningPrompt(context),
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(optionsSet.options.length, (index) {
                      final option = optionsSet.options[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => _advanceToNext(
                                    selectedIndex: index,
                                    correctIndex: optionsSet.correctIndex,
                                    itemId: target.id,
                                    selectedAudioPath: optionAudioPaths[index],
                                  ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatWordOptionLabel(
                                  category: category,
                                  thaiWord: option,
                                ),
                                style: LearningTextEmphasis.optionPronunciation(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const AppStatusBanner(
                      tone: AppStatusTone.info,
                      message: '시간이 끝나면 자동으로 다음 문제로 넘어갑니다.',
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
    });
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
      _timerPaused = false;
      _submitting = false;
    });
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _timerPaused || _submitting) {
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        await _advanceToNext(
          selectedIndex: -1,
          correctIndex: -1,
          timedOut: true,
        );
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
          route: '/flash-word-test',
        );
  }

  Future<void> _advanceToNext({
    required int selectedIndex,
    required int correctIndex,
    String? itemId,
    String? selectedAudioPath,
    bool timedOut = false,
  }) async {
    if (_submitting) {
      return;
    }
    _timer?.cancel();
    setState(() => _submitting = true);

    final session = ref.read(currentStudySessionProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    final flow = ref.read(studyFlowControllerProvider);
    final words = wordsByCategory(session?.category.name ?? 'daily');
    final effectiveTotal = _effectiveTotal(flow.totalItems, words.length);
    final currentDisplayIndex = flow
        .indexOf(StudyFlowTrack.flashWordTest)
        .clamp(0, effectiveTotal - 1)
        .toInt();
    final currentContentIndex = resolveTestContentIndex(
      displayIndex: currentDisplayIndex,
      itemCount: effectiveTotal,
      levelName: session?.level.name,
      seedKey: session?.sessionId ?? 'dev',
      orderKey: 'flash-word-test',
    );
    final currentWord = words[currentContentIndex];
    // Reconstruct the deterministic option layout to recover the chosen option's
    // item id, which is the authoritative grading signal sent to the server.
    final currentChoice = wordThaiOptions(
      category: session?.category.name ?? 'daily',
      correctIndex: currentContentIndex,
      seedKey: session?.sessionId ?? 'dev',
    );
    final selectedItemId = timedOut
        ? ''
        : currentChoice.optionIdAt(selectedIndex);
    final normalizedCorrectIndex = timedOut ? -1 : correctIndex;

    final isCorrectAttempt =
        !timedOut &&
        selectedIndex >= 0 &&
        selectedIndex == normalizedCorrectIndex;
    final hasNext = currentDisplayIndex < effectiveTotal - 1;

    if (session != null &&
        user != null &&
        !user.isAnonymous &&
        !developmentSession) {
      final repository = ref.read(sessionRuntimeRepositoryProvider);
      try {
        await repository.submitChoiceTestItem(
          userId: user.uid,
          sessionId: session.sessionId,
          itemId: itemId ?? currentWord.id,
          selectedItemId: selectedItemId,
          selectedIndex: selectedIndex,
          correctIndex: normalizedCorrectIndex,
          elapsedSeconds: _activeTimeLimit - _remainingSeconds,
        );

        if (hasNext) {
          await repository.saveResumeState(
            userId: user.uid,
            sessionId: session.sessionId,
            route: '/flash-word-test',
          );
        } else {
          await repository.discardResumeState(
            userId: user.uid,
            sessionId: session.sessionId,
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Flash word choice progress save failed: $error\n$stackTrace',
        );
      }
    }

    if (!timedOut &&
        selectedAudioPath != null &&
        selectedAudioPath.isNotEmpty &&
        _audioReady) {
      await _playPromptAudio(selectedAudioPath);
    }

    if (!mounted) {
      return;
    }
    ref
        .read(studyFlowControllerProvider.notifier)
        .advanceTrack(
          track: StudyFlowTrack.flashWordTest,
          totalCount: effectiveTotal,
          isCorrectAttempt: isCorrectAttempt,
          countAsAttempt: true,
        );
    if (!hasNext) {
      context.go('/flash-word-test/speaking');
      return;
    }
    setState(() => _submitting = false);
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

int _choiceTimeLimitByLevel(String? levelName) {
  switch (levelName) {
    case 'intermediate':
      return 10;
    case 'advanced':
      return 8;
    default:
      return 12;
  }
}

String _formatWordOptionLabel({
  required String category,
  required String thaiWord,
}) {
  final matched = wordsByCategory(category).where((word) {
    return word.thaiWord.trim() == thaiWord.trim();
  });
  final word = matched.isEmpty ? null : matched.first;
  return formatThaiSoundChoiceLabel(
    thaiText: thaiWord,
    fallbackHangul: word?.hangulPronunciation,
    fallbackPhonetic: word?.phonetic,
  );
}

String _findWordAudioPath({
  required String category,
  required String thaiWord,
  required String fallbackAudioPath,
}) {
  final matched = wordsByCategory(category).where((word) {
    return word.thaiWord.trim() == thaiWord.trim();
  });
  final word = matched.isEmpty ? null : matched.first;
  return word?.audioPath ?? fallbackAudioPath;
}
