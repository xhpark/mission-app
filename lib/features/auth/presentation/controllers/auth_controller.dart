import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../reporting/presentation/controllers/report_requirement_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> enterDevelopmentMode() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (kReleaseMode) {
        throw StateError('정식 배포 환경에서는 개발용 로그인을 사용할 수 없습니다.');
      }
      ref.read(developmentSessionProvider.notifier).value = true;
    });
  }

  Future<void> signInForDevelopment() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final developmentSession = ref.read(developmentSessionProvider.notifier);

      // Always unlock the development flow immediately, even if Firebase auth
      // is slow or unavailable in local web environments.
      developmentSession.value = true;

      try {
        await ref
            .read(firebaseAuthProvider)
            .signInAnonymously()
            .timeout(const Duration(seconds: 3));
        developmentSession.value = false;
      } catch (_) {
        developmentSession.value = true;
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthProvider).signOut();
      ref.read(developmentSessionProvider.notifier).value = false;
      ref.read(currentStudySessionProvider.notifier).clear();
      ref.read(studyFlowControllerProvider.notifier).clear();
      ref.read(reportRequirementProvider.notifier).markSubmitted();
    });
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
