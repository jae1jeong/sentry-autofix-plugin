# sentry-autofix

Sentry 오류를 TDD 방식으로 자동 수정하고 Draft PR을 생성하는 Claude Code 플러그인.

## 동작 원리

```
Sentry MCP에서 이슈 조회
    ↓
스택트레이스 기반 코드 원인 분석 (서브에이전트)
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

### 방법 1: git clone (추천)

```bash
git clone https://github.com/<owner>/sentry-autofix.git
cd sentry-autofix
./install.sh
```

### 방법 2: 수동 설치

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

## 빠른 시작

### 1. 프로젝트 디렉토리에서 Claude Code 실행

```bash
cd /path/to/your-project   # Sentry 연동된 프로젝트
claude
```

### 2. Sentry 인증 (최초 1회)

첫 실행 시 Sentry MCP가 OAuth 인증을 요청합니다. 브라우저가 자동으로 열리고 Sentry 로그인 후 권한을 승인하면 됩니다.

### 3. 스캔 먼저 해보기

```
/sentry-scan
```

첫 실행 시 인터랙티브 온보딩이 시작됩니다:

**Phase 1: Sentry 연결 확인**

Sentry MCP 연결을 테스트합니다. 연결 실패 시 두 가지 인증 방법을 안내합니다:

| 방법 | 설명 |
|------|------|
| OAuth (권장) | Claude Code 재시작 시 브라우저 인증 자동 진행 |
| Custom Integration 토큰 | Sentry 웹 → Settings → Developer Settings → Custom Integrations에서 토큰 발급 후 settings.json에 등록 |

Custom Integration 토큰 설정 방법:
1. Sentry 웹에서 **Settings → Developer Settings → Custom Integrations** 이동
2. **Create New Integration** → **Internal Integration** 선택
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

**Phase 2: 프로젝트 설정**

```
감지된 프로젝트 유형: Android (Gradle)

== Sentry 설정 ==
1. Sentry 조직 slug (sentryOrg):          ← 필수 입력
2. Sentry 프로젝트 slug (sentryProject):   ← 필수 입력
3. 대상 환경 (environment) [기본: production]:

== 브랜치 설정 ==
4. 기본 브랜치 (baseBranch):              ← 수정의 시작점 + PR 대상
   [감지: main]
   (입력한 브랜치가 존재하는지 git에서 자동 검증)

== 빌드/테스트 설정 ==
5. 테스트 명령 (testCommand) [감지: ./gradlew test]:
6. 린트 명령 (lintCommand) [감지: ./gradlew lint]:
7. 타입체크 명령 (typeCheckCommand) [감지: 없음]:
```

- Sentry URL에서 slug 확인: `https://sentry.io/organizations/{sentryOrg}/issues/?project={sentryProject}`
- 브랜치는 사용자가 입력하면 `git rev-parse --verify`로 존재 여부를 검증, 없으면 재입력 요청
- 설정 완료 후 `.sentry-autofix/state.json` 생성 + `.gitignore` 자동 추가
- 이후 실행에서는 온보딩을 건너뜀. 설정 변경은 `state.json`을 직접 수정

### 4. 특정 이슈 수정

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

### 5. 자동 모드 (선택)

```
/sentry-fix                     # 가장 우선순위 높은 이슈 자동 선택
/loop 12h /sentry-fix           # 하루 2회 자동 실행
```

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

```
/loop 12h /sentry-fix                   # 하루 2회 (로컬, 세션 유지 필요)
/loop 8h /sentry-fix                    # 하루 3회
/loop 24h /sentry-fix                   # 하루 1회
/schedule daily 09:00 /sentry-fix       # 매일 오전 9시 (원격, 컴퓨터 꺼져도 동작)
/schedule "0 9,21 * * *" /sentry-fix    # 매일 오전 9시 + 오후 9시
```

**취소:**
```
/loop                           # 현재 등록된 loop 목록 확인
/loop stop <id>                 # 특정 loop 취소
```

`config.scanInterval`은 연속 실행 방지 가드입니다. 설정 간격보다 짧게 연속 실행되면 자동 스킵합니다.

---

## 설정

첫 실행 시 프로젝트 루트에 `.sentry-autofix/state.json`이 자동 생성됩니다.

### 기본 설정

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `scanInterval` | `"12h"` | 연속 실행 방지 간격 |
| `testCommand` | 자동 감지 | `package.json`의 `scripts.test` |
| `typeCheckCommand` | 자동 감지 | `scripts.typecheck` 또는 `npx tsc --noEmit` |
| `lintCommand` | 자동 감지 | `scripts.lint` |
| `baseBranch` | `"main"` | PR 대상 + 브랜치 시작점 |
| `sentryOrg` | (필수 입력) | Sentry 조직 slug |
| `sentryProject` | (필수 입력) | Sentry 프로젝트 slug |
| `environment` | `"production"` | 이슈 필터링 환경 |

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

### 설정 직접 수정

```bash
# 프로젝트 루트에서
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

```
/mcp                    # MCP 서버 상태 확인
```

Sentry 서버가 목록에 없으면 플러그인이 제대로 설치되지 않은 것입니다. `~/.claude/plugins/local/sentry-autofix/.mcp.json` 파일 존재 여부를 확인하세요.

### 스킬이 안 보임

```bash
# settings.json에서 확인
cat ~/.claude/settings.json | grep sentry
# "sentry-autofix@local": true 가 있어야 함
```

없으면 수동 추가 후 Claude Code 재시작.

### OAuth 브라우저가 안 열림

세션 내에서 직접 시도:
```
! open https://mcp.sentry.dev/mcp
```

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

## 라이선스

MIT
