import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../data/models/bootstrap_session.dart';
import '../providers/bootstrap_providers.dart';

enum BootstrapStatus {
  loading,
  ready,
}

class BootstrapController extends AsyncNotifier<BootstrapSession> {
  @override
  Future<BootstrapSession> build() async {
    final developmentSession = ref.read(developmentSessionProvider);
    if (developmentSession) {
      return BootstrapSession.fallback();
    }

    final auth = ref.read(firebaseAuthProvider);
    final currentUser = auth.currentUser;
    final authState = currentUser ??
        await ref
            .watch(authStateChangesProvider.future)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);

    if (authState == null) {
      return BootstrapSession.fallback();
    }

    final deviceId =
        await ref.read(deviceIdServiceProvider).getOrCreateDeviceId();
    return ref.read(bootstrapRepositoryProvider).bootstrapUserSession(
          userId: authState.uid,
          deviceId: deviceId,
        );
  }
}

final bootstrapControllerProvider =
    AsyncNotifierProvider<BootstrapController, BootstrapSession>(
      BootstrapController.new,
    );
