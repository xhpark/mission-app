class StudySessionResult {
  const StudySessionResult({
    required this.sessionId,
    required this.startedAt,
  });

  final String sessionId;
  final String startedAt;

  factory StudySessionResult.fromJson(Map<String, dynamic> json) {
    return StudySessionResult(
      sessionId: json['sessionId'] as String? ?? '',
      startedAt: json['startedAt'] as String? ?? '',
    );
  }

  factory StudySessionResult.fallback() {
    final now = DateTime.now().toIso8601String();
    return StudySessionResult(
      sessionId: 'local-$now',
      startedAt: now,
    );
  }
}
