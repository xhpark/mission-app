class SentenceLearningItem {
  const SentenceLearningItem({
    required this.sessionId,
    required this.contentSetId,
    required this.itemId,
    required this.order,
    required this.thaiText,
    required this.nativeText,
    required this.pronunciation,
    required this.hint,
    required this.audioUrl,
    required this.currentStep,
    required this.totalSteps,
    required this.sessionCompleted,
  });

  final String sessionId;
  final String contentSetId;
  final String itemId;
  final int order;
  final String thaiText;
  final String nativeText;
  final String pronunciation;
  final String hint;
  final String audioUrl;
  final int currentStep;
  final int totalSteps;
  final bool sessionCompleted;

  factory SentenceLearningItem.fromJson(Map<String, dynamic> json) {
    final progress = Map<String, dynamic>.from(
      (json['progress'] as Map?) ?? const <String, dynamic>{},
    );

    return SentenceLearningItem(
      sessionId: json['sessionId'] as String? ?? '',
      contentSetId: json['contentSetId'] as String? ?? '',
      itemId: json['itemId'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 1,
      thaiText: json['thaiText'] as String? ?? '',
      nativeText: json['nativeText'] as String? ?? '',
      pronunciation: json['pronunciation'] as String? ?? '',
      hint: json['hint'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      currentStep: (progress['currentStep'] as num?)?.toInt() ?? 1,
      totalSteps: (progress['totalSteps'] as num?)?.toInt() ?? 1,
      sessionCompleted: json['sessionCompleted'] as bool? ?? false,
    );
  }

  factory SentenceLearningItem.fallback({
    required String sessionId,
    required String contentSetId,
  }) {
    return SentenceLearningItem(
      sessionId: sessionId,
      contentSetId: contentSetId,
      itemId: '$contentSetId-intro',
      order: 1,
      thaiText: 'สวัสดีครับ',
      nativeText: 'Hello.',
      pronunciation: 'sa-wat-dee krap',
      hint: 'A polite greeting used in Thai conversation.',
      audioUrl: '',
      currentStep: 1,
      totalSteps: 3,
      sessionCompleted: false,
    );
  }
}
