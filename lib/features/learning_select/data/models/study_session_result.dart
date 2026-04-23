class StudySessionResult {
  const StudySessionResult({
    required this.sessionId,
    required this.startedAt,
    required this.totalItems,
  });

  final String sessionId;
  final String startedAt;
  final int totalItems;

  factory StudySessionResult.fromJson(Map<String, dynamic> json) {
    return StudySessionResult(
      sessionId: json['sessionId'] as String? ?? '',
      startedAt: json['startedAt'] as String? ?? '',
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
    );
  }

  factory StudySessionResult.fallback({int totalItems = 0}) {
    final now = DateTime.now().toIso8601String();
    return StudySessionResult(
      sessionId: 'local-$now',
      startedAt: now,
      totalItems: totalItems,
    );
  }
}
