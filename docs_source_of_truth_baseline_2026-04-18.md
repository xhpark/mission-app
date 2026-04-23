# Mission App 기준 문서 체계 확정본

작성일: 2026-04-18
적용 범위: `D:\proj\mission_app` Flutter 앱, Firebase Functions, Firestore, 운영/자동화

## 1. 목적

이 문서는 현재 산재된 개발 문서들 중 어떤 문서를 실제 구현 기준으로 사용할지 확정하기 위한 기준 문서다.

목표는 다음과 같다.

1. Flutter 개발자가 어떤 문서를 먼저 봐야 하는지 명확히 한다.
2. UI, API, Firestore, 운영 문서 간 충돌이 발생할 때 판정 기준을 고정한다.
3. 구버전 문서가 최신 구현을 오염시키지 않도록 사용 범위를 제한한다.

## 2. 최종 기준 문서 세트

아래 6개를 공식 기준 문서로 확정한다.

1. `UI_DETAIL_SPEC_v5.docx`
2. `API_FULL_SPEC_v3.docx`
3. `Firestore_Complete_Schema_v3.docx`
4. `08_Flutter_Project_Structure_State_Design_v1.docx`
5. `09_ADMIN_MANUAL_v1.docx`
6. `Automation_Script_Spec_v3.docx`

이 6개 외의 문서는 직접 구현 기준이 아니라 보조 참고 자료로만 사용한다.

## 3. 문서별 역할 정의

### 3.1 `UI_DETAIL_SPEC_v5.docx`

역할: Flutter 화면 구현의 1차 기준 문서

이 문서가 책임지는 범위:

- 화면 목록
- 화면 진입 조건
- 상태
- 이벤트
- 유효성 검사
- 예외 흐름
- 접근성 기준
- UI에서 필요한 Firestore/API 연계 포인트

판정 원칙:
화면 동작, 버튼 상태, 화면 분기, 사용자 메시지, 화면 전환 조건은 이 문서를 최우선으로 따른다.

### 3.2 `API_FULL_SPEC_v3.docx`

역할: 앱-백엔드 인터페이스의 1차 기준 문서

이 문서가 책임지는 범위:

- callable function 인터페이스
- 요청/응답 구조
- 공통 응답 envelope
- 에러 코드
- 인증/권한 모델
- Flutter와 Functions 간 계약

판정 원칙:
함수 이름, 요청 파라미터, 응답 DTO, 서버 책임 범위는 이 문서를 최우선으로 따른다.

### 3.3 `Firestore_Complete_Schema_v3.docx`

역할: Firestore 데이터 구조의 1차 기준 문서

이 문서가 책임지는 범위:

- 컬렉션/문서 경로
- 필드 정의
- enum 값
- 인덱스 권장안
- 보안 규칙 원칙

판정 원칙:
컬렉션 경로, 필드명, 저장 책임, 읽기/쓰기 분리는 이 문서를 최우선으로 따른다.

### 3.4 `08_Flutter_Project_Structure_State_Design_v1.docx`

역할: Flutter 앱 내부 구조의 1차 기준 문서

이 문서가 책임지는 범위:

- 폴더 구조
- feature 분리 기준
- Riverpod 상태관리 방식
- controller/provider/repository 역할 분리
- 라우팅 구조 초안

판정 원칙:
코드 아키텍처와 레이어 분리는 이 문서를 따른다. 단, 화면 동작은 `UI_DETAIL_SPEC_v5.docx`, 데이터 계약은 `API_FULL_SPEC_v3.docx`, 스키마는 `Firestore_Complete_Schema_v3.docx`를 우선한다.

### 3.5 `09_ADMIN_MANUAL_v1.docx`

역할: 관리자 운영 정책 기준 문서

이 문서가 책임지는 범위:

- 관리자 역할
- 운영 절차
- 콘텐츠 등록 절차
- 학습자 승인 절차
- 보고/오류 대응 절차

판정 원칙:
운영자 액션, 운영 승인 절차, 관리자 화면의 업무 목적은 이 문서를 따른다.

### 3.6 `Automation_Script_Spec_v3.docx`

