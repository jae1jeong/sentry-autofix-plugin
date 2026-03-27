# sentry-autofix

**Claude Code 세션만 열어두면, 주말에도 Sentry 오류를 찾아서 고치고 PR을 올려놓는 플러그인.**

```
금요일 퇴근 → Claude Code 세션에서 /loop 12h /sentry-fix → 노트북 열어둠
월요일 출근 → GitHub에 Draft PR이 올라와 있음 → 리뷰만 하면 끝
```

설치 3분, 설정 2분. 나머지는 AI가 알아서 합니다.

---

## 왜 sentry-autofix인가?

- Sentry에 쌓이는 오류를 자동으로 감지하고 우선순위를 매깁니다
- 스택트레이스를 분석해서 원인 코드를 찾습니다
- 재현 테스트를 먼저 작성하고, 실패를 확인한 뒤에만 코드를 수정합니다 (TDD)
- 전체 테스트 + 타입체크 + 린트를 통과해야만 PR을 생성합니다
- Draft PR로만 올리므로 사람이 리뷰하기 전까지 merge되지 않습니다

## 동작 원리

```
Sentry MCP에서 이슈 조회
    ↓
스택트레이스 기반 코드 원인 분석 (서브에이전트)
    ↓
Sentry 이벤트 상세 조회 (request context, breadcrumbs)
    ↓
재현 테스트 작성 → 실패 확인 (TDD Red)
    ↓
최소 범위 코드 수정 → 테스트 통과 확인 (TDD Green)
    ↓
전체 테스트 + 타입체크 + 린트 검증
    ↓
auto/sentry-fix/<issue-id> 브랜치에서 Draft PR 생성
```

모든 수정은 `config.baseBranch` (기본: `main`)에서 브랜치를 생성하고, 해당 브랜치로 Draft PR을 올린다. 자동 merge는 하지 않는다.

---

## 사전 요구사항

