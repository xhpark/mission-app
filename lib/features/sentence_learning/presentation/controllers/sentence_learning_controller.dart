import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../learning_content/data/thai_learning_content.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../data/models/sentence_learning_item.dart';
import 'current_study_session_controller.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';

class SentenceLearningController extends AsyncNotifier<SentenceLearningItem?> {
  @override
  Future<SentenceLearningItem?> build() async {
    // Source-of-truth: sentence learning content is served from local bundled
    // content (thai_learning_content.dart). Backend callable item fetch path
    // is intentionally not used in the learner flow.
    final session = ref.watch(currentStudySessionProvider);

    if (session == null) {
      return null;
    }

    if (session.mode != LearningMode.sentenceLearning) {
      return null;
    }

    final index = ref.read(studyFlowControllerProvider).indexOf(
          StudyFlowTrack.sentenceLearning,
        );
    return _localItemForStep(
      session: session,
      step: index + 1,
      sessionCompleted: false,
    );
  }

  Future<void> completeCurrentItem() async {
    final session = ref.read(currentStudySessionProvider);
    final currentItem = state.asData?.value;

    if (session == null || currentItem == null) {
      throw StateError('An active sentence learning item is required.');
    }

    if (currentItem.sessionCompleted) {
      return;
    }

    final hasNext = ref.read(studyFlowControllerProvider.notifier).advanceTrack(
          track: StudyFlowTrack.sentenceLearning,
          totalCount: _totalStepsForSession(session),
        );
    final nextStep = hasNext
        ? ref.read(studyFlowControllerProvider).indexOf(
              StudyFlowTrack.sentenceLearning,
            ) +
            1
        : currentItem.totalSteps;
    final totalSteps = _totalStepsForSession(session);
    final completed = !hasNext;
    final safeStep = completed ? totalSteps : nextStep;
    state = AsyncData(
      _localItemForStep(
        session: session,
        step: safeStep,
        sessionCompleted: completed,
      ),
    );
  }

  int _totalStepsForSession(CurrentStudySession session) {
    final category = session.category.name;
    final sentences = sentencesByCategory(category);
    return sentences.isEmpty ? 1 : sentences.length;
  }

  SentenceLearningItem _localItemForStep({
    required CurrentStudySession session,
    required int step,
    required bool sessionCompleted,
  }) {
    final category = session.category.name;
    final totalSteps = _totalStepsForSession(session);
    final content = sentenceAt(category, step - 1);
    return SentenceLearningItem(
      sessionId: session.sessionId,
      contentSetId: session.contentSetId,
      itemId: content.id,
      order: content.orderNo,
      thaiText: content.thaiText,
      nativeText: content.koreanText,
      pronunciation: '${content.phonetic} / ${content.hangulPronunciation}',
      hint: content.hint,
      audioPath: content.audioPath,
      audioUrl: content.audioUrl,
      currentStep: step,
      totalSteps: totalSteps,
      sessionCompleted: sessionCompleted,
    );
  }
}

final sentenceLearningControllerProvider = AsyncNotifierProvider<
    SentenceLearningController, SentenceLearningItem?>(
  SentenceLearningController.new,
);
