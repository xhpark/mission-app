String onDeviceAsrReasonToKorean(String? reason) {
  switch (reason) {
    case 'unsupported_platform':
      return '현재 플랫폼에서는 온디바이스 ASR을 지원하지 않습니다.';
    case 'model_path_not_configured':
      return '온디바이스 ASR 모델 경로가 설정되지 않았습니다.';
    case 'model_files_not_found':
      return '온디바이스 ASR 모델 파일을 찾을 수 없습니다.';
    case 'engine_init_failed':
      return '온디바이스 ASR 엔진 초기화에 실패했습니다.';
    case 'ON_DEVICE_ASR_UNAVAILABLE':
      return '온디바이스 ASR을 사용할 수 없습니다.';
    default:
      return '온디바이스 ASR 사용이 불가능합니다.';
  }
}
