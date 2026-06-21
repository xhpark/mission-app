import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/firebase/firebase_services.dart';
import '../../data/models/bootstrap_session.dart';
import '../providers/bootstrap_providers.dart';

enum BootstrapStatus { loading, ready }

class BootstrapController extends AsyncNotifier<BootstrapSession> {
  static const _authRestoreTimeout = Duration(seconds: 3);
  static const _idTokenTimeout = Duration(seconds: 5);
  static const _bootstrapTimeout = Duration(seconds: 12);

  @override
  Future<BootstrapSession> build() async {
    final developmentSession = ref.watch(developmentSessionProvider);
    if (developmentSession) {
      return BootstrapSession.fallback();
    }

    final auth = ref.read(firebaseAuthProvider);
    final currentUser = auth.currentUser;
    final authState =
        currentUser ??
        await auth.authStateChanges().first.timeout(
          _authRestoreTimeout,
          onTimeout: () => null,
        );

    if (authState == null) {
      return BootstrapSession.fallback();
    }

    await _ensureCallableAuthReady(authState);

    final deviceId = await ref
        .read(deviceIdServiceProvider)
        .getOrCreateDeviceId();
    final repository = ref.read(bootstrapRepositoryProvider);

    try {
      return await repository
          .bootstrapUserSession(userId: authState.uid, deviceId: deviceId)
          .timeout(_bootstrapTimeout);
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (error.code == 'unauthenticated') {
        return _retryBootstrapAfterAuthRefresh(
          user: authState,
          deviceId: deviceId,
        );
      }

      if (_isRecoverableBootstrapError(error)) {
        return _useRecoverableBootstrapFallback(error, stackTrace);
      }

      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      return _useRecoverableBootstrapFallback(error, stackTrace);
    }
  }

  Future<void> _ensureCallableAuthReady(User user) async {
    final token = await user.getIdToken(false).timeout(_idTokenTimeout);
    if (token != null && token.isNotEmpty) {
      return;
    }

    throw StateError('Firebase auth token is empty.');
  }

  Future<BootstrapSession> _retryBootstrapAfterAuthRefresh({
    required User user,
    required String deviceId,
  }) async {
    try {
      await user.getIdToken(true).timeout(_idTokenTimeout);
      return await ref
          .read(bootstrapRepositoryProvider)
          .bootstrapUserSession(userId: user.uid, deviceId: deviceId)
          .timeout(_bootstrapTimeout);
    } on FirebaseFunctionsException catch (error, stackTrace) {
      if (_isRecoverableBootstrapError(error)) {
        return _useRecoverableBootstrapFallback(error, stackTrace);
      }

      if (error.code != 'unauthenticated') rethrow;
    } on FirebaseAuthException catch (error, stackTrace) {
      return _useRecoverableBootstrapFallback(error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      return _useRecoverableBootstrapFallback(error, stackTrace);
    }

    return _useRecoverableBootstrapFallback(
      FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Bootstrap callable auth was not available after refresh.',
      ),
      StackTrace.current,
    );
  }

  bool _isRecoverableBootstrapError(FirebaseFunctionsException error) {
    return switch (error.code) {
      'unavailable' ||
      'deadline-exceeded' ||
      'internal' ||
      'unauthenticated' => true,
      _ => false,
    };
  }

  BootstrapSession _useRecoverableBootstrapFallback(
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint(
        'bootstrapUserSession fallback after recoverable error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    return BootstrapSession.fallback();
  }
}

final bootstrapControllerProvider =
    AsyncNotifierProvider<BootstrapController, BootstrapSession>(
      BootstrapController.new,
    );
