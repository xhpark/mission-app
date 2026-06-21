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
      return _mapFailedPreconditionMessage(error.message);
    case 'invalid-argument':
      return '학습 요청 정보가 올바르지 않습니다. 선택 항목을 확인하고 다시 시도해 주세요.';
    case 'unavailable':
      return '서버가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요.';
    case 'deadline-exceeded':
      return '서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.';
    case 'internal':
      return _mapInternalFunctionsMessage(error.message);
    default:
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
      return '서버 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  }
}

String _mapFailedPreconditionMessage(String? rawMessage) {
  switch (rawMessage?.trim()) {
    case 'PENDING_APPROVAL':
      return '관리자 승인 후 학습을 시작할 수 있습니다.';
    case 'LEARNING_BLOCKED':
      return '현재 학습이 제한되어 있습니다. 필요한 보고서 또는 안내를 먼저 확인해 주세요.';
    default:
      return '현재 상태에서는 이 작업을 수행할 수 없습니다.';
  }
}

String _mapInternalFunctionsMessage(String? rawMessage) {
  switch (rawMessage?.trim()) {
    case 'START_STUDY_SESSION_FAILED':
      return '학습 세션을 만들지 못했습니다. 서버 로그를 확인해야 합니다.';
    default:
      return '서버 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  }
}

String _mapAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-credential':
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    case 'user-not-found':
      return '등록되지 않은 이메일입니다.';
    case 'wrong-password':
      return '비밀번호가 올바르지 않습니다.';
    case 'email-already-in-use':
      return '이미 등록된 이메일입니다.';
    case 'weak-password':
      return '비밀번호가 너무 짧거나 약합니다.';
    case 'network-request-failed':
      return '네트워크 요청에 실패했습니다. 연결 상태를 확인해 주세요.';
    case 'too-many-requests':
      return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    default:
      return '인증 처리 중 오류가 발생했습니다.';
  }
}
