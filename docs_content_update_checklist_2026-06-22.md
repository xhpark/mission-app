# 학습 콘텐츠 추가/제외/변경 체크리스트 (자동화 기준)

작성일: 2026-06-22
적용 범위: `lib/features/learning_content/data/thai_learning_content.dart`(단일 원본) 변경 시
관련 자동화: `scripts/content_pipeline.py`, 스킬 `content-update`, 훅(`thai_learning_content.dart` 편집 감지)

---

## 0. 핵심 구조 요약 (전수 감사 결론)

- **단일 원본**: 모든 학습 콘텐츠는 `thai_learning_content.dart`의 `thaiSentenceContents` / `thaiWordContents` 두 리스트가 유일한 출처다.
- **6개 모드 자동 파생**: 문장은 4개 모드(문장학습/문장테스트/플래시문장학습/플래시문장테스트), 단어는 2개 모드(플래시단어학습/플래시단어테스트)에 `sentencesByCategory()`/`wordsByCategory()`로 자동 반영된다. 모드별 중복 입력 불필요.
- **레벨 무관**: 초급/중급/고급은 콘텐츠를 필터링하지 않는다. 같은 카테고리면 3개 레벨 콘텐츠셋이 동일 내용을 공유한다.
- **콘텐츠 표시 = 번들 Dart**: 앱은 번들된 Dart에서 텍스트를 읽는다. 서버는 매니페스트로 채점·문항수만 담당한다. **Firestore `content_sets`는 매니페스트에 없는 셋의 최종 폴백일 뿐 실사용되지 않는다(F6 무관).**
- **콘텐츠 오디오 = 로컬 에셋**: `audioUrl`은 비고, 앱은 `assets/audio/...` 로컬 파일을 재생한다. Firebase Storage 업로드는 불필요.
- **발음 룩업은 `putIfAbsent`**: 먼저 등록된 토큰이 우선이므로 신규 콘텐츠가 기존 발음 매핑을 덮지 못한다 → 기존 발음 테스트 안전.
- **온디바이스 오디오 캐시는 자동 무효화됨**: `just_audio`는 에셋을 파일 경로로만 캐싱하고 내용 변경을 감지하지 못한다(2026-06-23 발견 — 같은 파일명으로 오디오를 갱신해도 기존 설치 사용자는 캐시된 옛 음성을 계속 들음). `tool/build_content_manifest.dart`가 매니페스트와 함께 `lib/features/learning_content/data/thai_content_version.dart`(소스 해시 상수)를 생성하고, 앱 시작 시 `ContentAudioCacheInvalidator`가 SharedPreferences에 저장된 버전과 비교해 다르면 `just_audio_cache`를 통째로 삭제한다. **콘텐츠 변경 후 `python scripts/content_pipeline.py manifest`만 실행하면 자동으로 처리되므로 별도 수동 단계가 필요 없다.**

## 1. 변경 유형별 영향

| 유형 | 영향 |
|---|---|
| **추가** | 해당 카테고리 세션 길이 증가(상한 없음), distractor 풀 증가, 매니페스트 modeTotals 증가, 신규 오디오 필요, 신규 문장은 연결단어 ≥1 필요 |
| **제외** | 세션 길이 감소, orderNo 연속성 깨짐 주의(반드시 재번호), 연결단어가 가리키던 문장 사라지면 링크 정리 필요, 오디오 파일 정리(선택) |
| **변경** | thaiText/발음 변경 시 매니페스트 expectedText 변경(서버 채점 영향), 오디오 재생성 필요, 발음 토큰 변경 시 룩업 영향 |

## 2. 반드시 지켜야 할 불변식 (계약 테스트가 강제)

`test/learning_content_contract_test.dart`가 검사한다. 위반 시 테스트 실패.

1. **개수 베이스라인 하드코딩** — 8~20줄. 콘텐츠 수가 바뀌면 이 숫자들을 직접 수정해야 한다.
   - `dailySentences.length`, `missionSentences.length`, 합계
   - `dailyWords.length`, `missionWords.length`, 합계
   - 현재값은 `python scripts/content_pipeline.py counts`로 확인.
2. **ID 고유 + orderNo 연속** — 카테고리별 orderNo는 1..N 빈틈 없이 연속. 추가는 끝번호+1, 제외 시 뒤 항목 재번호.
3. **모든 문장은 연결 단어 ≥1개** — 신규 문장마다 같은 카테고리 단어의 `linkedSentenceIds`에 그 문장 ID를 넣어야 한다. 교차 카테고리 링크 금지.
4. **오디오 파일 실제 존재** — `assets/audio/sentence/<THS_id>.mp3`, `assets/audio/word/<THW_id>.mp3`가 실제로 있어야 한다(파일 존재까지 검사).
5. **선택지 안정 ID** — 정답 옵션 ID == 항목 ID (자동 충족, 구조 유지 시).

## 3. 표준 작업 순서 (추가 기준)

```
1) thai_learning_content.dart 편집
   - 문장: thaiSentenceContents에 THS_<C><n> 추가 (id, category, orderNo, koreanText,
     thaiText, phonetic, hangulPronunciation, englishText, hint, related, cultureNote)
   - 단어(Option B): thaiWordContents에 THW_<C><n> 추가 (+ linkedSentenceIds로 신규 문장 연결)
   - audioPath는 비워둔다(자동으로 assets/audio/.../<id>.mp3 로 해석됨)
2) python scripts/content_pipeline.py counts        # 새 개수 확인
3) 계약 테스트 베이스라인 숫자 수정 (위 2-1)
4) python scripts/content_pipeline.py manifest       # 서버 매니페스트 재생성
5) python scripts/content_pipeline.py audio --execute # TTS 생성 + assets로 복사
6) python scripts/content_pipeline.py test            # 계약+드리프트 테스트
7) flutter analyze
8) firebase deploy --only functions                  # 매니페스트가 함수 번들에 포함됨
9) flutter build apk --release  → App Distribution 재배포 (34명이 보려면 필수)
10) git add/commit/push
```

`python scripts/content_pipeline.py`(인자 없음) = 2,4,5(dry),6를 순서대로. `--execute`로 오디오 실제 생성.

## 4. 자동화의 한계 (수동 단계)

- **콘텐츠 작성(1)**: 태국어 표기·발음·뉘앙스는 사람이 작성(원어민 검수 권장).
- **베이스라인 숫자(3)**: 의도된 트립와이어. 사람이 확인 후 수정(자동 변경하지 않음).
- **TTS 음성**: `th-TH-NiwatNeural`(MS Edge 남성 합성음). 진짜 원어민 녹음은 수동 교체.
- **TTS 경로 보정**: `generate_tts_audio.py`는 `dist/audio/audio/{sentences,words}/`(복수)에 생성 → 파이프라인이 `assets/audio/{sentence,word}/`(단수)로 복사한다(스크립트가 처리).
- **재배포(9)**: 콘텐츠·오디오가 앱에 번들되므로 새 APK 배포 필요.

## 5. 검증 게이트

`python scripts/content_pipeline.py check` = 매니페스트 드리프트만 빠르게 확인(`--check`).
`python scripts/content_pipeline.py test` = 계약+드리프트 전체 테스트.
CI 워크플로는 없으므로 로컬에서 반드시 실행한다.
