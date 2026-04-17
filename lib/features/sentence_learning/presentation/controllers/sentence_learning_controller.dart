import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/models/sentence_learning_item.dart';
import '../providers/sentence_learning_providers.dart';
import 'current_study_session_controller.dart';
import '../../../learning_select/presentation/controllers/learning_selection_controller.dart';

class SentenceLearningController extends AsyncNotifier<SentenceLearningItem?> {
  @override
  Future<SentenceLearningItem?> build() async {
    final user = ref.watch(authStateChangesProvider).asData?.value;
    final session = ref.watch(currentStudySessionProvider);

    if (user == null || session == null) {
      return null;
    }

    if (session.mode != LearningMode.sentenceLearning) {
      return null;
    }

    return ref.read(sentenceLearningRepositoryProvider).loadFirstItem(
          userId: user.uid,
          sessionId: session.sessionId,
          contentSetId: session.contentSetId,
        );
  }

  Future<void> completeCurrentItem() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final session = ref.read(currentStudySessionProvider);
    final currentItem = state.asData?.value;

    if (user == null || session == null || currentItem == null) {
      throw StateError('An active sentence learning item is required.');
    }

    if (currentItem.sessionCompleted) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(sentenceLearningRepositoryProvider).completeSentenceStudy(
            userId: user.uid,
            sessionId: session.sessionId,
            itemId: currentItem.itemId,
            contentSetId: session.contentSetId,
            currentStep: currentItem.currentStep,
            totalSteps: currentItem.totalSteps,
          ),
    );
  }
}

final sentenceLearningControllerProvider = AsyncNotifierProvider<
    SentenceLearningController, SentenceLearningItem?>(
  SentenceLearningController.new,
);
