import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/study_session_result.dart';

class StudySessionRepository {
  StudySessionRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<StudySessionResult> startStudySession({
    required String userId,
    required String contentSetId,
    required String category,
    required String level,
    required String mode,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'startStudySession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );
      final response = await callable.call(<String, dynamic>{
        'userId': userId,
        'contentSetId': contentSetId,
        'category': category,
        'level': level,
        'mode': mode,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return StudySessionResult.fromJson(data);
    } on TimeoutException {
      return StudySessionResult.fallback();
    } on FirebaseFunctionsException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }
}
