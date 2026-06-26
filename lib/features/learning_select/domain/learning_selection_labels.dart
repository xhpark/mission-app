import 'package:mission_app/l10n/app_localizations.dart';

import '../presentation/controllers/learning_selection_controller.dart';

/// Shared label text for [LearningCategory]/[LearningLevel]/[LearningMode],
/// reused wherever a screen shows the learner's current selection (e.g. the
/// small reference line "일상회화, 초급, 문장학습" at the top of a learning
/// or test screen) so the wording stays identical across screens.
String categoryLabel(LearningCategory category, AppLocalizations l10n) =>
    switch (category) {
      LearningCategory.daily => l10n.learningSelectCategoryDaily,
      LearningCategory.mission => l10n.learningSelectCategoryMission,
    };

String levelLabel(LearningLevel level, AppLocalizations l10n) =>
    switch (level) {
      LearningLevel.beginner => l10n.learningSelectLevelBeginner,
      LearningLevel.intermediate => l10n.learningSelectLevelIntermediate,
      LearningLevel.advanced => l10n.learningSelectLevelAdvanced,
    };

String modeLabel(LearningMode mode, AppLocalizations l10n) => switch (mode) {
  LearningMode.sentenceLearning => l10n.learningSelectModeSentenceLearning,
  LearningMode.sentenceTest => l10n.learningSelectModeSentenceTest,
  LearningMode.flashWordLearning => l10n.learningSelectModeFlashWordLearning,
  LearningMode.flashWordTest => l10n.learningSelectModeFlashWordTest,
  LearningMode.flashSentenceLearning =>
    l10n.learningSelectModeFlashSentenceLearning,
  LearningMode.flashSentenceTest => l10n.learningSelectModeFlashSentenceTest,
};
