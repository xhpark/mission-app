import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/features/reporting/domain/report_metrics.dart';
import 'package:mission_app/features/session_runtime/presentation/controllers/study_flow_controller.dart';

void main() {
  test('learning-only sessions do not report assessment metrics', () {
    const flow = StudyFlowState(
      sessionId: 'learning-session',
      totalItems: 15,
      completedItems: 15,
      correctAnswers: 0,
      attemptedAnswers: 0,
      trackIndices: <StudyFlowTrack, int>{},
      speakingSimilarityByItemId: <String, int>{},
      completedTracks: <StudyFlowTrack>{},
    );

    final metrics = buildReportMetrics(flow);

    expect(metrics.hasAssessment, isFalse);
    expect(metrics.hasSpeaking, isFalse);
    expect(metrics.answerRate, isNull);
    expect(metrics.accuracy, isNull);
    expect(metrics.missedAnswers, 0);
    expect(metrics.averageSimilarity, isNull);
  });

  test(
    'actual attempt and speaking metrics are reported regardless of mode',
    () {
      const flow = StudyFlowState(
        sessionId: 'mixed-session',
        totalItems: 31,
        completedItems: 31,
        correctAnswers: 56,
        attemptedAnswers: 62,
        trackIndices: <StudyFlowTrack, int>{},
        speakingSimilarityByItemId: <String, int>{
          'sentence-1': 32,
          'sentence-2': 44,
        },
        completedTracks: <StudyFlowTrack>{},
      );

      final metrics = buildReportMetrics(flow);

      expect(metrics.hasAssessment, isTrue);
      expect(metrics.hasSpeaking, isTrue);
      expect(metrics.answerRate, 100);
      expect(metrics.accuracy, 90);
      expect(metrics.missedAnswers, 6);
      expect(metrics.averageSimilarity, 38);
    },
  );
}
