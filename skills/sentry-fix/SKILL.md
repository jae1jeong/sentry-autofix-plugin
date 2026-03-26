---
name: sentry-fix
description: Use when fixing a Sentry error with TDD, auto-fixing production bugs, or creating a draft PR for a Sentry issue. Runs the full pipeline - analyze, reproduce test, fix, verify, draft PR.
---

# Sentry Fix

Sentry 이슈를 TDD 방식으로 자동 수정하고 Draft PR을 생성하는 파이프라인 스킬.

**REQUIRED BACKGROUND:** superpowers:test-driven-development — 재현 테스트 선행 원칙
**REQUIRED BACKGROUND:** superpowers:verification-before-completion — PR 생성 전 증거 기반 검증
**Related:** superpowers:systematic-debugging — 근본 원인 분석이 필요할 때

## Usage

```
/sentry-fix                     # 최우선 이슈 자동 선택
/sentry-fix SENTRY-123          # 특정 이슈 지정
```

## Pipeline

The pipeline has 11 steps. Each step has a hard gate — if a gate fails, the pipeline stops and records the failure reason.

### Step 1: Load State

`.sentry-autofix/state.json`을 읽는다. 파일이 없으면 `/sentry-scan`의 초기화 로직과 동일하게 기본값 생성 + `package.json`에서 config 자동 감지한다.

### Step 2: Issue Selection

**$ARGUMENTS에 이슈 ID가 있는 경우:**
해당 이슈를 직접 사용한다.

**$ARGUMENTS가 비어있는 경우:**
sentry-scan과 동일한 로직으로 Sentry MCP에서 이슈를 조회하고, 우선순위가 가장 높은 1건을 자동 선택한다.

### Step 3: Pre-checks

아래 중 하나라도 해당하면 즉시 중단한다:

| 검사 | 실패 시 |
|------|---------|
| `git status --porcelain`이 비어있지 않음 | 전체 중단. "워킹 트리에 미커밋 변경이 있습니다. 커밋하거나 stash한 뒤 다시 실행하세요." 출력 |
| state.json에서 해당 이슈가 `analyzing` 상태이고 30분 미경과 | 스킵. reason: `already_processing` |
| state.json에서 해당 이슈가 `pr_created` 상태 | 스킵. reason: `pr_exists` |
| state.json에서 해당 이슈가 `failed`이고 retryCount >= 2 | 스킵. `ignored`에 추가. reason: `max_retries` |
| `gh pr list --head auto/sentry-fix/<issue-id>`로 열린 PR 존재 | 스킵. reason: `pr_exists` |
| `lastScanAt`으로부터 `scanInterval` 미경과 (자동 실행 시) | 스킵. "마지막 스캔이 N시간 전" 로그 출력 |

### Step 4: Analysis (Subagent)

Agent 도구로 서브에이전트를 디스패치한다.

```
Agent:
  description: "Analyze Sentry issue"
  subagent_type: general-purpose
  prompt: |
    <issue-analyzer-prompt.md 내용>

    Target issue: <선택된 이슈 ID>
    Sentry org: <config.sentryOrg>
    Sentry project: <config.sentryProject>
```

서브에이전트의 프롬프트는 이 스킬과 같은 디렉토리의 `issue-analyzer-prompt.md`를 Read하여 사용한다.

**Gate:** 서브에이전트가 반환한 JSON의 `confidence`가 `"low"`이고 `skipReason`이 있으면 스킵한다.
state에 기록: `skipped`, reason: skipReason 값.

분석 통과 시 state를 `analyzing`으로 기록한다 (동시 실행 방지 락).

### Step 5: Reproduce Test — Write (TDD Red)

분석 결과의 `hypothesis`, `files`, `testStrategy`, `suggestedTestFile`을 바탕으로 재현 테스트를 작성한다.

**규칙:**
- 기존 테스트 파일이 있으면 (`existingTests`) 해당 파일을 Read하여 스타일과 네이밍 컨벤션을 따른다
- 새 테스트 파일이 필요하면 `suggestedTestFile` 경로에 생성한다
- 테스트는 **현재 버그를 재현해야 한다** — 수정 전에 실패하는 것이 목적이다
- 테스트 이름에 Sentry 이슈 ID를 포함한다. 예: `it('should handle null profile [SENTRY-123]', ...)`

### Step 6: Reproduce Test — Verify Failure (TDD Red Confirm)

```bash
<config.testCommand> -- --testPathPattern="<test-file>" 2>&1
```

**Gate:** 테스트가 **실패해야 한다**.
- 실패하면 → 다음 단계로 진행. state를 `test_written`으로 갱신.
- 통과하면 → 가설이 잘못되었거나 버그가 이미 수정됨. 스킵. reason: `cannot_reproduce`

