import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/models/study_session_result.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../providers/learning_select_providers.dart';
import 'learning_selection_controller.dart';

class StartStudySessionController extends AsyncNotifier<StudySessionResult?> {
  @override
  Future<StudySessionResult?> build() async {
    return null;
  }

  Future<StudySessionResult> start() async {
    final selection = ref.read(learningSelectionProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      throw StateError('User must be signed in before starting a session.');
    }
    if (!selection.canProceed) {
      throw StateError('Category, level, and mode must be selected.');
    }

    state = const AsyncLoading();
    final contentSetId = _resolveContentSetId(selection);
    final result = await AsyncValue.guard(() async {
      return ref.read(studySessionRepositoryProvider).startStudySession(
            userId: user.uid,
            contentSetId: contentSetId,
            category: _categoryValue(selection.category!),
            level: _levelValue(selection.level!),
            mode: _modeValue(selection.mode!),
          );
    });

    state = result;
    ref.read(currentStudySessionProvider.notifier).setSession(
          CurrentStudySession.fromSelection(
            result: result.requireValue,
            selection: selection,
            contentSetId: contentSetId,
          ),
        );
    return result.requireValue;
  }

  String _resolveContentSetId(LearningSelectionState selection) {
    final category = _categoryValue(selection.category!);
    final level = _levelValue(selection.level!);
    return '$category-$level-default';
  }

  String _categoryValue(LearningCategory value) => switch (value) {
        LearningCategory.daily => 'daily',
        LearningCategory.mission => 'mission',
      };

  String _levelValue(LearningLevel value) => switch (value) {
        LearningLevel.beginner => 'beginner',
        LearningLevel.intermediate => 'intermediate',
        LearningLevel.advanced => 'advanced',
      };

  String _modeValue(LearningMode value) => switch (value) {
        LearningMode.sentenceLearning => 'sentence_learning',
        LearningMode.sentenceTest => 'sentence_test',
        LearningMode.flashWordLearning => 'flash_word_learning',
      };
}

final startStudySessionControllerProvider = AsyncNotifierProvider<
    StartStudySessionController, StudySessionResult?>(
  StartStudySessionController.new,
);
