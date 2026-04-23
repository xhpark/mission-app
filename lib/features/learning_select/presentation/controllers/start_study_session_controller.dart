import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../bootstrap/presentation/controllers/bootstrap_controller.dart';
import '../../../learning_content/data/thai_learning_content.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../data/models/study_session_result.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../providers/learning_select_providers.dart';
import 'learning_selection_controller.dart';

class StartStudySessionController extends AsyncNotifier<StudySessionResult?> {
  @override
  Future<StudySessionResult?> build() async {
    return null;
  }

  void clearError() {
    if (state.hasError) {
      state = const AsyncData(null);
    }
  }

  Future<StudySessionResult> start() async {
    final selection = ref.read(learningSelectionProvider);
    final user = ref.read(authStateChangesProvider).asData?.value;
    final developmentSession = ref.read(developmentSessionProvider);
    if (user == null && !developmentSession) {
      throw StateError('User must be signed in before starting a session.');
    }
    if (!selection.canProceed) {
      throw StateError('Category, level, and mode must be selected.');
    }

    final bootstrapSession = ref.read(bootstrapControllerProvider).asData?.value;
    final contentSetId = _resolveContentSetId(
      bootstrapSession?.activeContentSetId,
      selection,
    );

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final fallbackTotalItems = _totalItems(selection);
      if (user == null || user.isAnonymous || developmentSession) {
        final now = DateTime.now().toIso8601String();
        return StudySessionResult(
          sessionId: 'dev-local-$now',
          startedAt: now,
          totalItems: fallbackTotalItems,
        );
      }

      try {
        return await ref
            .read(studySessionRepositoryProvider)
            .startStudySession(
              userId: user.uid,
              contentSetId: contentSetId,
              category: _categoryValue(selection.category!),
              level: _levelValue(selection.level!),
              mode: _modeValue(selection.mode!),
            )
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        throw StateError(
          'Could not start a session in time. Check Firebase connectivity and try again.',
        );
      }
    });

    if (result.hasError) {
      state = result;
      throw result.error!;
    }

    final studyResult = result.requireValue;
    final resolvedTotalItems = _totalItems(selection);
    ref.read(currentStudySessionProvider.notifier).setSession(
          CurrentStudySession.fromSelection(
            result: studyResult,
            selection: selection,
            contentSetId: contentSetId,
          ),
        );
    ref.read(studyFlowControllerProvider.notifier).startSession(
          sessionId: studyResult.sessionId,
          totalItems: resolvedTotalItems,
        );
    state = AsyncData(studyResult);
    return studyResult;
  }

  int _totalItems(LearningSelectionState selection) {
    final category = _categoryValue(selection.category!);
    final sentenceCount = sentencesByCategory(category).length;
    final wordCount = wordsByCategory(category).length;
    return switch (selection.mode!) {
      LearningMode.sentenceLearning => sentenceCount,
      LearningMode.sentenceTest => sentenceCount,
      LearningMode.flashWordLearning => wordCount,
      LearningMode.flashWordTest => wordCount,
      LearningMode.flashSentenceLearning => sentenceCount,
      LearningMode.flashSentenceTest => sentenceCount,
    };
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
        LearningMode.flashWordTest => 'flash_word_test',
        LearningMode.flashSentenceLearning => 'flash_sentence_learning',
        LearningMode.flashSentenceTest => 'flash_sentence_test',
      };

  String _resolveContentSetId(
    String? activeContentSetId,
    LearningSelectionState selection,
  ) {
    final normalized = activeContentSetId?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final category = _categoryValue(selection.category!);
    final level = _levelValue(selection.level!);
    return '$category-$level-default';
  }
}

final startStudySessionControllerProvider = AsyncNotifierProvider<
    StartStudySessionController, StudySessionResult?>(
  StartStudySessionController.new,
);
