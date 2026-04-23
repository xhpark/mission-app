# On-device ASR Fallback 설정 가이드 (업데이트)
작성일: 2026-04-19  
적용 프로젝트: `D:\proj\mission_app`

## 1. 목적
서버 STT 평가가 실패하거나 네트워크가 불안정한 경우에도 학습 진행을 끊지 않기 위해,
서버 STT와 온디바이스 ASR(sherpa-onnx)을 정책 기반으로 병행 운영한다.

## 2. 음성 인식 정책(필수)
앱에서 학습자가 다음 중 하나를 선택한다.

1. `서버 STT 전용 (저사양 권장)`
- 로컬 ASR 모델을 다운로드하지 않는다.
- 네트워크/서버 장애 시 음성평가는 실패 안내를 표시한다.
- 오프라인 fallback을 사용하지 않는다.

2. `오프라인 지원 (로컬 ASR 사용)`
- 서버 STT 실패 시 온디바이스 ASR로 fallback 평가를 시도한다.
- 서버 저장 실패 시 로컬 오프라인 큐에 적재하고 학습은 계속 진행한다.
- 네트워크 복구 시 큐를 자동 동기화한다.

## 3. 현재 fallback 동작 요약
적용 화면:
- `sentence_test_speaking`
- `flash_sentence_test_speaking`

동작 흐름:
1. 녹음 후 서버 STT `evaluateSpeakingAttempt` 호출
2. 서버 STT 성공이면 서버 결과 사용
3. 서버 STT 실패 또는 transcript 없음이면 정책 분기
- 서버 STT 전용: 오류 안내 후 종료
- 오프라인 지원: 온디바이스 ASR 실행
4. 온디바이스 결과 저장 시도
- 온라인: `submitOnDeviceSpeakingFallback` 저장 성공
- 오프라인/네트워크 장애: 로컬 큐 저장(`QUEUED_OFFLINE`) 후 계속 진행
5. 동기화 워커가 큐를 서버로 재전송

## 4. 오프라인 큐 / sync worker 정책
- 오프라인 큐 저장소: `SharedPreferences` JSON queue
- 워커는 `pendingCount > 0`일 때만 타이머(45초)를 시작한다.
- 큐가 비면 타이머를 즉시 중지한다.
- 큐가 생기면 즉시 1회 동기화를 먼저 시도하고, 이후 주기 동기화한다.

즉, 네트워크 호출은 큐가 있을 때만 발생한다.

## 5. sherpa-onnx 모델 경로 설정
온디바이스 ASR 사용 시 `--dart-define`로 모델 경로를 전달한다.

주요 키:
- `SHERPA_ONNX_MODEL_DIR`
- `SHERPA_ONNX_TOKENS_PATH`
- `SHERPA_ONNX_MODEL_PATH` (단일 모델 구성 시)
- `SHERPA_ONNX_ENCODER_PATH`
- `SHERPA_ONNX_DECODER_PATH`
- `SHERPA_ONNX_JOINER_PATH`
- `SHERPA_ONNX_MODEL_TYPE` (기본 `zipformer2_ctc`)

예시:
```powershell
flutter run -d windows `
  --dart-define=SHERPA_ONNX_MODEL_DIR=D:/AI/sherpa-onnx/sherpa-th/active-int8 `
  --dart-define=SHERPA_ONNX_TOKENS_PATH=D:/AI/sherpa-onnx/sherpa-th/active-int8/tokens.txt `
  --dart-define=SHERPA_ONNX_ENCODER_PATH=D:/AI/sherpa-onnx/sherpa-th/active-int8/encoder.int8.onnx `
  --dart-define=SHERPA_ONNX_DECODER_PATH=D:/AI/sherpa-onnx/sherpa-th/active-int8/decoder.int8.onnx `
  --dart-define=SHERPA_ONNX_JOINER_PATH=D:/AI/sherpa-onnx/sherpa-th/active-int8/joiner.int8.onnx
```

## 6. 플랫폼 제약
- 온디바이스 ASR 엔진은 현재 `dart:io` 기반 플랫폼(Android/iOS/Windows/macOS/Linux)에서 동작한다.
- Chrome(Web)에서는 현재 stub 경로로 동작하므로 온디바이스 ASR은 비활성이다.

## 7. 에러/상태 코드
주요 코드:
- `STT_UNAVAILABLE`
- `NETWORK_REQUIRED_SERVER_ONLY`
- `QUEUED_OFFLINE`
- `ON_DEVICE_ASR_UNAVAILABLE`
- `unsupported_platform`
- `model_path_not_configured`
- `model_files_not_found`
- `engine_init_failed`

## 8. QA 체크리스트
1. 서버 STT 전용 모드에서 네트워크 차단 시 오류 안내가 뜨는지 확인
2. 오프라인 지원 모드에서 서버 실패 시 온디바이스 평가가 수행되는지 확인
3. 오프라인 상태에서 `QUEUED_OFFLINE` 메시지와 학습 진행이 유지되는지 확인
4. 온라인 복구 후 오프라인 큐가 자동 동기화되는지 확인
5. 큐가 0건일 때 주기 동기화 타이머가 중지되는지 확인
