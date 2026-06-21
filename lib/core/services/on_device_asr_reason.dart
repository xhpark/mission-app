String onDeviceAsrReasonToKorean(String? reason) {
  switch (reason) {
    case 'unsupported_platform':
      return '현재 기기에서는 온디바이스 음성 인식을 지원하지 않습니다.';
    case 'model_path_not_configured':
      return '온디바이스 음성 인식 모델 설치 경로를 찾지 못했습니다.';
    case 'model_files_not_found':
      return '온디바이스 음성 인식 모델이 설치되어 있지 않습니다. 앱 전용 폴더에 모델을 설치해 주세요.';
    case 'model_update_required':
      return '온디바이스 음성 인식 모델 업데이트가 필요합니다. 새 모델을 다시 다운로드해 설치해 주세요.';
    case 'engine_init_failed':
      return '온디바이스 음성 인식 엔진 초기화에 실패했습니다. 모델 파일을 다시 설치해 주세요.';
    case 'ON_DEVICE_ASR_UNAVAILABLE':
      return '온디바이스 음성 인식을 사용할 수 없습니다.';
    default:
      return '온디바이스 음성 인식 사용이 불가능합니다.';
  }
}
