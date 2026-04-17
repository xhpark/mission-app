import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../learning_select/data/models/study_session_result.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';

class CurrentStudySession {
  const CurrentStudySession({
    required this.sessionId,
    required this.startedAt,
    required this.contentSetId,
    required this.category,
    required this.level,
    required this.mode,
  });

  final String sessionId;
  final String startedAt;
  final String contentSetId;
  final LearningCategory category;
  final LearningLevel level;
  final LearningMode mode;

  factory CurrentStudySession.fromSelection({
    required StudySessionResult result,
    required LearningSelectionState selection,
    required String contentSetId,
  }) {
    return CurrentStudySession(
      sessionId: result.sessionId,
      startedAt: result.startedAt,
      contentSetId: contentSetId,
      category: selection.category!,
      level: selection.level!,
      mode: selection.mode!,
    );
  }

  String get categoryLabel => switch (category) {
        LearningCategory.daily => 'Daily',
        LearningCategory.mission => 'Mission',
      };

  String get levelLabel => switch (level) {
        LearningLevel.beginner => 'Beginner',
        LearningLevel.intermediate => 'Intermediate',
        LearningLevel.advanced => 'Advanced',
      };

  String get modeLabel => switch (mode) {
        LearningMode.sentenceLearning => 'Sentence Learning',
        LearningMode.sentenceTest => 'Sentence Test',
        LearningMode.flashWordLearning => 'Flash Word Learning',
      };
}

class CurrentStudySessionController extends Notifier<CurrentStudySession?> {
  @override
  CurrentStudySession? build() {
    return null;
  }

  void setSession(CurrentStudySession session) {
    state = session;
  }

  void clear() {
    state = null;
  }
}

final currentStudySessionProvider =
    NotifierProvider<CurrentStudySessionController, CurrentStudySession?>(
      CurrentStudySessionController.new,
    );
