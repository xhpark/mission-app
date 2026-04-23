# 학습앱 E2E 클릭 동선 체크리스트 (로그인→선택→학습→테스트→요약→리포트)

## 1) 범위
- 기준 동선: `/login` → `/select` → 학습 모드 진입 → 테스트(선택/말하기) → `/session-summary` → `/report-preview` → `/report`
- 대상 환경: 웹(Chrome), 개발 모드 포함
- 목표: 화면 진입/라우팅/핵심 버튼/세션 상태/오류 메시지까지 단계별 검증

## 2) 공통 사전 조건
- 앱 실행 후 첫 진입 라우트가 `/bootstrap`에서 시작되는지 확인
- 우측 상단 `QA 디버그` 패널로 아래 값 확인
  - route
  - user status
  - sessionId
  - contentSetId
- 테스트 중 실패 시 즉시 기록
  - 현재 라우트
  - 클릭한 버튼 라벨
  - 스낵바/배너 오류 문구
  - QA 디버그 값 스크린샷

## 3) 핵심 동선 체크리스트

| 단계 | 사용자 액션 | 기대 화면/상태 | 실패 시 1차 로그 포인트 |
|---|---|---|---|
| 0 | 앱 최초 실행 | `/bootstrap` 로딩 후 인증 상태에 따라 `/login` 또는 `/select` 이동 | `lib/app/router/app_router.dart`, `lib/app/router/app_route_guard.dart`, `lib/features/bootstrap/presentation/controllers/bootstrap_controller.dart` |
| 1 | `/login`에서 `Continue for Development` 클릭 | 개발 세션 활성화 후 `/select` 이동 | `lib/features/auth/presentation/controllers/auth_controller.dart`의 `enterDevelopmentMode()` |
| 2 | `/select` 진입 확인 | 카테고리/레벨/모드 선택 UI, 시작 버튼 비활성(초기) | `lib/features/learning_select/presentation/screens/learning_select_screen.dart` |
| 3 | 카테고리/레벨/모드 모두 선택 | 시작 버튼 활성화 | `lib/features/learning_select/presentation/controllers/learning_selection_controller.dart` |
| 4 | `학습 시작` 클릭 | 세션 생성 후 모드별 라우트 이동 (`/sentence-learning` 등) | `lib/features/learning_select/presentation/controllers/start_study_session_controller.dart` |
| 5 | 문장 학습 화면에서 `문장 들어보기` 클릭 | 문장 오디오 재생, 오류 시 스낵바 노출 | `lib/features/sentence_learning/presentation/screens/sentence_learning_screen.dart`, `lib/core/services/audio_player_service.dart` |
| 6 | 문장 학습 화면에서 `내 목소리로 읽기` → `녹음 중지` | 녹음 완료 후 `내 녹음 듣기` 버튼 노출 | `lib/core/services/recorder_service.dart`, `sentence_learning_screen.dart` |
| 7 | 문장 학습에서 `완료하고 다음으로` 반복 | 진행도 증가, 마지막에 세션 완료 상태 표시 | `lib/features/sentence_learning/presentation/controllers/sentence_learning_controller.dart`, `lib/features/session_runtime/presentation/controllers/study_flow_controller.dart` |
| 8 | 문장 테스트(선택형) 진입 시 정답 선택 후 진행 | `/sentence-test/choice` 반복 또는 `/sentence-test/speaking` 이동 | `lib/features/sentence_test/presentation/screens/sentence_test_choice_screen.dart` |
| 9 | 문장 테스트(말하기)에서 녹음/평가 후 `테스트 완료` | 조건 통과 시 다음 문항 또는 `/session-summary` 이동 | `lib/features/sentence_test/presentation/screens/sentence_test_speaking_screen.dart`, `lib/core/services/asr_policy_controller.dart`, `lib/core/services/on_device_asr_engine.dart` |
| 10 | `/session-summary` 확인 후 `리포트 프리뷰로` 클릭 | `/report-preview` 이동, 세션 요약 정보 표시 | `lib/features/session_summary/presentation/screens/session_summary_screen.dart`, `lib/features/reporting/presentation/screens/report_preview_screen.dart` |
| 11 | `/report-preview`에서 `리포트 작성으로` 클릭 | `/report` 이동 | `lib/features/reporting/presentation/screens/report_preview_screen.dart` |
| 12 | `/report`에서 체크리스트+소감 입력 후 제출 | 제출 성공 배너, 세션/진행 상태 초기화 | `lib/features/reporting/presentation/screens/report_screen.dart`, `lib/features/reporting/presentation/controllers/report_requirement_controller.dart` |

## 4) 모드별 추가 검증 (필수)

아래 모드는 `/select`에서 각각 선택 후, 동일 방식으로 진입/진행/완료를 확인한다.

| 모드 | 진입 라우트 | 핵심 확인 포인트 |
|---|---|---|
| 문장 학습 | `/sentence-learning` | 문장+주요단어 매핑, 단어 칩 클릭 오디오 재생 |
| 문장 테스트 | `/sentence-test/choice` | 선택형→말하기형 순환, 정답/오답 옵션 중복 없음 |
| 플래시 단어 학습 | `/flash-word-learning` | 카드 전환, 단어 오디오/의미 일치 |
| 플래시 단어 테스트 | `/flash-word-test` | 보기 중복 없음, 정답 1회 노출 |
| 플래시 문장 학습 | `/flash-sentence-learning` | 문장 카드 전환, 오디오 연결 |
| 플래시 문장 테스트 | `/flash-sentence-test/choice` | 보기 중복 없음, 말하기 단계 연계 |

## 5) 라우팅 가드 검증 항목
- 비로그인 상태에서 보호 라우트 진입 시 `/login` 리다이렉트
- 활성 세션 없는 상태에서 세션 필요 라우트 진입 시 `/select` 리다이렉트
- `/guide`, `/resume`는 세션 없어도 접근 가능해야 함
- reportRequired=true 인 경우 reportRoutes 외 진입 시 `/report-gate`로 이동

참조:
- `lib/app/router/app_route_guard.dart`
- `test/app_route_guard_test.dart`

## 6) 실패 유형별 즉시 점검 순서
1. QA 디버그 패널 값(route/sessionId/contentSetId) 확인
2. 현재 화면 스낵바/배너 문구 기록
3. 해당 단계의 컨트롤러/스크린 파일 확인
4. `flutter analyze` 실행
5. `flutter test` 실행
6. 재현 동작 1회 반복 후 동일 오류인지 확인

## 7) 완료 판정 기준
- 핵심 동선 0~12 단계 모두 통과
- 모드별 추가 검증 6개 모드 모두 통과
- 라우팅 가드 검증 4개 항목 통과
- `flutter analyze`: No issues found
- `flutter test`: All tests passed
