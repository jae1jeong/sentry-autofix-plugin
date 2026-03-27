---
name: sentry-verify
description: Use before creating a PR or claiming a Sentry fix is complete. Runs all verification commands and requires evidence before any success claim.
---

# Sentry Verify

PR 생성이나 수정 완료 선언 전에 모든 검증을 실행하고, 증거 없이 성공을 주장하지 않는다.

## Iron Law

```
검증 명령을 실행하지 않고 "통과"라고 말하지 않는다
"아마 될 거야"는 검증이 아니다
```

## 검증 체크리스트

PR 생성 전 아래를 순서대로 실행하고, 각 단계의 실제 출력을 확인한다:

```
1. 재현 테스트 통과     → 해당 테스트 파일만 실행, 출력 확인
2. 전체 테스트 통과     → config.testCommand 실행, 출력 확인
3. 타입체크 통과        → config.typeCheckCommand 실행 (있으면), 출력 확인
4. 린트 통과           → config.lintCommand 실행 (있으면), 출력 확인
```

## 증거 기반 판단

| 주장 | 필요한 증거 | 불충분 |
|------|-----------|--------|
| "테스트 통과" | 테스트 명령 출력: 0 failures | 이전 실행, "될 거야" |
| "타입체크 통과" | 타입체크 명령 출력: exit 0 | 린트만 통과 |
| "버그 수정됨" | 재현 테스트 통과 + 전체 스위트 통과 | 코드만 변경 |
| "regression 없음" | 전체 테스트 스위트 0 failures | 재현 테스트만 통과 |

## 실패 시 행동

하나라도 실패하면:
1. 코드 변경 롤백 (테스트 파일은 유지)
2. state.json에 실패 상태와 이유 기록
3. PR 생성하지 않음

**절대 하지 말 것:**
- 실패한 검증을 무시하고 PR 생성
- "나중에 고치면 되지" — 지금 고치거나 중단
- 부분 검증으로 통과 판정 — 전체를 실행해야 함

## 경고 신호

- "아마 통과할 거야" → 실행해라
- "린트만 통과했으니까" → 린트 ≠ 테스트 ≠ 타입체크
- "이전에 통과했으니까" → 지금 다시 실행해라
- "빨리 PR 올리고 싶어" → 검증이 먼저
