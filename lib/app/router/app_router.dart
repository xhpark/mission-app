import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/bootstrap/presentation/controllers/bootstrap_controller.dart';
import '../../features/bootstrap/presentation/screens/approval_pending_screen.dart';
import '../../features/bootstrap/presentation/screens/blocked_screen.dart';
import '../../features/bootstrap/presentation/screens/bootstrap_screen.dart';
import '../../features/bootstrap/presentation/screens/learning_blocked_screen.dart';
import '../../features/flash_sentence_learning/presentation/screens/flash_sentence_learning_screen.dart';
import '../../features/flash_sentence_test/presentation/screens/flash_sentence_test_choice_screen.dart';
import '../../features/flash_sentence_test/presentation/screens/flash_sentence_test_speaking_screen.dart';
import '../../features/flash_word_learning/presentation/screens/flash_word_learning_screen.dart';
import '../../features/flash_word_test/presentation/screens/flash_word_test_screen.dart';
import '../../features/learning_select/presentation/screens/learning_guide_screen.dart';
import '../../features/learning_select/presentation/screens/learning_select_screen.dart';
import '../../features/report_gate/presentation/screens/report_gate_screen.dart';
import '../../features/reporting/presentation/controllers/report_requirement_controller.dart';
import '../../features/reporting/presentation/screens/report_preview_screen.dart';
import '../../features/reporting/presentation/screens/report_screen.dart';
import '../../features/resume/presentation/screens/resume_screen.dart';
import '../../features/sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../features/sentence_learning/presentation/screens/sentence_learning_screen.dart';
import '../../features/sentence_test/presentation/screens/sentence_test_choice_screen.dart';
import '../../features/sentence_test/presentation/screens/sentence_test_speaking_screen.dart';
import '../../features/session_summary/presentation/screens/session_summary_screen.dart';
import 'app_route_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/bootstrap',
    refreshListenable: listenable,
    routes: [
      GoRoute(path: '/bootstrap', builder: (_, _) => const BootstrapScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/approval-pending',
        builder: (_, _) => const ApprovalPendingScreen(),
      ),
      GoRoute(
        path: '/learning-blocked',
        builder: (_, _) => const LearningBlockedScreen(),
      ),
      GoRoute(path: '/blocked', builder: (_, _) => const BlockedScreen()),
      GoRoute(path: '/select', builder: (_, _) => const LearningSelectScreen()),
      GoRoute(path: '/guide', builder: (_, _) => const LearningGuideScreen()),
      GoRoute(
        path: '/sentence-learning',
        builder: (_, _) => const SentenceLearningScreen(),
      ),
      GoRoute(
        path: '/sentence-test/choice',
        builder: (_, _) => const SentenceTestChoiceScreen(),
      ),
      GoRoute(
        path: '/sentence-test/speaking',
        builder: (_, _) => const SentenceTestSpeakingScreen(),
      ),
      GoRoute(
        path: '/flash-word-learning',
        builder: (_, _) => const FlashWordLearningScreen(),
      ),
      GoRoute(
        path: '/flash-word-test',
        builder: (_, _) => const FlashWordTestScreen(),
      ),
      GoRoute(
        path: '/flash-sentence-learning',
        builder: (_, _) => const FlashSentenceLearningScreen(),
      ),
      GoRoute(
        path: '/flash-sentence-test/choice',
        builder: (_, _) => const FlashSentenceTestChoiceScreen(),
      ),
      GoRoute(
        path: '/flash-sentence-test/speaking',
        builder: (_, _) => const FlashSentenceTestSpeakingScreen(),
      ),
      GoRoute(
        path: '/session-summary',
        builder: (_, _) => const SessionSummaryScreen(),
      ),
      GoRoute(path: '/report', builder: (_, _) => const ReportScreen()),
      GoRoute(
        path: '/report-preview',
        builder: (_, _) => const ReportPreviewScreen(),
      ),
      GoRoute(path: '/resume', builder: (_, _) => const ResumeScreen()),
      GoRoute(
        path: '/report-gate',
        builder: (_, _) => const ReportGateScreen(),
      ),
    ],
    redirect: (context, state) {
      final bootstrapState = ref.read(bootstrapControllerProvider);
      final authState = ref.read(authStateChangesProvider);
      final developmentSession = ref.read(developmentSessionProvider);
      final currentSession = ref.read(currentStudySessionProvider);
      final sessionHydrated = ref.read(currentStudySessionHydratedProvider);
      final reportRequired = ref.read(reportRequirementProvider);
      final bootstrapSession = bootstrapState.asData?.value;
      final reportGateBlocked =
          (bootstrapSession?.reportGateStage ?? 'none') != 'none';

      final isBootstrapping = bootstrapState.isLoading;
      final signedInUser = authState.asData?.value;
      final signedIn = signedInUser != null || developmentSession;
      final isDevelopmentAnonymous =
          (signedInUser?.isAnonymous ?? false) || developmentSession;
      return AppRouteGuard.redirect(
        AppRouteGuardInput(
          location: state.matchedLocation,
          isBootstrapping: isBootstrapping,
          signedIn: signedIn,
          isDevelopmentAnonymous: isDevelopmentAnonymous,
          sessionHydrated: sessionHydrated,
          hasCurrentSession: currentSession != null,
          reportRequired: reportRequired || reportGateBlocked,
          bootstrapSession: bootstrapSession,
        ),
      );
    },
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(bootstrapControllerProvider, (_, _) => notifyListeners());
    _ref.listen(authStateChangesProvider, (_, _) => notifyListeners());
    _ref.listen(developmentSessionProvider, (_, _) => notifyListeners());
    _ref.listen(currentStudySessionProvider, (_, _) => notifyListeners());
    _ref.listen(
      currentStudySessionHydratedProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen(reportRequirementProvider, (_, _) => notifyListeners());
  }
}
