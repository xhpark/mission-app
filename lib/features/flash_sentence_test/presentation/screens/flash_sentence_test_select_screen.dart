import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../learning_content/data/thai_learning_content.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';

class FlashSentenceTestSelectScreen extends ConsumerWidget {
  const FlashSentenceTestSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플래시 문장 테스트 선택'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/flash-sentence-learning');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '다음 단계를 선택해 주세요',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '선택형 테스트, 말하기 테스트, 플래시문장 재학습 중 하나를 선택할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _ActionButton(
              label: '선택형 테스트 시작',
              onPressed: () {
                _ensureSessionAndFlow(
                  ref,
                  mode: LearningMode.flashSentenceTest,
                );
                ref
                    .read(studyFlowControllerProvider.notifier)
                    .resetTrack(track: StudyFlowTrack.flashSentenceTestChoice);
                context.go('/flash-sentence-test/choice');
              },
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: '말하기 테스트 시작',
              onPressed: () {
                _ensureSessionAndFlow(
                  ref,
                  mode: LearningMode.flashSentenceTest,
                );
                ref
                    .read(studyFlowControllerProvider.notifier)
                    .resetTrack(
                      track: StudyFlowTrack.flashSentenceTestSpeaking,
                    );
                context.go('/flash-sentence-test/speaking');
              },
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: '플래시문장 재학습',
              onPressed: () {
                _ensureSessionAndFlow(
                  ref,
                  mode: LearningMode.flashSentenceLearning,
                );
                final controller = ref.read(
                  studyFlowControllerProvider.notifier,
                );
                controller.resetTrack(
                  track: StudyFlowTrack.flashSentenceLearning,
                );
                controller.resetTrack(
                  track: StudyFlowTrack.flashSentenceTestChoice,
                );
                controller.resetTrack(
                  track: StudyFlowTrack.flashSentenceTestSpeaking,
                );
                context.go('/flash-sentence-learning');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _ensureSessionAndFlow(WidgetRef ref, {required LearningMode mode}) {
    final sessionController = ref.read(currentStudySessionProvider.notifier);
    var session = ref.read(currentStudySessionProvider);
    if (session == null) {
      final now = DateTime.now().toIso8601String();
      session = CurrentStudySession(
        sessionId: 'dev-local-$now',
        startedAt: now,
        contentSetId: 'daily-beginner-default',
        category: LearningCategory.daily,
        level: LearningLevel.beginner,
        mode: mode,
      );
      sessionController.setSession(session);
    }

    final sentences = sentencesByCategory(session.category.name);
    final fallbackSentences = sentencesByCategory('daily');
    final totalItems = sentences.isNotEmpty
        ? sentences.length
        : fallbackSentences.length;
    final flow = ref.read(studyFlowControllerProvider);
    if (flow.sessionId.isEmpty || flow.totalItems <= 0) {
      ref
          .read(studyFlowControllerProvider.notifier)
          .startSession(sessionId: session.sessionId, totalItems: totalItems);
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
