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
      final callable = _functions.httpsCallable('bootstrapUserSession');
      final response = await callable.call(<String, dynamic>{
        'userId': userId,
        'deviceId': deviceId,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return BootstrapSession.fromJson(data);
    } on FirebaseFunctionsException {
      return BootstrapSession.fallback();
    } catch (_) {
      return BootstrapSession.fallback();
    }
  }
}
