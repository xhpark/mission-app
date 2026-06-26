# 휴대전화번호 기반 인증 전환 — 영향 분석 (실제 코드 기준)

> 작성일: 2026-06-24
> 상태: **분석 완료 / 구현 보류**. 추후 plan 모드로 단계별 구현 계획 수립용 입력 자료.
> 목표: 34명 테스터의 **휴대전화번호만** 파악된 상태에서, 전화번호를 사용자 ID로
>      쓰고 SMS 링크로 앱을 배포·계정 생성하게 만드는 방안의 전체 영향 파악.

---

## 0. 한 줄 요약

데이터 모델은 이미 `phoneNormalized` 인덱스까지 갖춰 **phone-ready**다. 진짜 작업은
DB 마이그레이션이 아니라 **인증 신뢰 체계(관리자 인증·자동승인 화이트리스트·계정 복구)의
재작성**이다. 가장 치명적 리스크는 **관리자 인증이 전적으로 이메일에 묶여 있어** 전화번호
인증으로 전환하면 관리자 본인이 로그인/대시보드 접근이 불가능해진다는 점이다.

---

## 1. 현재 인증 아키텍처 (확인된 사실)

- **인증 방식**: Firebase Auth 이메일 + 비밀번호
- **사용자 ID**: Firebase Auth UID (UUID). 이메일은 사람이 읽는 식별자 + 신뢰 앵커로 사용.
- **승인 상태**: `pending_approval | approved | blocked` (`user_profiles/{uid}.status`)
- **관리자 식별**: 환경변수 `ADMIN_APPROVAL_EMAIL` 이메일 일치로 판정
- **자동 승인**: 환경변수 `PREAPPROVED_TEST_EMAILS` 이메일 화이트리스트

### 관련 핵심 파일
- `lib/features/auth/presentation/controllers/auth_controller.dart`
- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/bootstrap/data/models/bootstrap_session.dart`
- `functions/src/index.ts` (백엔드 전체)
- `firestore.rules`

---

## 2. 영향 영역 종합표 (실제 코드 위치 포함)

| # | 영역 | 파일/위치 | 심각도 |
|---|------|----------|--------|
| 1 | **관리자 인증 (email→phone/uid)** | `functions/src/index.ts:576-600` (`requireAdminUser`) | 🔴 치명 |
| 2 | **자동승인 화이트리스트 (email set)** | `index.ts:48,545` (`PREAPPROVED_TEST_EMAILS`, `shouldPreApproveUser`) | 🔴 높음 |
| 3 | **승인 요청/대기 알림** | `index.ts:652-745` (`notifyAdminForPendingApproval`, `sendAdminApprovalEmail`) | 🔴 높음 |
| 4 | **이메일 찾기/비번 재설정 UI** | `login_screen.dart:277-398` | 🔴 높음 |
| 5 | **email_verified 검증** | `index.ts:218-224,1136` (`authTokenEmailVerified`) | 🟡 중간 |
| 6 | **리포트/대시보드 email 표시** | `index.ts:1622,2111,2162` | 🟡 중간 |
| 7 | **인증 컨트롤러 (signIn/createAccount)** | `auth_controller.dart:51-93` | 🔴 높음 |
| 8 | **앱 배포 (App Distribution은 email만 지원)** | (배포 인프라) | 🟡 중간 |
| 9 | **bootstrap 세션 (email 기반 승인)** | `index.ts:989-1116` | 🔴 높음 |

---

## 3. 영역별 상세

### 🔴 3.1 승인 워크플로 (승인요청 → 승인대기 → 관리자 승인)

전 과정이 이메일에 묶여 있음:

| 단계 | 코드 | 이메일 의존 |
|------|------|------------|
| 자동 승인 판정 | `shouldPreApproveUser(email)` `index.ts:545` | `PREAPPROVED_TEST_EMAILS`에 **이메일 목록**으로 화이트리스트 |
| 관리자 판정 | `isDefaultAdminEmail(email)` `index.ts:549` | 관리자를 **이메일**(`ADMIN_APPROVAL_EMAIL`)로 식별 |
| 승인 요청 알림 | `notifyAdminForPendingApproval()` `index.ts:652` | 텔레그램/이메일 발송 (phone은 이미 포함, 단 email이 주 식별자) |
| SMTP 승인 메일 | `sendAdminApprovalEmail()` `index.ts:676` | 관리자에게 **이메일로** 발송 |
| 관리자 권한 검증 | `requireAdminUser()` `index.ts:576` | `tokenEmail === profile.email` 일치로 인증 |

**문제**: 전화번호 인증 시 Firebase 토큰에 `email`이 없음 →
- `requireAdminUser()`의 `emailMatchesToken`이 깨져 **관리자 대시보드 접근 불가**
- `shouldPreApproveUser()` 화이트리스트 무용지물 → 34명 자동승인 로직 재작성 필요

### 🔴 3.2 관리자 인증 = 이메일 (가장 치명적)

`index.ts:585-595`:
```typescript
const email = normalizeEmail(profile.email);
const tokenEmail = authTokenEmail(authToken);
const emailMatchesToken = email.length === 0 || tokenEmail === email;
const isConfiguredDefaultAdmin =
    isDefaultAdminEmail(email) && isDefaultAdminEmail(tokenEmail);