### Step 7: Fix Code (TDD Green)

분석 결과를 바탕으로 최소 범위 코드 수정을 수행한다.

**허용:**
- 예외 처리 보강
- null/undefined guard 추가
- 입력 검증 로직 수정
- 잘못된 분기 조건 수정
- 타입 가드 또는 경계 조건 수정

**금지:**
- 대규모 구조 변경
- DB migration 추가
- 외부 API 계약 변경
- 배포 설정 변경
- 보안 관련 정책 변경

**Gate:** `git diff --stat`으로 변경 파일 수를 확인한다. 5개 초과 시 중단. reason: `scope_too_large`

state를 `fixed`로 갱신.

### Step 8: Verify (TDD Green Confirm + Full Suite)

순서대로 실행한다:

1. **재현 테스트 통과 확인**
```bash
<config.testCommand> -- --testPathPattern="<test-file>" 2>&1
```
Gate: 통과해야 함

2. **전체 테스트 통과 확인**
```bash
<config.testCommand> 2>&1
```
Gate: 통과해야 함

3. **타입체크** (config.typeCheckCommand가 있으면)
```bash
<config.typeCheckCommand> 2>&1
```
Gate: 통과해야 함

4. **린트** (config.lintCommand가 있으면)
```bash
<config.lintCommand> 2>&1
```
Gate: 통과해야 함

**어느 하나라도 실패 시:**
- `git checkout -- . ':!<test-file>'`으로 코드 변경 롤백 (테스트 파일은 유지)
- state를 `failed`로 갱신, retryCount 증가
- reason: `regression` (기존 테스트 실패) 또는 `verification_failed` (타입체크/린트 실패)
- 중단

### Step 9: Git + Draft PR

1. **브랜치 생성 및 커밋**
```bash
git checkout -b auto/sentry-fix/<issue-id>
git add -A
git commit -m "fix: <분석 결과의 rootCause 요약> [SENTRY-<id>]"
```

2. **Push**
```bash
git push -u origin auto/sentry-fix/<issue-id>
```

3. **Draft PR 생성**

`pr-template.md`를 Read하여 템플릿을 가져오고, 분석 결과와 검증 결과를 채워 넣는다.

```bash
gh pr create --draft \
  --title "fix: <요약> [SENTRY-<id>]" \
  --body "<채워진 PR 템플릿>" \
  --base <config.baseBranch> \
  --head auto/sentry-fix/<issue-id>
```

4. **원래 브랜치로 복귀**
```bash
git checkout <config.baseBranch>
```

state를 `pr_created`로 갱신, `prUrl`과 `branch` 기록.

### Step 10: Notification (Optional)

`config.notifications.enabled`가 `true`이고 현재 이벤트가 `config.notifications.notifyOn`에 포함되면:

```bash
curl -s -X POST "<config.notifications.slackWebhookUrl>" \
  -H "Content-Type: application/json" \
  -d '{"text": "[SENTRY-<id>] Draft PR 생성: <PR URL>"}'
```

`failed` 이벤트일 때:
```bash
curl -s -X POST "<config.notifications.slackWebhookUrl>" \
  -H "Content-Type: application/json" \
  -d '{"text": "[SENTRY-<id>] 수정 실패: <reason>"}'
```

### Step 11: Log

`.sentry-autofix/logs/<ISO-timestamp>.json`에 실행 로그를 저장한다:

```json
{
  "timestamp": "2026-03-25T09:30:00Z",
  "issueId": "SENTRY-123",
  "status": "pr_created",
  "prUrl": "https://github.com/...",
  "analysis": { ... },
  "filesChanged": ["src/checkout/payment.ts"],
  "testsAdded": ["src/__tests__/payment.test.ts"],
  "verificationResults": {
    "reproTest": "pass",
    "fullSuite": "pass",
    "typeCheck": "pass",
    "lint": "pass"
  }
}
```

## Error Recovery

파이프라인 중 어느 지점에서든 실패하면:
1. 코드 변경이 있었으면 `git checkout -- . ':!<test-file>'`으로 롤백 (테스트 파일은 보존)
2. 생성한 브랜치가 있으면 `git branch -D auto/sentry-fix/<issue-id>` (리모트 push 전이면)
3. state.json에 실패 상태와 이유 기록
4. notifications 설정에 따라 Slack 알림
5. 실행 로그 저장

## Stale Lock Detection

state.json에서 `analyzing` 상태인 이슈의 `processedAt`이 30분 이상 경과했으면 stale로 간주하고 해당 이슈의 상태를 초기화한다.
