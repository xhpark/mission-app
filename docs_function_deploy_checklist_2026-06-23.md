# Cloud Functions 배포 후 체크리스트

작성일: 2026-06-23
배경: `bootstrapUserSession`, `submitOnDeviceSpeakingFallback` 두 함수가 Cloud Run IAM의
`roles/run.invoker: allUsers` 바인딩을 잃어버려 모든 호출이 Cloud Run 레벨 401로 거부된
사고. 우리 코드의 어떤 에러 로그도 안 남고(`Allowing request...` 같은 App Check 로그조차
함수 내부에 도달하기 전이라 안 찍힘), Cloud Run 자체 로그(`The request was not authorized
to invoke this service`)에만 흔적이 남는다.

## 원인

이 프로젝트의 모든 콜러블 함수는 `functions/src/index.ts`의
`setGlobalOptions({ invoker: "public" })`로 "누구나 호출 가능"하게 의도되어 있다(실제 인가는
함수 내부의 Firebase Auth 검증이 담당). 그런데 Cloud Functions v2는 이 `invoker: "public"`
설정을 함수가 **처음 생성(create)**될 때만 Cloud Run IAM에 적용하고, 이미 존재하는 함수의
**코드 업데이트(update) 배포**에서는 재적용하지 않는다. 무슨 이유로든 한 번 IAM이 비워지면
(다른 함수와의 묶음 배포 중 발생한 것으로 추정) 이후 같은 코드를 몇 번 재배포해도 복구되지
않는다.

## 체크리스트

`firebase deploy --only functions...` 실행 후 매번:

```
python scripts/verify_function_invoker_iam.py          # 점검만
python scripts/verify_function_invoker_iam.py --fix     # 누락 시 자동 복구
```

- 전부 `OK`면 정상.
- `MISSING`이 나오면 `--fix`로 복구(다른 함수들과 동일한 `roles/run.invoker: allUsers` 권한을
  부여하는 것뿐, 새로운 권한이 아니다).
- 단순 재배포(update)로는 복구되지 않는다는 점을 기억할 것 — 반드시 IAM을 직접 복구해야 한다.

## 사고 당시 영향 범위

- `bootstrapUserSession`: 앱 로그인/세션 부트스트랩 핵심 함수. 영향 시 로그인 자체가 막힘.
- `submitOnDeviceSpeakingFallback`: 온디바이스(폰 전용) 말하기 평가 결과 저장 함수. 영향 시
  "온디바이스 결과 저장에 실패했습니다" 메시지로만 나타나고, 클라이언트 코드가 실제 예외를
  버리므로(`catch (_)`) 원인 파악에 서버 로그 직접 조회가 필요했다.
