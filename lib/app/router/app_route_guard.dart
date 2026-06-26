import '../../features/bootstrap/data/models/bootstrap_session.dart';

class AppRouteGuardInput {
  const AppRouteGuardInput({
    required this.location,
    required this.isBootstrapping,
    required this.signedIn,
    required this.isDevelopmentAnonymous,
    required this.sessionHydrated,
    required this.hasCurrentSession,
    required this.reportRequired,
    required this.bootstrapSession,
  });

  final String location;
  final bool isBootstrapping;
  final bool signedIn;
  final bool isDevelopmentAnonymous;
  final bool sessionHydrated;
  final bool hasCurrentSession;
  final bool reportRequired;
  final BootstrapSession? bootstrapSession;
}

class AppRouteGuard {
  static const protectedStudyRoutes = <String>{
    '/guide',
    '/sentence-learning',
    '/sentence-test/choice',
    '/sentence-test/speaking',
    '/flash-word-learning',
    '/flash-word-test-select',
    '/flash-word-test',
    '/flash-word-test/speaking',
    '/flash-sentence-learning',
    '/flash-sentence-test-select',
    '/flash-sentence-test/choice',
    '/flash-sentence-test/speaking',
    '/session-summary',
    '/report',
    '/report-preview',
    '/resume',
    '/admin-dashboard',
    '/admin-today-link-clicks',
  };

  static const routesRequiringActiveSession = <String>{
    '/sentence-learning',
    '/sentence-test/choice',
    '/sentence-test/speaking',
    '/flash-word-learning',
    '/flash-word-test-select',
    '/flash-word-test',
    '/flash-word-test/speaking',
    '/flash-sentence-learning',
    '/flash-sentence-test-select',
    '/flash-sentence-test/choice',
    '/flash-sentence-test/speaking',
    '/session-summary',
    '/report-preview',
  };

  static const routesBlockedByReportGate = <String>{
    '/sentence-learning',
    '/sentence-test/choice',
    '/sentence-test/speaking',
    '/flash-word-learning',
    '/flash-word-test-select',
    '/flash-word-test',
    '/flash-word-test/speaking',
    '/flash-sentence-learning',
    '/flash-sentence-test-select',
    '/flash-sentence-test/choice',
    '/flash-sentence-test/speaking',
  };

  static String? redirect(AppRouteGuardInput input) {
    final session = input.bootstrapSession;
    final location = input.location;

    if (!input.signedIn) {
      return location == '/login' ? null : '/login';
    }

    if (input.isBootstrapping && input.bootstrapSession == null) {
      return location == '/bootstrap' ? null : '/bootstrap';
    }

    if (!input.isDevelopmentAnonymous &&
        protectedStudyRoutes.contains(location) &&
        !input.sessionHydrated) {
      return null;
    }

    if (input.isDevelopmentAnonymous) {
      if (location == '/bootstrap' || location == '/login') {
        return '/select';
      }

      return null;
    }

    if (routesRequiringActiveSession.contains(location) &&
        !input.hasCurrentSession) {
      return '/select';
    }

    if (session == null) {
      return location == '/bootstrap' ? null : '/bootstrap';
    }

    if (session.isBlocked) {
      return location == '/blocked' ? null : '/blocked';
    }

    if (session.isPendingApproval) {
      return location == '/approval-pending' ? null : '/approval-pending';
    }

    if (session.learningBlocked) {
      return location == '/learning-blocked' ? null : '/learning-blocked';
    }

    if (input.reportRequired &&
        input.hasCurrentSession &&
        routesBlockedByReportGate.contains(location)) {
      return '/report-preview';
    }

    if (location == '/bootstrap' ||
        location == '/login' ||
        location == '/approval-pending' ||
        location == '/learning-blocked' ||
        location == '/blocked') {
      return '/select';
    }

    return null;
  }
}
