import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/bootstrap_session.dart';

class BootstrapRepository {
  BootstrapRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<BootstrapSession> bootstrapUserSession({
    required String userId,
    required String deviceId,
  }) async {
    final callable = _functions.httpsCallable(
      'bootstrapUserSession',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
    );

    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await callable.call(<String, dynamic>{
          'userId': userId,
          'deviceId': deviceId,
        });

        final data = Map<String, dynamic>.from(response.data as Map);
        return BootstrapSession.fromJson(data);
      } on FirebaseFunctionsException catch (error) {
        final shouldRetry =
            _isTransientBootstrapError(error) && attempt < maxAttempts - 1;
        if (!shouldRetry) {
          _logBootstrapFailure(error, attempt + 1);
          rethrow;
        }
        _logBootstrapRetry(error, attempt + 1, maxAttempts);
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      } catch (_) {
        rethrow;
      }
    }

    throw StateError('bootstrapUserSession retry exhausted');
  }

  bool _isTransientBootstrapError(FirebaseFunctionsException error) {
    return switch (error.code) {
      'unavailable' ||
      'deadline-exceeded' ||
      'internal' ||
      'unauthenticated' => true,
      _ => false,
    };
  }

  void _logBootstrapRetry(
    FirebaseFunctionsException error,
    int attempt,
    int maxAttempts,
  ) {
    if (!kDebugMode) return;

    debugPrint(
      'bootstrapUserSession retry $attempt/$maxAttempts '
      'after ${error.code}: ${error.message ?? '-'}',
    );
  }

  void _logBootstrapFailure(FirebaseFunctionsException error, int attempts) {
    if (!kDebugMode) return;

    debugPrint(
      'bootstrapUserSession failed after $attempts attempts '
      '(${error.code}): ${error.message ?? '-'}; details=${error.details}',
    );
  }
}
