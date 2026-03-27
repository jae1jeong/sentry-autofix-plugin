---
name: sentry-tdd
description: Use when writing reproduction tests for Sentry bugs. Enforces test-first workflow - write failing test, verify failure, then fix. No production code without a failing test.
---

# Sentry TDD

Sentry 버그 수정을 위한 TDD 원칙. 재현 테스트를 먼저 작성하고, 실패를 확인한 뒤에만 코드를 수정한다.

## Iron Law

```
재현 테스트 없이 코드 수정 금지
테스트 실패를 확인하지 않으면 수정 시작 금지
```

## Red-Green 사이클

```
RED:   재현 테스트 작성 → 실행 → 반드시 실패 확인
GREEN: 최소 범위 코드 수정 → 실행 → 테스트 통과 확인
```

### RED — 재현 테스트 작성

Sentry 이벤트 데이터(스택트레이스, request context, breadcrumbs)를 기반으로 실패하는 테스트를 작성한다.

**규칙:**
- **기존 테스트를 절대 수정하지 않는다** — 기존 테스트의 코드, assertion, import를 변경/삭제 금지
- 새 테스트 파일을 만들거나, 기존 파일에 새 테스트 케이스만 추가한다
- 테스트 이름에 Sentry 이슈 ID를 포함한다
- 실제 코드를 테스트한다 (mock은 불가피할 때만)
- 하나의 버그, 하나의 테스트
- Sentry 이벤트의 실제 입력값을 테스트 데이터로 사용한다

**실패 확인이 필수인 이유:**
테스트가 바로 통과하면 → 버그를 재현하지 못한 것이다. 가설이 잘못되었거나 이미 수정된 버그다.

### GREEN — 최소 수정

테스트를 통과시키기 위한 가장 작은 변경만 수행한다.

**허용:** null guard, 입력 검증, 분기 조건 수정, 예외 처리 보강
**금지:** 구조 변경, migration, 외부 API 변경, "개선"

테스트 통과 후 → 전체 테스트 스위트 확인 → 타입체크 → 린트.

### 검증 실패 시

- 기존 테스트 깨짐 → 코드 변경 롤백 (테스트 파일은 유지)
- 타입체크/린트 실패 → 코드 변경 롤백
- 재현 테스트가 실패하지 않음 → 수정 진행 금지

## 경고 신호

이런 생각이 들면 멈춰라:
- "테스트 실패 확인 안 해도 될 것 같은데" → 확인해라
- "수정부터 하고 테스트 나중에" → 테스트 먼저
- "이건 너무 단순해서 테스트 필요 없어" → 단순한 코드도 깨진다
- "기존 테스트가 커버하니까" → Sentry에서 발견됐으면 커버 안 된 거다
