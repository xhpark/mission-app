import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/session_runtime/presentation/controllers/study_flow_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('study flow advances and accumulates score', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(studyFlowControllerProvider.notifier);
    controller.startSession(sessionId: 's1', totalItems: 5);

    final hasNext1 = controller.advanceTrack(
      track: StudyFlowTrack.sentenceTestChoice,
      totalCount: 3,
      isCorrectAttempt: true,
      countAsAttempt: true,
    );
    final hasNext2 = controller.advanceTrack(
      track: StudyFlowTrack.sentenceTestChoice,
      totalCount: 3,
      isCorrectAttempt: false,
      countAsAttempt: true,
    );

    final state = container.read(studyFlowControllerProvider);
    expect(hasNext1, isTrue);
    expect(hasNext2, isTrue);
    expect(state.correctAnswers, 1);
    expect(state.attemptedAnswers, 2);
    expect(state.completedItems, 2);
    expect(state.indexOf(StudyFlowTrack.sentenceTestChoice), 2);
  });

  test('study flow restores the latest persisted session', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();

    final controller = container.read(studyFlowControllerProvider.notifier);
    controller.startSession(sessionId: 's1', totalItems: 5);
    controller.advanceTrack(
      track: StudyFlowTrack.flashSentenceLearning,
      totalCount: 5,
    );
    await controller.persistNow();
    container.dispose();

    final restoredContainer = ProviderContainer();
    addTearDown(restoredContainer.dispose);

    restoredContainer.read(studyFlowControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final restored = restoredContainer.read(studyFlowControllerProvider);
    expect(restored.sessionId, 's1');
    expect(restored.totalItems, 5);
    expect(restored.completedItems, 1);
    expect(restored.indexOf(StudyFlowTrack.flashSentenceLearning), 1);
  });

  test('a track is marked completed once its last item is advanced past', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(studyFlowControllerProvider.notifier);
    controller.startSession(sessionId: 's1', totalItems: 2);

    final hasNextOnFirstItem = controller.advanceTrack(
      track: StudyFlowTrack.flashSentenceTestChoice,
      totalCount: 2,
    );
    expect(hasNextOnFirstItem, isTrue);
    expect(
      container
          .read(studyFlowControllerProvider)
          .isTrackCompleted(StudyFlowTrack.flashSentenceTestChoice),
      isFalse,
    );

    final hasNextOnLastItem = controller.advanceTrack(
      track: StudyFlowTrack.flashSentenceTestChoice,
      totalCount: 2,
    );
    expect(hasNextOnLastItem, isFalse);
    expect(
      container
          .read(studyFlowControllerProvider)
          .isTrackCompleted(StudyFlowTrack.flashSentenceTestChoice),
      isTrue,
    );
  });

  test('resetting a track clears its completed flag', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(studyFlowControllerProvider.notifier);
    controller.startSession(sessionId: 's1', totalItems: 1);
    controller.advanceTrack(
      track: StudyFlowTrack.flashSentenceTestChoice,
      totalCount: 1,
    );
    expect(
      container
          .read(studyFlowControllerProvider)
          .isTrackCompleted(StudyFlowTrack.flashSentenceTestChoice),
      isTrue,
    );

    controller.resetTrack(track: StudyFlowTrack.flashSentenceTestChoice);
    expect(
      container
          .read(studyFlowControllerProvider)
          .isTrackCompleted(StudyFlowTrack.flashSentenceTestChoice),
      isFalse,
    );
  });

  test('completed tracks survive persistence and rehydration', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();

    final controller = container.read(studyFlowControllerProvider.notifier);
    controller.startSession(sessionId: 's1', totalItems: 1);
    controller.advanceTrack(
      track: StudyFlowTrack.flashSentenceTestChoice,
      totalCount: 1,
    );
    await controller.persistNow();
    container.dispose();

    final restoredContainer = ProviderContainer();
    addTearDown(restoredContainer.dispose);
    restoredContainer.read(studyFlowControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final restored = restoredContainer.read(studyFlowControllerProvider);
    expect(
      restored.isTrackCompleted(StudyFlowTrack.flashSentenceTestChoice),
      isTrue,
    );
  });
}
