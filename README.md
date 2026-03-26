# sentry-autofix

Sentry 오류를 TDD 방식으로 자동 수정하고 Draft PR을 생성하는 Claude Code 플러그인.

## Install

```bash
git clone <repo-url> && cd sentry-autofix
./install.sh
```

Restart Claude Code after install. Sentry OAuth runs on first use.

## Skills

### /sentry-scan

Sentry에서 미해결 오류를 조회하고 수정 가능성을 평가한다.

```
/sentry-scan                # 전체 스캔
/sentry-scan SENTRY-123     # 특정 이슈 분석
```

### /sentry-fix

이슈 분석 → 재현 테스트 작성 → 코드 수정 → 검증 → Draft PR 생성.

```
/sentry-fix                 # 최우선 이슈 자동 선택
/sentry-fix SENTRY-123      # 특정 이슈 지정
```

## Scheduling

```
/loop 12h /sentry-fix       # 하루 2회
/loop 8h /sentry-fix        # 하루 3회
/schedule daily 09:00 /sentry-fix  # 매일 오전 9시 (원격)
```

## Configuration

첫 실행 시 `.sentry-autofix/state.json`이 자동 생성된다. `config` 섹션을 수정하여 설정을 변경한다.

| 설정 | 기본값 | 설명 |
|------|--------|------|
| scanInterval | 12h | 연속 실행 방지 간격 |
| testCommand | auto-detect | 테스트 실행 명령 |
| typeCheckCommand | auto-detect | 타입체크 명령 |
| lintCommand | auto-detect | 린트 명령 |
| baseBranch | main | PR 대상 브랜치 |
| sentryOrg | (required) | Sentry 조직 slug |
| sentryProject | (required) | Sentry 프로젝트 slug |
| environment | production | 대상 환경 |

### Slack Notifications

```json
{
  "notifications": {
    "enabled": true,
    "slackWebhookUrl": "https://hooks.slack.com/services/...",
    "notifyOn": ["pr_created", "failed"]
  }
}
```

## How It Works

1. **Scan** — Sentry MCP로 프로덕션 오류 조회
2. **Analyze** — 스택트레이스 기반 코드 원인 분석
3. **Test** — 재현 테스트 작성, 실패 확인 (TDD Red)
4. **Fix** — 최소 범위 수정, 테스트 통과 확인 (TDD Green)
5. **Verify** — 전체 테스트 + 타입체크 + 린트
6. **PR** — Draft PR 생성 with evidence

## Requirements

- Claude Code
- gh CLI (authenticated)
- git
- Sentry account
