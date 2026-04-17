import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/bootstrap/presentation/controllers/bootstrap_controller.dart';
import '../../features/bootstrap/presentation/screens/bootstrap_screen.dart';
import '../../features/learning_select/presentation/screens/learning_select_screen.dart';
import '../../features/sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../features/sentence_learning/presentation/screens/sentence_learning_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final bootstrapState = ref.watch(bootstrapControllerProvider);
  final authState = ref.watch(authStateChangesProvider);
  final currentSession = ref.watch(currentStudySessionProvider);

  return GoRouter(
    initialLocation: '/bootstrap',
    routes: [
      GoRoute(
        path: '/bootstrap',
        builder: (_, _) => const BootstrapScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/select',
        builder: (_, _) => const LearningSelectScreen(),
      ),
      GoRoute(
        path: '/sentence-learning',
        builder: (_, _) => const SentenceLearningScreen(),
      ),
    ],
    redirect: (_, state) {
      final isBootstrapping = bootstrapState.isLoading;
      final signedIn = authState.asData?.value != null;
      final learningBlocked =
          bootstrapState.asData?.value.learningBlocked ?? false;
      final location = state.matchedLocation;

      if (isBootstrapping) {
        return location == '/bootstrap' ? null : '/bootstrap';
      }

      if (!signedIn) {
        return location == '/login' ? null : '/login';
      }

      if (location == '/sentence-learning' && currentSession == null) {
        return '/select';
      }

      if (learningBlocked) {
        return location == '/select' ? null : '/select';
      }

      if (location == '/bootstrap' || location == '/login') {
        return '/select';
      }

      return null;
    },
  );
});