if (((role === "admin" || profile.admin === true) && emailMatchesToken) || isConfiguredDefaultAdmin) {
  return; // 관리자 통과
}
throw new HttpsError("permission-denied", "ADMIN_REQUIRED");
```
전화번호 인증 시 `token.email`이 비어 토큰 검증 전체가 무너짐.
→ **관리자 식별 체계를 phone 또는 uid 기반으로 전면 재설계 필요** (보안 코어 재작성).

### 🔴 3.3 이메일 찾기 / 비밀번호 재설정 UI

`login_screen.dart:277-398`:
- "이메일 찾기": 이름+전화번호 → `findLearnerEmail()` `index.ts:2403` → 마스킹 이메일 반환
- "비밀번호 재설정": 이메일로 재설정 메일 발송 `login_screen.dart:363`

전화번호 인증 전환 시:
- "이메일 찾기" 전체 삭제 또는 "계정 찾기"로 재설계
- "비밀번호 재설정" 삭제 (OTP는 비밀번호 없음)
- 참고: `findLearnerEmail`은 이미 `phoneNormalized`로 검색 중(`index.ts:2413`) → 전화 인프라 일부 존재

### 🟡 3.4 리포트/대시보드에 이메일이 식별자로 박힘

| 위치 | 사용 |
|------|------|
| `completeReportSubmission` `index.ts:1622` | 리포트에 `learnerEmail` 저장 |
| `getAdminDashboard` `index.ts:2111,2162` | 승인목록·학습자목록에 `email` 표시 |
| `user_learning_summary` | `learnerEmail` 필드 보관 |

기능은 안 깨지나, 표시 필드를 phone으로 교체하는 일관성 작업 필요.

### 🟡 3.5 email_verified 검증

`index.ts:218-224, 1136`에서 `authTokenEmailVerified()`를 `startStudySession`이 호출.
전화번호 인증은 `email_verified` 개념이 없으므로 분기 재정의 필요.

### 🟢 3.6 긍정 발견 — 이미 절반은 phone-ready

- `user_profiles`에 `phone`, `phoneNumber`, `phoneNormalized`, `learnerPhone` 필드 **이미 저장**
  (`index.ts:2371-2374` `updateLearnerProfile`)
- `normalizePhone()` 정규화 함수 **이미 존재** (`index.ts:529`)
- `findLearnerEmail`이 **이미 phoneNormalized 인덱스 검색** 중
- 승인 알림 텍스트에 **전화번호 이미 포함** (`index.ts:664`)
- 회원가입 시 이름+전화번호를 이미 입력받음 (`login_screen.dart:100-120`)

→ DB 스키마 마이그레이션 부담은 작다. 바꿔야 할 핵심은 인증·관리자식별·복구 흐름.

---

## 4. 배포 방식 변경 (App Distribution은 이메일만 지원)

현재: Firebase App Distribution(이메일 초대). 전화번호만으로는 초대 불가.

방안:
- **A. SMS 링크 배포 (권장)**: 관리자가 전화번호 입력 → 백엔드가 다운로드 링크 생성 →
  SMS 발송 → 링크 클릭 → APK/Play Store. `functions/src/generateDownloadLink.ts`(신규) +
  SMS 서비스 통합 필요.
- **B. QR 코드 + 공개 링크**: SMS 비용 절감, 인식 단계 추가.
- **C. Play Store 내부 테스트**: 난이도 낮음, Google Play Console 수동 초대.

SMS 비용(34명, 1회): $0.35~1.75 수준. 월 운영비 무시 가능.

---

## 5. 인증 전환 방식 비교

| 방안 | 흐름 | 장점 | 단점 |
|------|------|------|------|
| **A. Firebase 전화번호 인증 (권장)** | 전화 입력→OTP→자동 로그인 | Firebase 기본 지원, 보안 높음 | 매 로그인 OTP, SMS 비용, 국제번호 처리 |
| B. 커스텀(임시 비번 SMS) | 전화→임시비번 SMS→로그인 | 기존 이메일 로직 일부 재사용 | 보안 약함, SMS 서비스 별도 구축 |

권장: **방안 A**. OTP는 `phoneNormalized`를 키로 `user_profiles`와 연결.

---

## 6. 보안·규정·국제화

- 전화번호는 개인정보 → 한국 개인정보보호법 명시적 동의 필요. 약관/처리방침 개정.
- 사용자국가(한국/태국/미국) 혼재 → `libphonenumber`로 E164 정규화 권장.
- `firestore.rules`는 현재 `isOwner(userId)` 기반이라 직접적 email 의존은 없음(영향 작음).
  단 관리자 판정은 rules가 아니라 함수(`requireAdminUser`)에서 하므로 거기서 재설계.

---

## 7. 추후 plan 모드 입력용 — 구현 단계 골격 (초안)

> 아래는 계획 수립 시 출발점. 실제 plan 모드에서 구체화/검증할 것.

### Phase 0. 결정 사항 (착수 전 확정 필요)
- 관리자 식별을 **uid 고정** vs **phone 화이트리스트** 중 무엇으로?
- 기존 이메일 계정과 **병렬 운영**할지, **전화 전용**으로 갈지?
- SMS 서비스: Firebase Phone Auth 내장 vs Twilio vs 국내(Naver/Kakao)?

### Phase 1. 인증 코어 (P0)
1. `requireAdminUser()`를 email→(uid 또는 phoneNormalized) 기반으로 재작성 `index.ts:576`
2. 자동승인을 `PREAPPROVED_TEST_PHONES`(정규화 전화 set)로 전환 `index.ts:48,545`
3. `bootstrapUserSession`/`resolveUserStatus`의 email 의존 분기 재작성 `index.ts:938,989`
4. `authTokenEmailVerified` 분기 제거/대체 `index.ts:218,1136`
5. Flutter: `auth_controller.dart` 전화 OTP 메서드 추가, `login_screen.dart` UI 전환

### Phase 2. 계정 복구·알림 (P0~P1)
1. "이메일 찾기/비번 재설정" → "전화로 계정 찾기/재인증"으로 재설계 `login_screen.dart:277`
2. `findLearnerEmail` → `findLearnerAccount`(phone 기반) 정리 `index.ts:2403`
3. 승인 알림(`notifyAdminForPendingApproval`/SMTP)을 phone 중심으로 정리 `index.ts:652`

### Phase 3. 배포 (P0)
1. `generateDownloadLink` 함수 + 관리자 UI
2. SMS 발송 통합, 34명 일괄 발송
3. APK 다운로드/설치 E2E 점검

### Phase 4. 표시·정합성·테스트 (P1)
1. 대시보드/리포트의 email 표시 필드를 phone으로 교체 `index.ts:1622,2111,2162`
2. `user_learning_summary.learnerEmail` 처리 정리
3. 단위/통합/E2E 테스트 추가 (전화 유효성, OTP, 중복, 관리자 인증)
4. 기존 사용자 마이그레이션 스크립트(필요 시)

---

## 8. 핵심 리스크 톱3 (착수 시 최우선 점검)

1. **관리자 락아웃**: phone 전환 시 관리자 본인 로그인/대시보드 불가 → Phase 1.1 먼저.
2. **34명 자동승인 붕괴**: email 화이트리스트 무용 → Phase 1.2 동반 필수.
3. **계정 복구 공백**: 비번 재설정/이메일 찾기 삭제로 복구 경로 사라짐 → Phase 2 필수.

---

## 9. 참고: 변경 불필요/영향 적은 곳

- `firestore.rules`: `isOwner(uid)` 기반이라 거의 그대로 사용 가능.
- 학습 콘텐츠·오디오·플래시/테스트 로직: 인증과 무관, 영향 없음.
- `test/learning_content_contract_test.dart`: 콘텐츠 계약 테스트라 무관.
