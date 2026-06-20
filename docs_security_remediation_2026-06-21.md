# 보안/무결성 정비 기록 — 2026-06-21

Claude + Codex 상호 검증(4라운드 합의)에서 확정한 출시전 blocker와 fast-follow를
구현한 기록이다. 근본 원인: *학습 콘텐츠와 결과 산정의 권위가 클라이언트에 있고,
서버는 저장소 역할만 하며 `itemId→정답/expectedText/정원` 계약을 강제하지 않았다.*

## 출시전 Blocker (완료)

### F2 — 하드코딩 PII 제거
- `functions/src/index.ts`의 관리자 실명/전화/이메일/사전승인 이메일 상수를 환경변수
  기반으로 전환(`ADMIN_CONTACT`, `ADMIN_APPROVAL_EMAIL`, `ADMIN_DEFAULT_NAME`,
  `ADMIN_DEFAULT_PHONE`, `PREAPPROVED_TEST_EMAILS`).
- `functions/.env.example` 추가, `functions/.gitignore`에 `.env` 보호 추가.
- **운영 조치 필요**: 배포 전 `functions/.env`에 실제 값을 채운다. 값이 비어 있으면
  기본 관리자 자동 부여/사전승인은 비활성(안전 기본값)이다.

### F3 — 계정 열거 차단
- `findLearnerEmail`의 하드코딩된 기본 관리자 우회 반환 제거.
- 모든 callable에 App Check 강제(아래 참조)로 무차별 호출 차단.

### App Check 강제
- 모든 `onCall`에 `callableOptions = { enforceAppCheck }` 적용. 기본 ON.
- **개발/QA**: 비검증 클라이언트로 로컬 테스트가 필요하면 dev 프로젝트의
  `functions/.env`에 `ENFORCE_APP_CHECK=false`. (익명/개발 세션은 서버 callable을
  호출하지 않고 로컬 경로를 타므로 영향 없음. 실계정 디버그 호출 시에만 필요.)

### 콘텐츠 매니페스트 (서버 채점 권위)
- 단일 출처 `lib/features/learning_content/data/thai_learning_content.dart`에서
  `tool/build_content_manifest.dart`가 `functions/src/generated/thai_content_manifest.ts`
  를 생성. `itemId → {type, expectedText}`와 모드별 정원을 담는다.
- 재생성: `dart run tool/build_content_manifest.dart`
- 드리프트 검사: `test/content_manifest_drift_test.dart`가 `flutter test`에서
  매니페스트와 Dart 콘텐츠 일치를 검증(CI 커버).

### C1 — 서버 권위 채점/집계
- `submitChoiceTestItem`: `selectedItemId` 기반 서버 판정(정답 옵션 id == 질문 itemId).
  클라 `correctIndex`는 매니페스트가 아는 항목이면 신뢰하지 않음. 레거시 인덱스는
  매니페스트 미스 시에만 폴백. 클라(`session_runtime_repository` + 3개 선택형 화면)는
  선택 옵션의 id를 전송. `wordThaiOptions`에 optionIds 추가.
- `evaluateSpeakingAttempt` / `submitOnDeviceSpeakingFallback`: `expectedText`를
  매니페스트에서 조회(권위). 클라 입력은 미지 콘텐츠셋 폴백만.
- `startStudySession`: 정원(`totalItems`)을 매니페스트에서 산정(권위).
- `completeReportSubmission`: 대시보드 입력(`attemptedAnswers`/`correctAnswers`/
  `averageSimilarity`/`assessmentApplicable`)을 저장된 attempt 기반 서버 산출값으로만
  계산. 자기보고 완료수는 비채점(학습) 모드에만 허용.
- 채점 계약 회귀 테스트: `test/learning_content_contract_test.dart`(문장+단어 옵션 id가
  질문 itemId와 일치).

## Fast-follow

### F1 — 주간 리포트 게이트 (휴면, 베타 비활성)
- 서버 주도 게이트(`user_report_state.reportGateStage`/`learningBlocked`)를 *올리는*
  코드/스케줄러가 백엔드에 없다 → 현재 **휴면**. 베타에서 강제되지 않는다.
- 라우트 가드/읽기/문구는 향후 활성화를 위해 무해하게 유지.
- **활성화하려면**: 주간 경계에 `reportGateStage`/`learningBlocked`를 설정하는 스케줄
  함수(`onSchedule`)를 추가해야 한다. 그 전까지 "주간 강제"를 사용자에게 약속/홍보하지
  않는다(관리 원칙 문서의 "과도하게 강제하지 않는다"와 일치).
- 클라의 세션 종료 후 리포트 프리뷰 유도(`requireReport()`)는 별개의 정상 UX이며 유지.

### F12 — 저장소/메타 (일부)
- `pubspec.yaml` description를 실제 제품 설명으로 교체.
- `firebase_app_check` 버전 상향은 `pub get` 필요로 별도 처리(미적용).

## 미적용(별도 작업 권고)
- **F4** 실기기/`integration_test` E2E: 디바이스 필요, 본 작업 범위 밖. 출시 전 수동 스모크 필수.
- **F5** 부트스트랩 승인 폴백의 자문적 게이팅: 서버 재검증으로 실질 차단 유지됨(설계 문서화 권고).
- **F6** 콘텐츠 Firestore 전면 이전: 매니페스트 교차검증으로 베타 무결성 확보. 전면 이전은 후속.
- **F7** 유사도 로직 통합: 클라 사본은 오프라인 폴백 추정치 전용(서버가 온라인 권위).
- **F9** 녹음 저장(SharedPreferences→파일): 미적용.
- **F10** 대형 파일 분해: 미적용.
- **F11** 미커밋 작업 정리/커밋 분할: 사용자 지시 시 진행.

## 검증
- `flutter analyze`: 0 issues
- `flutter test`: 전체 통과
- `npm --prefix functions run build`: 통과
