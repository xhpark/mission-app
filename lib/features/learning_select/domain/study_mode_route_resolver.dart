import '../presentation/controllers/learning_selection_controller.dart';

String routeForLearningMode(LearningMode mode) => switch (mode) {
  LearningMode.sentenceLearning => '/sentence-learning',
  LearningMode.sentenceTest => '/sentence-test/choice',
  LearningMode.flashWordLearning => '/flash-word-learning',
  LearningMode.flashWordTest => '/flash-word-test',
  LearningMode.flashSentenceLearning => '/flash-sentence-learning',
  LearningMode.flashSentenceTest => '/flash-sentence-test/choice',
};

String routeForSelectionOrFallback(LearningSelectionState selection) {
  final mode = selection.mode;
  if (mode == null) {
    return '/select';
  }

  return routeForLearningMode(mode);
}
