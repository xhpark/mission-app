class BootstrapSession {
  const BootstrapSession({
    required this.approved,
    required this.learningBlocked,
    required this.reportGateStage,
    required this.hasResume,
  });

  final bool approved;
  final bool learningBlocked;
  final String reportGateStage;
  final bool hasResume;

  factory BootstrapSession.fromJson(Map<String, dynamic> json) {
    return BootstrapSession(
      approved: json['approved'] as bool? ?? true,
      learningBlocked: json['learningBlocked'] as bool? ?? false,
      reportGateStage: json['reportGateStage'] as String? ?? 'none',
      hasResume: json['hasResume'] as bool? ?? false,
    );
  }

  factory BootstrapSession.fallback() {
    return const BootstrapSession(
      approved: true,
      learningBlocked: false,
      reportGateStage: 'none',
      hasResume: false,
    );
  }
}