역할: 콘텐츠 자동화 파이프라인 기준 문서

이 문서가 책임지는 범위:

- 자동화 범위
- 입력 포맷
- validate/build/upload 파이프라인
- TTS/QA/upload/smoke test 흐름
- 스크립트 단위 책임

판정 원칙:
자동화 저장소 구조와 스크립트 흐름은 이 문서를 따른다. 단, 최종 Firestore 경로와 필드 정의는 `Firestore_Complete_Schema_v3.docx`와 충돌할 수 없다.

## 4. 우선순위 규칙

문서가 충돌할 경우 아래 우선순위로 판정한다.

1. 화면 동작/상태/전환: `UI_DETAIL_SPEC_v5.docx`
2. API 계약/서버 책임: `API_FULL_SPEC_v3.docx`
3. Firestore 경로/필드/데이터 구조: `Firestore_Complete_Schema_v3.docx`
4. Flutter 폴더 구조/상태관리/레이어링: `08_Flutter_Project_Structure_State_Design_v1.docx`
5. 운영 절차: `09_ADMIN_MANUAL_v1.docx`
6. 자동화 절차: `Automation_Script_Spec_v3.docx`

보조 문서는 위 기준 문서를 뒤집을 수 없다.

## 5. 보조 참고 문서

아래 문서는 참고용으로만 사용한다.

1. `01_PRD_v3.docx`
2. `02_USER_FLOW_UI_SPEC_v3.docx`
3. `03_INFORMATION_ARCHITECTURE_v3.docx`
4. `05_FEATURE_SPEC_v3.docx`
5. `Mission_App_FINAL_v3.docx`
6. `Mission_App_FULL_SPEC_v3.docx`

사용 원칙:

- 제품 방향을 이해할 때 참고 가능
- 최신 기준 문서의 빈칸을 메울 때 보조 참고 가능
- 최신 기준 문서와 충돌하면 즉시 배제
- 구현 명세를 확정하는 근거 문서로 사용 금지

## 6. 직접 구현 기준으로 사용 금지할 문서

아래 문서는 구버전 또는 상위 문서로 대체되었으므로 직접 구현 기준으로 사용하지 않는다.

1. `06_UI_DETAIL_SPEC_wireframe_v4.docx`
2. `07_API_SPEC_v1.docx`
3. `04_DATABASE_SCHEMA_v3.docx`
4. `10_AUTOMATION_PLAN_v2.docx`

사용 금지 이유:

- 최신 문서가 이미 존재함
- 참조 버전이 오래됨
- 구현 시 충돌 가능성이 높음

## 7. 도메인별 실제 사용 방법

### 7.1 Flutter 화면 개발

아래 순서로 문서를 본다.

1. `UI_DETAIL_SPEC_v5.docx`
2. `08_Flutter_Project_Structure_State_Design_v1.docx`
3. `API_FULL_SPEC_v3.docx`
4. `Firestore_Complete_Schema_v3.docx`

적용 예:

- 화면 구성, 버튼 상태, 이벤트 흐름은 UI v5 기준
- provider/controller/repository 배치는 Flutter 구조 문서 기준
- 서버 호출 DTO는 API FULL 기준
- Firestore document path는 Complete Schema 기준

### 7.2 Firebase Functions 개발

아래 순서로 문서를 본다.

1. `API_FULL_SPEC_v3.docx`
2. `Firestore_Complete_Schema_v3.docx`
3. `UI_DETAIL_SPEC_v5.docx`

적용 예:

- callable 이름과 응답은 API FULL 기준
- 저장 경로와 필드는 Firestore Complete Schema 기준
- 화면에서 필요한 타이밍과 예외 처리는 UI v5 기준

### 7.3 Firestore/보안 규칙 설계

아래 순서로 문서를 본다.

1. `Firestore_Complete_Schema_v3.docx`
2. `API_FULL_SPEC_v3.docx`
3. `09_ADMIN_MANUAL_v1.docx`

### 7.4 운영/관리자 기능 개발

아래 순서로 문서를 본다.

