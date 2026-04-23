import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String toUserFacingErrorMessage(Object error) {
  if (error is StateError) {
    return error.message;
  }

  if (error is TimeoutException) {
    return '요청 시간이 초과되었습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.';
  }

  if (error is FirebaseFunctionsException) {
    return _mapFunctionsError(error);
  }

  if (error is FirebaseAuthException) {
    return _mapAuthError(error);
  }

  return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

String _mapFunctionsError(FirebaseFunctionsException error) {
  switch (error.code) {
    case 'unauthenticated':
      return '로그인이 필요합니다. 다시 로그인해 주세요.';
    case 'permission-denied':
      return '이 작업을 수행할 권한이 없습니다.';
    case 'not-found':
      return '요청한 학습 데이터를 찾을 수 없습니다.';
    case 'failed-precondition':
      return '현재 상태에서는 이 작업을 수행할 수 없습니다.';
    case 'unavailable':
      return '서버가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요.';
    default:
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
      return '서버 처리 중 오류가 발생했습니다.';
  }
}

String _mapAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'network-request-failed':
      return '네트워크 요청에 실패했습니다. 연결 상태를 확인해 주세요.';
    case 'too-many-requests':
      return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    default:
      return '인증 처리 중 오류가 발생했습니다.';
  }
}
