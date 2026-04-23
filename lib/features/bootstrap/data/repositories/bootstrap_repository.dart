import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/bootstrap_session.dart';

class BootstrapRepository {
  BootstrapRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<BootstrapSession> bootstrapUserSession({
    required String userId,
    required String deviceId,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'bootstrapUserSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );
      final response = await callable.call(<String, dynamic>{
        'userId': userId,
        'deviceId': deviceId,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return BootstrapSession.fromJson(data);
    } on TimeoutException {
      return BootstrapSession.fallback();
    } on FirebaseFunctionsException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }
}