| 도구 | 확인 방법 | 설치 |
|------|----------|------|
| Claude Code | `claude --version` | [claude.ai/download](https://claude.ai/download) |
| gh CLI | `gh auth status` | `brew install gh && gh auth login` |
| git | `git --version` | `brew install git` |
| Sentry 계정 | [sentry.io](https://sentry.io) 로그인 | - |

대상 프로젝트 요구사항:
- Sentry에 프로젝트가 연동되어 있고 이슈가 존재
- 테스트를 실행할 수 있는 환경 (자동 감지 또는 수동 설정)

지원 프로젝트 유형:

| 유형 | 감지 기준 | 테스트 | 린트 |
|------|----------|--------|------|
| Android (Gradle) | `build.gradle(.kts)` | `./gradlew test` | `./gradlew lint` |
| Node.js/TypeScript | `package.json` | `scripts.test` | `scripts.lint` |
| Python | `pyproject.toml` / `setup.py` | `pytest` | `ruff` / `flake8` |
| Go | `go.mod` | `go test ./...` | `golangci-lint run` |
| 기타 | - | 수동 설정 | 수동 설정 |

---

## 설치

### 방법 1: Plugin 명령어 (추천)

```
/plugin marketplace add jae1jeong/sentry-autofix-plugin
/plugin install sentry-autofix@sentry-autofix
```

Sentry MCP 등록 후 재시작:
```bash
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### 방법 2: git clone + install script

```bash
git clone https://github.com/jae1jeong/sentry-autofix-plugin.git
cd sentry-autofix-plugin
./install.sh
```

Claude Code 재시작.

### 방법 3: 수동 설치

```bash
# 1. 플러그인 디렉토리에 복사
mkdir -p ~/.claude/plugins/local/sentry-autofix
cp -r .claude-plugin skills .mcp.json ~/.claude/plugins/local/sentry-autofix/

# 2. settings.json에 플러그인 활성화 추가
# "enabledPlugins" 섹션에 아래 추가:
#   "sentry-autofix@local": true

# 3. settings.json에 Sentry MCP 서버 등록
# "mcpServers" 섹션에 아래 추가:
#   "sentry": { "type": "http", "url": "https://mcp.sentry.dev/mcp" }
```

`install.sh`는 위 3단계를 자동으로 수행합니다 (플러그인 복사 + 활성화 + Sentry MCP 등록).

### 설치 후

**Claude Code를 반드시 재시작해야 플러그인이 로드됩니다.**

```bash
# Claude Code 재시작
exit   # 현재 세션 종료
claude # 다시 시작
```

---

## 빠른 시작 (5분)

```bash
# 1. 설치 (택 1)
/plugin marketplace add jae1jeong/sentry-autofix-plugin
/plugin install sentry-autofix@sentry-autofix
# 또는: git clone https://github.com/jae1jeong/sentry-autofix-plugin.git && cd sentry-autofix-plugin && ./install.sh

# 2. Claude Code 재시작 후, 프로젝트에서 실행
cd /path/to/your-project
claude

# 3. 초기 설정 (최초 1회, 2분)
/sentry-setup
```

`/sentry-setup`이 하는 일:
1. **Sentry 연결 확인** — 안 되어 있으면 MCP 등록 + `/mcp`에서 Authenticate 안내
2. **필수 설정 2개** — Sentry 조직 slug + 프로젝트 slug
3. **나머지 자동 감지** — 브랜치, 테스트/린트 명령은 프로젝트에서 감지 (Enter로 넘기면 됨)

설정이 끝나면 바로 사용 가능합니다.

### 특정 이슈 수정

```
/sentry-fix SENTRY-12345
```

이 명령이 수행하는 작업:
1. `main` 브랜치로 이동 + 최신 pull
2. Sentry MCP로 이슈 분석 (서브에이전트)
3. 재현 테스트 작성 → 실패 확인
4. 코드 수정 → 테스트 통과 확인
5. 전체 테스트 + 타입체크 + 린트 검증
6. `auto/sentry-fix/SENTRY-12345` 브랜치 생성
7. Draft PR 생성 → `main` 브랜치로 복귀

### 자동 모드 — 세션만 열어두면 알아서 합니다

```
/loop 12h /sentry-fix           # 하루 2회 자동 실행
```

이 한 줄이면 끝입니다. Claude Code 세션이 열려있는 동안:
- 12시간마다 Sentry에서 새 오류를 확인합니다
- 수정 가능한 이슈를 골라서 재현 테스트 + 수정 + 검증을 수행합니다
- 통과하면 Draft PR을 올려놓습니다
- 실패하면 기록만 남기고 다음 이슈로 넘어갑니다

> **주의:** `/loop`는 세션이 열려있을 때만 동작합니다. 세션을 닫거나 Claude Code를 재시작하면 사라집니다. 3일 후 자동 만료됩니다.
> 세션 없이도 동작하려면 Desktop 스케줄(`/schedule`) 또는 Cloud 스케줄을 사용하세요.
>
> **권한 모드:** 완전 자동 실행을 위해서는 Claude Code가 권한 승인 없이 실행될 수 있어야 합니다. 기본 모드에서는 파일 수정, git push, PR 생성마다 승인을 물어봅니다. `/loop` 설정 전에 Claude Code 권한 설정을 확인하세요.

**금요일 퇴근 전에 설정하고 노트북을 열어두면, 월요일에 PR이 올라와 있습니다.**

---

## 스킬 상세

### /sentry-scan

Sentry에서 미해결 오류를 조회하고 수정 가능성을 평가한다. **코드 수정 없음.**

```
/sentry-scan                    # 전체 스캔
/sentry-scan SENTRY-123         # 특정 이슈만 분석
```

**출력 예시:**

```
## Sentry 스캔 결과 (2026-03-25 09:30)

| 순위 | 이슈 | 제목 | 빈도 | 수정가능성 | 이유 |
|------|------|------|------|-----------|------|
| 1 | SENTRY-123 | TypeError: Cannot read 'id' of null | 847/day | 높음 | null guard 누락 |
| 2 | SENTRY-456 | ValidationError in checkout | 234/day | 중간 | 입력 검증 로직 |
| 3 | SENTRY-789 | TimeoutError: DB query | 12/day | 낮음 | 인프라 이슈 |

스캔 이슈: 15개 / 수정 후보: 3개 / 스킵: 12개
```

**수정 가능성 판단 기준:**

| 조건 | 판정 |
|---|---|
| 스택트레이스 + 소스 파일 존재 | 높음 |
| 스택트레이스만 있음 | 중간 |
| 스택트레이스 없음 / 외부 의존성 | 낮음 |
| DB/인프라/외부 API 오류 | 스킵 |

### /sentry-fix

이슈를 TDD 방식으로 수정하고 Draft PR을 생성한다.

```
/sentry-fix                     # 최우선 이슈 자동 선택
/sentry-fix SENTRY-123          # 특정 이슈 지정
```

**파이프라인 (11단계):**

```
Step 1.  State 로드 (.sentry-autofix/state.json)
Step 2.  이슈 선택 (인자 또는 자동)
Step 3.  사전 검사 (clean 워킹트리, 중복 PR, baseBranch checkout + pull)
Step 4.  분석 (Sentry MCP + 코드베이스 탐색, 서브에이전트)
Step 5.  재현 테스트 작성 (TDD Red)
Step 6.  테스트 실패 확인 (Red Confirm)
Step 7.  코드 수정 (TDD Green, 최소 범위)
Step 8.  검증 (테스트 + 타입체크 + 린트)
Step 9.  Git: 브랜치 생성 → 커밋 → Push → Draft PR
Step 10. Slack 알림 (선택)
Step 11. 실행 로그 저장
```

**브랜치 전략:**

```
main (config.baseBranch)
  ├── auto/sentry-fix/SENTRY-123   ← Draft PR → main
  ├── auto/sentry-fix/SENTRY-456   ← Draft PR → main
  └── auto/sentry-fix/SENTRY-789   ← Draft PR → main
```

- 항상 `config.baseBranch`에서 최신 코드를 pull한 뒤 브랜치를 생성
- 수정 후 `config.baseBranch`로 자동 복귀
- 자동 merge 없음 — 반드시 사람이 리뷰 후 merge

**자동 중단 조건:**

| 상황 | 행동 |
|------|------|
| 워킹 트리에 미커밋 변경 | 전체 중단 |
| 재현 테스트가 실패하지 않음 | 스킵 (버그 재현 불가) |
| 수정 후 기존 테스트 깨짐 | 롤백 + 실패 기록 |
| 변경 파일 5개 초과 | 스킵 (범위 초과) |
| 이미 열린 PR 존재 | 스킵 |
| 2회 연속 실패 | 무시 목록에 추가 |

---

## 예약 실행

스킬 내부에서 실행 주기를 강제하지 않습니다. `/loop` 또는 `/schedule`로 직접 설정합니다.

### `/loop` vs `/schedule` 차이

**`/loop`** — 현재 세션 안에서 도는 타이머. 브라우저 탭 하나 열어둔 것과 비슷.
- 세션 닫으면 사라짐, 3일 후 자동 만료
- 빠르게 테스트할 때 적합

**`/schedule` (Desktop)** — 컴퓨터에 설치되는 백그라운드 작업. macOS launchd / cron과 비슷.
- Claude Code를 안 열어도 컴퓨터만 켜져있으면 실행
- 재시작해도 유지됨

**Cloud 스케줄** — Anthropic 서버에서 실행. GitHub Actions와 비슷.
- 컴퓨터가 꺼져있어도 동작
- 로컬 파일 접근 불가 (매번 fresh clone)

| 방식 | 명령어 | 컴퓨터 필요 | 세션 필요 | 재시작 후 유지 |
|------|--------|-----------|---------|------------|
| `/loop` | `/loop 12h /sentry-fix` | O | O | X (3일 만료) |
| Desktop 스케줄 | `/schedule` | O | X | O |
| Cloud 스케줄 | claude.ai에서 설정 | X | X | O |

```
# /loop (세션 열려있을 때)
/loop 12h /sentry-fix                   # 하루 2회
/loop 8h /sentry-fix                    # 하루 3회

# Desktop 스케줄 (세션 없이, 컴퓨터만 켜져있으면)
/schedule daily 09:00 /sentry-fix       # 매일 오전 9시
/schedule "0 9,21 * * *" /sentry-fix    # 하루 2회 (오전 9시 + 오후 9시)
```

**취소/관리:**
```
# loop
/loop                           # 현재 등록된 loop 목록 확인
/loop stop <id>                 # 특정 loop 취소

# Desktop 스케줄
/schedule                       # 등록된 스케줄 목록
/schedule stop <id>             # 특정 스케줄 취소
```

`config.scanInterval`은 연속 실행 방지 가드입니다. 설정 간격보다 짧게 연속 실행되면 자동 스킵합니다.

---

## 설정

첫 실행 시 프로젝트 루트에 `.sentry-autofix/state.json`이 자동 생성됩니다.

### 기본 설정

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `scanInterval` | `"12h"` | 연속 실행 방지 간격 |
| `testCommand` | 자동 감지 | 프로젝트 유형별 (위 지원 테이블 참고) |
| `typeCheckCommand` | 자동 감지 | 프로젝트 유형별 (없으면 비워둠) |
| `lintCommand` | 자동 감지 | 프로젝트 유형별 (위 지원 테이블 참고) |
| `baseBranch` | `"main"` | PR 대상 + 브랜치 시작점 |
| `sentryOrg` | (필수 입력) | Sentry 조직 slug |
| `sentryProject` | (필수 입력) | Sentry 프로젝트 slug |
| `environment` | `"production"` | 이슈 필터링 환경 |
| `testConvention` | 자동 감지 | 테스트 프레임워크, mock 라이브러리, assertion 스타일, 예시 스니펫 (setup 시 캐싱하여 루프당 토큰 절약) |

### Slack 알림 (선택)

`.sentry-autofix/state.json`의 `config.notifications`를 수정합니다:

```json
{
  "notifications": {
    "enabled": true,
    "slackWebhookUrl": "https://hooks.slack.com/services/T00/B00/xxx",
    "notifyOn": ["pr_created", "failed"]
  }
}
```

| 이벤트 | 메시지 예시 |
|---|---|
| `pr_created` | `[SENTRY-123] Draft PR 생성: https://github.com/.../pull/42` |
| `failed` | `[SENTRY-456] 수정 실패: regression` |
| `skipped` | `[SENTRY-789] 스킵: insufficient_stacktrace` |

Slack Incoming Webhook URL 생성: [api.slack.com/messaging/webhooks](https://api.slack.com/messaging/webhooks)

### 설정 변경

```
/sentry-config                  # 전체 설정 보기 + 수정
/sentry-config baseBranch       # 특정 설정만 변경
```

또는 직접 수정:

```bash
vi .sentry-autofix/state.json
```

`.sentry-autofix/`는 첫 실행 시 `.gitignore`에 자동 추가됩니다.

---

## 생성되는 파일과 브랜치

### 프로젝트에 생성되는 것

| 경로 | 설명 | git 추적 |
|------|------|---------|
| `.sentry-autofix/state.json` | 상태 파일 (처리 이력, 설정) | 자동 .gitignore |
| `.sentry-autofix/logs/*.json` | 실행 로그 | 자동 .gitignore |
| `auto/sentry-fix/*` 브랜치 | 수정 브랜치 (리모트에 push됨) | - |
| Draft PR | GitHub에 생성 | - |

### 커밋 메시지 형식

```
fix: handle null user in checkout flow [SENTRY-123]
```

### PR 본문에 포함되는 내용

- 문제 요약
- Sentry 이슈 링크
- 원인 분석
- 변경 내용
- 추가한 테스트
- 검증 결과 (테스트/타입체크/린트)
- 리스크 및 수동 확인 필요 항목

---

## 수정 범위 제한

### 허용

- 예외 처리 보강
- null/undefined guard 추가
- 입력 검증 로직 수정
- 잘못된 분기 조건 수정
- 타입 가드 또는 경계 조건 수정

### 금지 (자동으로 중단)

- 대규모 구조 변경
- DB migration
- 외부 API 계약 변경
- 배포 설정 변경
- 보안 관련 정책 변경
- 파일 5개 초과 변경

---

## 트러블슈팅

### Sentry MCP 연결 안 됨

```bash
# 1. MCP 서버 등록
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# 2. Claude Code 재시작

# 3. Claude Code 안에서:
/mcp → sentry 선택 → Authenticate 클릭
# 브라우저에서 Sentry OAuth 인증 진행
```

### 스킬이 안 보임

```bash
# settings.json에서 확인
cat ~/.claude/settings.json | grep sentry
# "sentry-autofix@local": true 가 있어야 함
```

없으면 수동 추가 후 Claude Code 재시작.

### OAuth 인증이 안 되는 경우 (Custom Integration 토큰)

OAuth가 동작하지 않으면 토큰을 수동 설정할 수 있습니다:

1. Sentry 웹 → **Settings → Developer Settings → Custom Integrations**
2. **Create New Integration** → **Internal Integration**
3. 권한: Project(Read), Issue & Event(Read), Organization(Read)
4. 생성 후 토큰을 복사하여 `~/.claude/settings.json`에 추가:

```json
{
  "mcpServers": {
    "sentry": {
      "type": "http",
      "url": "https://mcp.sentry.dev/mcp",
      "headers": {
        "Authorization": "Bearer <your-token>"
      }
    }
  }
}
```

5. Claude Code 재시작

### "워킹 트리에 미커밋 변경이 있습니다"

```bash
git stash          # 변경사항 임시 저장
/sentry-fix ...    # 수정 실행
git stash pop      # 변경사항 복원
```

### 특정 이슈를 무시하고 싶음

`.sentry-autofix/state.json`의 `ignored` 배열에 이슈 ID를 추가:

```json
{
  "ignored": ["SENTRY-789", "SENTRY-012"]
}
```

---

## 플러그인 구조

```
sentry-autofix/
├── .claude-plugin/
│   └── plugin.json                 # 플러그인 매니페스트
├── .mcp.json                       # Sentry MCP 원격 서버 등록
├── skills/
│   ├── sentry-scan/
│   │   └── SKILL.md                # 스캔 전용 스킬
│   └── sentry-fix/
│       ├── SKILL.md                # 전체 파이프라인 스킬
│       ├── issue-analyzer-prompt.md # 분석 서브에이전트 프롬프트
│       └── pr-template.md          # PR 본문 템플릿
├── install.sh                      # 원클릭 설치
└── README.md
```

## 알려진 한계

- **실행당 1개 이슈만 처리.** `/sentry-fix`는 한 번에 하나의 이슈만 수정합니다. 여러 이슈는 `/loop`이나 `/schedule`로 반복 실행하여 처리합니다. 코드 충돌 방지를 위해 배치 모드는 지원하지 않습니다.
- **상태 파일이 계속 커짐.** `.sentry-autofix/state.json`에 처리한 이슈가 계속 쌓입니다. PR을 수백 개 올린 뒤에는 파일이 커지고 수동으로 읽기 어려워집니다. 자동 정리 기능은 아직 없으므로 `processed`에서 오래된 항목을 직접 삭제해야 합니다.
- **모든 버그를 고칠 수 있는 건 아닙니다.** 인프라 장애, 외부 API 오류, 데이터 정합성 문제, flaky test는 자동으로 스킵됩니다. 스택트레이스가 명확한 애플리케이션 레벨 버그를 대상으로 합니다.
- **재현 테스트 품질이 일정하지 않음.** AI가 스택트레이스 분석으로 재현 테스트를 작성합니다. 레이스 컨디션, 특정 데이터 상태, 복잡한 사용자 플로우가 필요한 버그는 정확하게 재현하지 못할 수 있습니다.
- **`/loop`는 세션 범위.** 세션을 닫으면 사라지고 3일 후 자동 만료됩니다. 지속적인 자동화는 `/schedule`(Desktop) 또는 Cloud 스케줄을 사용하세요.
- **단일 저장소만 지원.** 크로스 레포 의존성 수정은 지원하지 않습니다.
- **LLM 토큰 비용.** 매 실행마다 분석(서브에이전트), 코드 읽기, 테스트 작성, 수정에 토큰을 소모합니다. 대규모 코드베이스에서 자주 실행하면 비용이 증가합니다.

---

## 주의사항

> **이 플러그인은 AI 보조 도구이며, 사람의 코드 리뷰를 대체하지 않습니다.**
>
> - **Draft PR을 반드시 확인한 뒤 머지하세요.** AI가 생성한 수정은 미묘한 버그를 만들거나, 엣지 케이스를 놓치거나, 비즈니스 로직을 잘못 이해할 수 있습니다.
> - **재현 테스트가 원본 버그를 완전히 커버하지 못할 수 있습니다.** 수정이 증상이 아니라 근본 원인을 해결하는지 직접 확인하세요.
> - **AI는 실수를 합니다.** 잘못된 분석, 부정확한 수정, 결함 있는 테스트 모두 가능합니다. 자동 생성된 PR은 주니어 개발자가 올린 것처럼 꼼꼼히 리뷰하세요.
> - **머지 책임은 본인에게 있습니다.** Draft PR은 승인 없이는 아무것도 배포되지 않도록 하기 위해 존재합니다.
>
> 주의해서 사용하세요.

---

## 크레딧

- TDD 및 검증 스킬(`sentry-tdd`, `sentry-verify`)은 [superpowers](https://github.com/obra/superpowers) 플러그인의 `test-driven-development`, `verification-before-completion` 스킬을 참고하여 Sentry 버그 수정에 맞게 경량화한 버전입니다.

## 라이선스

MIT
