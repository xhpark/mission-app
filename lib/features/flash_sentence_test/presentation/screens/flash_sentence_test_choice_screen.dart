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
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/domain/test_item_order.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../session_runtime/presentation/providers/session_runtime_providers.dart';

class FlashSentenceTestChoiceScreen extends ConsumerStatefulWidget {
  const FlashSentenceTestChoiceScreen({super.key});

  @override
  ConsumerState<FlashSentenceTestChoiceScreen> createState() =>
      _FlashSentenceTestChoiceScreenState();
}

class _FlashSentenceTestChoiceScreenState
    extends ConsumerState<FlashSentenceTestChoiceScreen>
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
    final sentences = sentencesByCategory(category);
    final effectiveTotal = _effectiveTotal(flow.totalItems, sentences.length);

    if (sentences.isEmpty || effectiveTotal <= 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.flashSentenceTestChoiceTitle ?? '플래시 문장 테스트 - 선택형'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/flash-sentence-test-select'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            AppSectionCard(
              title: '콘텐츠 확인 필요',
              description: '현재 카테고리에서 테스트 가능한 문장이 없습니다.',
              icon: Icons.warning_amber_outlined,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    final maxIndex = effectiveTotal - 1;
    final displayIndex = flow
        .indexOf(StudyFlowTrack.flashSentenceTestChoice)
        .clamp(0, maxIndex)
        .toInt();
    final targetIndex = resolveTestContentIndex(
      displayIndex: displayIndex,
      itemCount: effectiveTotal,
      levelName: session?.level.name,
      seedKey: session?.sessionId ?? 'dev',
      orderKey: 'flash-sentence-test',
    );
    final target = sentences[targetIndex];
    final choice = sentenceThaiOptions(
      category: category,
      correctIndex: targetIndex,
      seedKey: session?.sessionId ?? 'dev',
    );
    final optionAudioPaths = choice.options
        .asMap()
        .entries
        .map(
          (entry) => choice.audioPathAt(
            entry.key,
            fallback: _findSentenceAudioPath(
              category: category,
              thaiText: entry.value,
              sentenceId: choice.optionIdAt(entry.key),
              fallbackAudioPath: target.audioPath,
            ),
          ),
        )
        .toList();
    final timeLimitSeconds = _choiceTimeLimitByLevel(session?.level.name);

    _ensureActiveItem(itemId: target.id, timeLimitSeconds: timeLimitSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.flashSentenceTestChoiceTitle ?? '플래시 문장 테스트 - 선택형'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () {
            final moved = ref
                .read(studyFlowControllerProvider.notifier)
                .retreatTrack(track: StudyFlowTrack.flashSentenceTestChoice);
            if (moved) {
              return;
            }
            context.go('/flash-sentence-test-select');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
                key: ValueKey('flash-sentence-test-${target.id}'),
                title: '뜻 보고 고르기',
                description: '제시된 한국어에 맞는 태국어 문장을 고르세요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.koreanText,
                      style: LearningTextEmphasis.meaningPrompt(context),
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(choice.options.length, (index) {
                      final option = _formatSentenceOptionLabel(
                        category: category,
                        thaiText: choice.options[index],
                        sentenceId: choice.optionIdAt(index),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => _handleOptionSelected(
                                    selectedIndex: index,
                                    correctIndex: choice.correctIndex,
                                    itemId: target.id,
                                    selectedAudioPath: optionAudioPaths[index],
                                  ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                option,
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
    setState(() => _timerPaused = !_timerPaused);
  }

  Future<bool> _playPromptAudio(String audioPath) async {
    final player = _audioPlayerService;
    if (!_audioReady || player == null || audioPath.isEmpty) {
      return false;
    }
    try {
      await player.playAsset(audioPath);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Flash sentence choice audio failed: $audioPath');
      debugPrint('$error\n$stackTrace');
      return false;
    }
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
          route: '/flash-sentence-test/choice',
        );
  }

  Future<void> _handleOptionSelected({
    required int selectedIndex,
    required int correctIndex,
    required String itemId,
    required String selectedAudioPath,
  }) async {
    await _advanceToNext(
      selectedIndex: selectedIndex,
      correctIndex: correctIndex,
      itemId: itemId,
      selectedAudioPath: selectedAudioPath,
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
    final sentences = sentencesByCategory(session?.category.name ?? 'daily');
    final effectiveTotal = _effectiveTotal(flow.totalItems, sentences.length);
    final currentDisplayIndex = flow
        .indexOf(StudyFlowTrack.flashSentenceTestChoice)
        .clamp(0, effectiveTotal - 1)
        .toInt();
    final currentContentIndex = resolveTestContentIndex(
      displayIndex: currentDisplayIndex,
      itemCount: effectiveTotal,
      levelName: session?.level.name,
      seedKey: session?.sessionId ?? 'dev',
      orderKey: 'flash-sentence-test',
    );
    final currentSentence = sentences[currentContentIndex];
    // Reconstruct the deterministic option layout to recover the chosen option's
    // item id, which is the authoritative grading signal sent to the server.
    final currentChoice = sentenceThaiOptions(
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

    if (!timedOut) {
      final played = await _playPromptAudio(selectedAudioPath ?? '');
      if (!played && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 보기의 음성을 재생하지 못했습니다.')),
        );
      }
    }

    if (session != null &&
        user != null &&
        !user.isAnonymous &&
        !developmentSession) {
      final repository = ref.read(sessionRuntimeRepositoryProvider);
      try {
        await repository.submitChoiceTestItem(
          userId: user.uid,
          sessionId: session.sessionId,
          itemId: itemId ?? currentSentence.id,
          selectedItemId: selectedItemId,
          selectedIndex: selectedIndex,
          correctIndex: normalizedCorrectIndex,
          elapsedSeconds: _activeTimeLimit - _remainingSeconds,
        );

        if (hasNext) {
          await repository.saveResumeState(
            userId: user.uid,
            sessionId: session.sessionId,
            route: '/flash-sentence-test/choice',
          );
        } else {
          await repository.discardResumeState(
            userId: user.uid,
            sessionId: session.sessionId,
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Flash sentence choice progress save failed: $error\n$stackTrace',
        );
      }
    }

    if (!mounted) {
      return;
    }
    ref
        .read(studyFlowControllerProvider.notifier)
        .advanceTrack(
          track: StudyFlowTrack.flashSentenceTestChoice,
          totalCount: effectiveTotal,
          isCorrectAttempt: isCorrectAttempt,
          countAsAttempt: true,
        );
    if (!hasNext) {
      context.go('/flash-sentence-test/speaking');
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

String _formatSentenceOptionLabel({
  required String category,
  required String thaiText,
  String sentenceId = '',
}) {
  final sentence = _findSentenceOption(
    category: category,
    thaiText: thaiText,
    sentenceId: sentenceId,
  );
  final hangul = sentence?.hangulPronunciation.trim() ?? '';
  if (hangul.isEmpty) {
    return thaiText;
  }
  return '$hangul ($thaiText)';
}

String _findSentenceAudioPath({
  required String category,
  required String thaiText,
  required String fallbackAudioPath,
  String sentenceId = '',
}) {
  final sentence = _findSentenceOption(
    category: category,
    thaiText: thaiText,
    sentenceId: sentenceId,
  );
  return sentence?.audioPath ?? fallbackAudioPath;
}

ThaiSentenceContent? _findSentenceOption({
  required String category,
  required String thaiText,
  required String sentenceId,
}) {
  final sentences = sentencesByCategory(category);
  if (sentenceId.trim().isNotEmpty) {
    for (final sentence in sentences) {
      if (sentence.id == sentenceId) {
        return sentence;
      }
    }
  }
  final normalizedThai = thaiText.trim();
  for (final sentence in sentences) {
    if (sentence.thaiText.trim() == normalizedThai) {
      return sentence;
    }
  }
  return null;
}
