class BootstrapSession {
  const BootstrapSession({
    required this.status,
    required this.approved,
    required this.learningBlocked,
    required this.reportGateStage,
    required this.hasResume,
    required this.activeContentSetId,
    required this.adminContact,
    required this.isAdmin,
  });

  final String status;
  final bool approved;
  final bool learningBlocked;
  final String reportGateStage;
  final bool hasResume;
  final String activeContentSetId;
  final String adminContact;
  final bool isAdmin;

  bool get isPendingApproval => status == 'pending_approval';

  bool get isBlocked => status == 'blocked';

  factory BootstrapSession.fromJson(Map<String, dynamic> json) {
    return BootstrapSession(
      status: json['status'] as String? ?? 'pending_approval',
      approved: json['approved'] as bool? ?? false,
      learningBlocked: json['learningBlocked'] as bool? ?? false,
      reportGateStage: json['reportGateStage'] as String? ?? 'none',
      hasResume: json['hasResume'] as bool? ?? false,
      activeContentSetId: json['activeContentSetId'] as String? ?? '',
      adminContact: json['adminContact'] as String? ?? '010-0000-0000',
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }

  factory BootstrapSession.fallback() {
    return const BootstrapSession(
      status: 'approved',
      approved: true,
      learningBlocked: false,
      reportGateStage: 'none',
      hasResume: false,
      activeContentSetId: 'daily-beginner-default',
      adminContact: '010-0000-0000',
      isAdmin: false,
    );
  }
}
