# Mission App

태국어 학습(문장/단어 학습 및 테스트)과 리포트 제출 흐름을 제공하는 Flutter 앱입니다.

## 핵심 라우트

- `/login`: 임시 개발 로그인
- `/select`: 학습 카테고리/난이도/모드 선택
- `/sentence-learning`, `/sentence-test/*`
- `/flash-word-learning`, `/flash-word-test`
- `/flash-sentence-learning`, `/flash-sentence-test/*`
- `/session-summary` → `/report-preview` → `/report`

## 개발 문서 기준 반영 항목

- 시간 제한 표시(학습/테스트 공통 화면)
- 문장 들어보기 UI(오디오/TTS 연결 포인트)
- 리포트 프리뷰 단계 추가
- Content 데이터 계약 오디오 필드(`audioPath`, `audioUrl`) 반영
- 자동화 스크립트 엔트리 추가 (`/scripts`)

## 로컬 개발

- Flutter 프로젝트 루트: `D:\proj\mission_app`
- Python 자동화 스크립트: `D:\proj\mission_app\scripts`

`flutter` 명령 실행 지침은 배포/환경 설정 문서를 따릅니다.
