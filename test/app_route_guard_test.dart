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

  test('redirects to login before bootstrap when not signed in', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/bootstrap',
        isBootstrapping: true,
        signedIn: false,
        isDevelopmentAnonymous: false,
        sessionHydrated: false,
        hasCurrentSession: false,
        reportRequired: false,
        bootstrapSession: null,
      ),
    );

    expect(target, '/login');
  });

  test('does not force bootstrap redirect while loading if session exists', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/select',
        isBootstrapping: true,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: false,
        bootstrapSession: BootstrapSession.fallback(),
      ),
    );

    expect(target, isNull);
  });

  test('keeps select route when weekly report is required', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/select',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: true,
        bootstrapSession: BootstrapSession.fallback(),
      ),
    );

    expect(target, isNull);
  });

  test('allows report preview when weekly report is required', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/report-preview',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: true,
        bootstrapSession: BootstrapSession.fallback(),
      ),
    );

    expect(target, isNull);
  });

  test(
    'does not force report gate when weekly report is required but no session',
    () {
      final target = AppRouteGuard.redirect(
        AppRouteGuardInput(
          location: '/select',
          isBootstrapping: false,
          signedIn: true,
          isDevelopmentAnonymous: false,
          sessionHydrated: true,
          hasCurrentSession: false,
          reportRequired: true,
          bootstrapSession: BootstrapSession.fallback(),
        ),
      );

      expect(target, isNull);
    },
  );

  test(
    'redirects study route to report preview when weekly report is required',
    () {
      final target = AppRouteGuard.redirect(
        AppRouteGuardInput(
          location: '/sentence-learning',
          isBootstrapping: false,
          signedIn: true,
          isDevelopmentAnonymous: false,
          sessionHydrated: true,
          hasCurrentSession: true,
          reportRequired: true,
          bootstrapSession: BootstrapSession.fallback(),
        ),
      );

      expect(target, '/report-preview');
    },
  );

  test('keeps summary route accessible when weekly report is required', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/session-summary',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: true,
        bootstrapSession: BootstrapSession.fallback(),
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

  test('allows admin dashboard without active learning session', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/admin-dashboard',
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

  test('allows development user into session-required route', () {
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

    expect(target, isNull);
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

  test('allows report route when there is an active session', () {
    final target = AppRouteGuard.redirect(
      AppRouteGuardInput(
        location: '/report',
        isBootstrapping: false,
        signedIn: true,
        isDevelopmentAnonymous: false,
        sessionHydrated: true,
        hasCurrentSession: true,
        reportRequired: true,
        bootstrapSession: BootstrapSession.fallback(),
      ),
    );

    expect(target, isNull);
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

  test('redirects development user away from login', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/login',
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

  test('allows development user into flash word speaking test route', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/flash-word-test/speaking',
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

  test('allows development user into flash sentence test select route', () {
    final target = AppRouteGuard.redirect(
      const AppRouteGuardInput(
        location: '/flash-sentence-test-select',
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
