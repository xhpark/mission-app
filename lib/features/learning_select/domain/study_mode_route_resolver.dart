import '../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../presentation/controllers/learning_selection_controller.dart';

String routeForLearningMode(LearningMode mode) => switch (mode) {
  LearningMode.sentenceLearning => '/sentence-learning',
  LearningMode.sentenceTest => '/sentence-test/choice',
  LearningMode.flashWordLearning => '/flash-word-learning',
  LearningMode.flashWordTest => '/flash-word-test',
  LearningMode.flashSentenceLearning => '/flash-sentence-learning',
  LearningMode.flashSentenceTest => '/flash-sentence-test-select',
};

String routeForSelectionOrFallback(LearningSelectionState selection) {
  final mode = selection.mode;
  if (mode == null) {
    return '/select';
  }

  return routeForLearningMode(mode);
}

/// Resolves where an in-progress session should resume, based on which
/// choice/speaking tracks for [mode] have actually been completed.
///
/// [routeForLearningMode] only knows the mode's default entry screen, so
/// resuming a two-stage test (choice -> speaking) always restarted at the
/// first stage, even after the learner had already finished both stages and
/// was simply waiting to submit a report. That left them stuck cycling
/// through the test screens with no way to reach the report or home screen.
String resumeRouteForSession(LearningMode mode, StudyFlowState flow) {
  switch (mode) {
    case LearningMode.sentenceTest:
      if (flow.isTrackCompleted(StudyFlowTrack.sentenceTestSpeaking)) {
        return '/session-summary';
      }
      if (flow.isTrackCompleted(StudyFlowTrack.sentenceTestChoice)) {
        return '/sentence-test/speaking';
      }
      return '/sentence-test/choice';
    case LearningMode.flashWordTest:
      if (flow.isTrackCompleted(StudyFlowTrack.flashWordTestSpeaking)) {
        return '/session-summary';
      }
      if (flow.isTrackCompleted(StudyFlowTrack.flashWordTest)) {
        return '/flash-word-test/speaking';
      }
      return '/flash-word-test';
    case LearningMode.flashSentenceTest:
      if (flow.isTrackCompleted(StudyFlowTrack.flashSentenceTestSpeaking)) {
        return '/session-summary';
      }
      if (flow.isTrackCompleted(StudyFlowTrack.flashSentenceTestChoice)) {
        return '/flash-sentence-test/speaking';
      }
      if (flow.indexOf(StudyFlowTrack.flashSentenceTestChoice) > 0) {
        return '/flash-sentence-test/choice';
      }
      return '/flash-sentence-test-select';
    case LearningMode.sentenceLearning:
    case LearningMode.flashWordLearning:
    case LearningMode.flashSentenceLearning:
      return routeForLearningMode(mode);
  }
}