1. `09_ADMIN_MANUAL_v1.docx`
2. `UI_DETAIL_SPEC_v5.docx`
3. `API_FULL_SPEC_v3.docx`
4. `Firestore_Complete_Schema_v3.docx`

### 7.5 자동화 스크립트 개발

아래 순서로 문서를 본다.

1. `Automation_Script_Spec_v3.docx`
2. `Firestore_Complete_Schema_v3.docx`
3. `API_FULL_SPEC_v3.docx`

## 8. 현재 확인된 충돌 사항

아래 항목은 기준 문서 체계는 확정하되, 실제 구현 전에 추가 정리가 필요한 항목이다.

### 8.1 인증 방식

현 상태:

- 일부 API 문서는 휴대전화 인증 또는 관리자 승인형 간소 인증을 전제로 읽힌다.
- 현재 Flutter 코드는 익명 로그인으로 구현되어 있다.

조치 원칙:
인증 정책은 별도 결정을 통해 확정하고, 확정 전까지는 임시 구현 여부를 명시해야 한다.

### 8.2 Firestore 하위 컬렉션 명칭

현 상태:

- 스키마 문서는 `sentences`, `words` 중심이다.
- 현재 Functions 구현 일부는 `items` 하위 컬렉션을 사용한다.

조치 원칙:
최종 경로 명칭은 `Firestore_Complete_Schema_v3.docx` 기준으로 재정렬한다. 코드가 다르면 코드를 수정 대상으로 본다.

### 8.3 Flutter 구조 문서의 참조 버전

현 상태:

- `08_Flutter_Project_Structure_State_Design_v1.docx`는 UI v4 기준 흔적이 남아 있다.

조치 원칙:
이 문서는 구조 문서로만 사용하고, 화면 동작 판정에는 사용하지 않는다. 추후 v2 문서로 갱신한다.

### 8.4 샘플 데이터와 운영 정책 차이

현 상태:

- 정책상 일반언어 15문장, 선교언어 10문장이다.
- 현재 seed 데이터는 그보다 적다.

조치 원칙:
seed 데이터는 개발용 fixture로 명시하고, 운영 정책을 대체하는 근거로 사용하지 않는다.

## 9. 구현 시 의사결정 규칙

구현 중 문서 해석 충돌이 발생하면 아래 순서로 처리한다.

1. 같은 도메인의 최신 공식 기준 문서를 먼저 확인한다.
2. 다른 도메인 문서와 충돌하면 이 문서의 우선순위 규칙을 따른다.
3. 그래도 충돌이 남으면 "문서 정합성 이슈"로 기록하고 구현을 멈춘다.
4. 임시 우회 구현을 했다면 코드와 작업 기록에 임시임을 명시한다.

## 10. 팀 운영 규칙

앞으로 문서를 수정할 때는 아래 원칙을 따른다.

1. 새 문서가 기존 문서를 대체하면 제목 또는 서문에 대체 대상 문서를 명시한다.
2. 구현 기준 문서에 영향을 주는 변경은 관련 도메인 문서 2개 이상을 함께 갱신한다.
3. 화면 변경은 최소 `UI_DETAIL_SPEC`와 `API` 또는 `Firestore` 영향 여부를 같이 확인한다.
4. 경로/필드 변경은 반드시 `Firestore_Complete_Schema`와 `API_FULL_SPEC`를 동시에 점검한다.
5. Flutter 구조 변경은 `08_Flutter...` 문서를 후속으로 갱신한다.

## 11. 최종 선언

2026-04-18 기준 Mission App 구현의 공식 기준선은 다음과 같다.

- 화면: `UI_DETAIL_SPEC_v5.docx`
- API: `API_FULL_SPEC_v3.docx`
- Firestore: `Firestore_Complete_Schema_v3.docx`
- Flutter 내부 구조: `08_Flutter_Project_Structure_State_Design_v1.docx`
- 운영 정책: `09_ADMIN_MANUAL_v1.docx`
- 자동화: `Automation_Script_Spec_v3.docx`

이 선언 이후 구버전 문서는 직접 구현 기준으로 사용하지 않는다.
