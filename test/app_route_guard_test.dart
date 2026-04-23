import 'package:flutter_test/flutter_test.dart';
import 'package:mission_app/app/router/app_route_guard.dart';
import 'package:mission_app/features/bootstrap/data/models/bootstrap_session.dart';

void main() {
  test('redirects to login when not signed in', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/select',
        isBootstrapping: false,
        signedIn: false,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: null,
      ),
    );

    expect(target, '/login');
  });

  test('keeps bootstrapping screen while bootstrapping', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/bootstrap',
        isBootstrapping: true,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: false,
        bootstrapSession: null,
      ),
    );

    expect(target, isNull);
  });

  test('routes to report gate when report is required', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/select',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: true,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: true,
        bootstrapSession: null,
      ),
    );

    expect(target, '/report-gate');
  });

  test('allows report preview when report is required', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/report-preview',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: true,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: true,
        bootstrapSession: null,
      ),
    );

    expect(target, isNull);
  });

  test('does not force report gate when report is required but no session', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/select',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: true,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: true,
        bootstrapSession: null,
      ),
    );

    expect(target, isNull);
  });

  test('allows guide route without active session', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/guide',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: BootstrapSession.fallback(),
      ),
    );

    expect(target, isNull);
  });

  test('allows resume route without active session', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/resume',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: BootstrapSession.fallback(),
      ),
    );

    expect(target, isNull);
  });

  test('redirects development user to select for session-required route', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/sentence-test/choice',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: true,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: null,
      ),
    );

    expect(target, '/select');
  });

  test('redirects report route to select when there is no active session', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/report',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: null,
      ),
    );

    expect(target, '/select');
  });

  test('keeps guide route accessible for development user without session', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/guide',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: true,
        sessionHydrated: true,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: null,
      ),
    );

    expect(target, isNull);
  });
}
