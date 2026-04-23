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
  static const reportRoutes = <String>{
    '/report-gate',
    '/report-preview',
    '/report',
    '/session-summary',
  };

  static const protectedStudyRoutes = <String>{
    '/guide',
    '/sentence-learning',
    '/sentence-test/choice',
    '/sentence-test/speaking',
    '/flash-word-learning',
    '/flash-word-test',
    '/flash-sentence-learning',
    '/flash-sentence-test/choice',
    '/flash-sentence-test/speaking',
    '/session-summary',
    '/report',
    '/report-preview',
    '/resume',
    '/report-gate',
  };

  static const routesRequiringActiveSession = <String>{
    '/sentence-learning',
    '/sentence-test/choice',
    '/sentence-test/speaking',
    '/flash-word-learning',
    '/flash-word-test',
    '/flash-sentence-learning',
    '/flash-sentence-test/choice',
    '/flash-sentence-test/speaking',
    '/session-summary',
    '/report',
    '/report-preview',
    '/report-gate',
  };

  static String? redirect(AppRouteGuardInput input) {
    final session = input.bootstrapSession;
    final location = input.location;

    if (input.isBootstrapping) {
      return location == '/bootstrap' ? null : '/bootstrap';
    }

    if (!input.signedIn) {
      return location == '/login' ? null : '/login';
    }

    if (!input.isDevelopmentAnonymous &&
        protectedStudyRoutes.contains(location) &&
        !input.sessionHydrated) {
      return null;
    }

    if (routesRequiringActiveSession.contains(location) &&
        !input.hasCurrentSession) {
      return '/select';
    }

    if (input.isDevelopmentAnonymous) {
      if (input.reportRequired &&
          input.hasCurrentSession &&
          !reportRoutes.contains(location)) {
        return '/report-gate';
      }

      if (location == '/bootstrap' || location == '/login') {
        return '/select';
      }

      return null;
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
        !reportRoutes.contains(location)) {
      return '/report-gate';
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
