import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../../bootstrap/presentation/controllers/bootstrap_controller.dart';
import '../../../reporting/presentation/controllers/report_requirement_controller.dart';
import '../../../sentence_learning/presentation/controllers/current_study_session_controller.dart';
import '../../../session_runtime/presentation/controllers/study_flow_controller.dart';

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
      _resetStartupState();
    });
  }

  Future<void> signInForDevelopment() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (kReleaseMode) {
        throw StateError('정식 배포 환경에서는 개발용 로그인을 사용할 수 없습니다.');
      }
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
      _resetStartupState();
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.read(developmentSessionProvider.notifier).value = false;
      await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      _resetStartupState();
    });
  }

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
    required String learnerName,
    required String learnerPhone,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.read(developmentSessionProvider.notifier).value = false;
      final credential = await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        throw StateError('계정 생성 후 사용자 정보를 확인하지 못했습니다.');
      }

      await user.updateDisplayName(learnerName);
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('updateLearnerProfile')
          .call(<String, dynamic>{
            'userId': user.uid,
            'learnerName': learnerName,
            'learnerPhone': learnerPhone,
          });
      _resetStartupState();
    });
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthProvider).sendPasswordResetEmail(email: email);
    });
  }

  Future<String?> findLearnerEmail({
    required String learnerName,
    required String learnerPhone,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('findLearnerEmail')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'learnerName': learnerName,
            'learnerPhone': learnerPhone,
          });
      final data = result.data;
      state = const AsyncData(null);
      if (data['found'] == true) {
        return data['maskedEmail'] as String?;
      }
      return null;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthProvider).signOut();
      ref.read(developmentSessionProvider.notifier).value = false;
      ref.read(currentStudySessionProvider.notifier).clear();
      ref.read(studyFlowControllerProvider.notifier).clear();
      ref.read(reportRequirementProvider.notifier).markSubmitted();
      _resetStartupState();
    });
  }

  void _resetStartupState() {
    ref.invalidate(bootstrapControllerProvider);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
