import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/session_runtime/presentation/controllers/study_flow_controller.dart';

void main() {
  test('study flow advances and accumulates score', () {
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
}

