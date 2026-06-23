import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/learning_select/domain/study_mode_route_resolver.dart';
import 'package:mission_app/features/learning_select/presentation/controllers/learning_selection_controller.dart';
import 'package:mission_app/features/session_runtime/presentation/controllers/study_flow_controller.dart';

void main() {
  // Resuming a two-stage test (choice -> speaking) used to always send the
  // learner back to the mode's default entry screen, ignoring how far they
  // had actually progressed. A learner who had already finished both stages
  // and was just waiting to submit a report would get stuck cycling through
  // the test screens with no way to reach the report or home screen.
  group('flashSentenceTest', () {
    const emptyFlow = StudyFlowState.empty;

    test('not started yet resumes at the test-select hub', () {
      expect(
        resumeRouteForSession(LearningMode.flashSentenceTest, emptyFlow),
        '/flash-sentence-test-select',
      );
    });

    test('mid-choice-test resumes directly at the choice screen', () {
      final flow = emptyFlow.copyWith(
        trackIndices: <StudyFlowTrack, int>{
          StudyFlowTrack.flashSentenceTestChoice: 2,
        },
      );
      expect(
        resumeRouteForSession(LearningMode.flashSentenceTest, flow),
        '/flash-sentence-test/choice',
      );
    });

    test('choice completed but speaking not resumes at speaking', () {
      final flow = emptyFlow.copyWith(
        completedTracks: <StudyFlowTrack>{
          StudyFlowTrack.flashSentenceTestChoice,
        },
      );
      expect(
        resumeRouteForSession(LearningMode.flashSentenceTest, flow),
        '/flash-sentence-test/speaking',
      );
    });

    test('both stages completed resumes at the session summary', () {
      final flow = emptyFlow.copyWith(
        completedTracks: <StudyFlowTrack>{
          StudyFlowTrack.flashSentenceTestChoice,
          StudyFlowTrack.flashSentenceTestSpeaking,
        },
      );
      expect(
        resumeRouteForSession(LearningMode.flashSentenceTest, flow),
        '/session-summary',
      );
    });
  });

  group('sentenceTest', () {
    const emptyFlow = StudyFlowState.empty;

    test('choice completed but speaking not resumes at speaking', () {
      final flow = emptyFlow.copyWith(
        completedTracks: <StudyFlowTrack>{StudyFlowTrack.sentenceTestChoice},
      );
      expect(
        resumeRouteForSession(LearningMode.sentenceTest, flow),
        '/sentence-test/speaking',
      );
    });

    test('both stages completed resumes at the session summary', () {
      final flow = emptyFlow.copyWith(
        completedTracks: <StudyFlowTrack>{
          StudyFlowTrack.sentenceTestChoice,
          StudyFlowTrack.sentenceTestSpeaking,
        },
      );
      expect(
        resumeRouteForSession(LearningMode.sentenceTest, flow),
        '/session-summary',
      );
    });
  });

  group('flashWordTest', () {
    const emptyFlow = StudyFlowState.empty;

    test('choice completed but speaking not resumes at speaking', () {
      final flow = emptyFlow.copyWith(
        completedTracks: <StudyFlowTrack>{StudyFlowTrack.flashWordTest},
      );
      expect(
        resumeRouteForSession(LearningMode.flashWordTest, flow),
        '/flash-word-test/speaking',
      );
    });

    test('both stages completed resumes at the session summary', () {
      final flow = emptyFlow.copyWith(
        completedTracks: <StudyFlowTrack>{
          StudyFlowTrack.flashWordTest,
          StudyFlowTrack.flashWordTestSpeaking,
        },
      );
      expect(
        resumeRouteForSession(LearningMode.flashWordTest, flow),
        '/session-summary',
      );
    });
  });
}
