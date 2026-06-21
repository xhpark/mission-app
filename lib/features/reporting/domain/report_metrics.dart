import '../../session_runtime/presentation/controllers/study_flow_controller.dart';

class ReportMetrics {
  const ReportMetrics({
    required this.hasAssessment,
    required this.hasSpeaking,
    required this.answerRate,
    required this.accuracy,
    required this.missedAnswers,
    required this.averageSimilarity,
  });

  final bool hasAssessment;
  final bool hasSpeaking;
  final int? answerRate;
  final int? accuracy;
  final int missedAnswers;
  final int? averageSimilarity;
}

ReportMetrics buildReportMetrics(StudyFlowState flow) {
  final hasAssessment = flow.attemptedAnswers > 0;
  final averageSimilarity = flow.averageSimilarityScore;
  final missedAnswers = hasAssessment
      ? (flow.attemptedAnswers - flow.correctAnswers)
            .clamp(0, flow.attemptedAnswers)
            .toInt()
      : 0;

  return ReportMetrics(
    hasAssessment: hasAssessment,
    hasSpeaking: averageSimilarity != null,
    answerRate: hasAssessment
        ? _boundedPercentValue(flow.attemptedAnswers, flow.totalItems)
        : null,
    accuracy: hasAssessment
        ? _percentValue(flow.correctAnswers, flow.attemptedAnswers)
        : null,
    missedAnswers: missedAnswers,
    averageSimilarity: averageSimilarity,
  );
}

int? _percentValue(int numerator, int denominator) {
  if (denominator <= 0) {
    return null;
  }
  return ((numerator / denominator) * 100).round();
}

int? _boundedPercentValue(int numerator, int denominator) {
  final value = _percentValue(numerator, denominator);
  return value?.clamp(0, 100).toInt();
}
