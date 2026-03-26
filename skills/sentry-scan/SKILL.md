---
name: sentry-scan
description: Use when checking Sentry for new errors, triaging production issues, or asking "what's broken in prod". Scans unresolved/regression issues and reports fixability.
---

# Sentry Scan

Sentry MCP를 통해 프로덕션 오류를 조회하고, 수정 가능성을 평가하여 우선순위 리포트를 출력한다. 코드 수정 없음.

## Usage

```
/sentry-scan                    # 전체 스캔
/sentry-scan SENTRY-123         # 특정 이슈만 분석
```

## Execution Flow

### Step 1: State 로드

`.sentry-autofix/state.json`을 읽는다. 파일이 없으면 아래 기본값으로 초기화한다.

```json
{
  "lastScanAt": null,
  "processed": {},
  "ignored": [],
  "config": {
    "scanInterval": "12h",
    "testCommand": "",
    "typeCheckCommand": "",
    "lintCommand": "",
    "baseBranch": "main",
    "sentryOrg": "",
    "sentryProject": "",
    "environment": "production",
    "notifications": {
      "enabled": false,
      "slackWebhookUrl": "",
      "notifyOn": ["pr_created", "failed"]
    }
  }
}
```

초기화 시 프로젝트 유형을 자동 감지하여 config에 채운다:

| 프로젝트 유형 | 감지 기준 | testCommand | lintCommand | typeCheckCommand |
|---|---|---|---|---|
| Android (Gradle) | `build.gradle` 또는 `build.gradle.kts` 존재 | `./gradlew test` | `./gradlew lint` | - |
| Node.js | `package.json` 존재 | `scripts.test` | `scripts.lint` | `scripts.typecheck` 또는 `npx tsc --noEmit` |
| Python | `pyproject.toml` 또는 `setup.py` 존재 | `pytest` | `ruff check .` 또는 `flake8` | `mypy .` |
| Go | `go.mod` 존재 | `go test ./...` | `golangci-lint run` | `go vet ./...` |
| 기타 | 위에 해당 없음 | 사용자에게 입력 요청 | 사용자에게 입력 요청 | 사용자에게 입력 요청 |

### 첫 실행 시 인터랙티브 초기화

`.sentry-autofix/state.json`이 존재하지 않으면 온보딩 흐름을 시작한다.

#### Phase 1: Sentry 연결 확인

Sentry MCP 연결을 테스트한다. 연결이 안 되면 두 가지 방법을 안내한다:

```
Sentry 연결을 확인합니다...

[연결 성공 시]
✅ Sentry MCP 연결 완료 (OAuth 인증됨)

[연결 실패 시]
❌ Sentry MCP에 연결할 수 없습니다.

Sentry 인증 방법 2가지:

방법 1: OAuth (권장)
  Claude Code를 재시작하면 Sentry MCP가 자동으로 OAuth 브라우저 인증을 요청합니다.

방법 2: Custom Integration 토큰
  1. Sentry 웹에서 Settings → Developer Settings → Custom Integrations 이동
  2. "Create New Integration" → Internal Integration 선택
  3. 권한 설정:
     - Project: Read
     - Issue & Event: Read
     - Organization: Read
  4. 생성 후 표시되는 토큰을 복사
  5. Claude Code settings.json의 mcpServers.sentry에 헤더 추가:
     {
       "type": "http",
       "url": "https://mcp.sentry.dev/mcp",
       "headers": {
         "Authorization": "Bearer <your-token>"
       }
     }
  6. Claude Code 재시작 후 다시 /sentry-scan 실행
```

연결 실패 시 여기서 중단한다. 연결 성공 시 Phase 2로 진행.

#### Phase 2: 프로젝트 설정

자동 감지 결과를 보여주고 사용자에게 확인/수정을 요청한다:

```
감지된 프로젝트 유형: Android (Gradle)

== Sentry 설정 ==
1. Sentry 조직 slug (sentryOrg):
2. Sentry 프로젝트 slug (sentryProject):
3. 대상 환경 (environment) [기본: production]:

== 브랜치 설정 ==
4. 기본 브랜치 (baseBranch) — 수정 브랜치의 시작점이자 PR 대상:
   [감지: main]

== 빌드/테스트 설정 ==
5. 테스트 명령 (testCommand) [감지: ./gradlew test]:
6. 린트 명령 (lintCommand) [감지: ./gradlew lint]:
7. 타입체크 명령 (typeCheckCommand) [감지: 없음]:
```

- Sentry 조직/프로젝트 slug는 URL에서 확인 가능: `https://sentry.io/organizations/{sentryOrg}/issues/?project={sentryProject}`
- `baseBranch`는 `git symbolic-ref refs/remotes/origin/HEAD`로 자동 감지를 시도한다
- 사용자가 브랜치명을 입력하면 `git rev-parse --verify <branch>`로 존재 여부를 확인한다
- 존재하지 않는 브랜치를 입력하면 "해당 브랜치가 존재하지 않습니다. 다시 입력해주세요."를 출력하고 재입력을 요청한다
- 각 항목에서 사용자가 빈 값을 입력하면 감지된 기본값을 사용한다
- 설정 완료 후 `state.json`을 저장한다
- `.gitignore`에 `.sentry-autofix/`가 없으면 자동으로 추가한다 (`.gitignore` 파일이 없으면 생성)
- 이후 실행에서는 초기화를 건너뛴다. 설정 변경은 `state.json`을 직접 수정한다.

### Step 2: Sentry 이슈 조회

$ARGUMENTS에 특정 이슈 ID가 있으면 해당 이슈만 조회한다.

없으면 Sentry MCP를 통해 이슈 목록을 조회한다:
- 필터: `is:unresolved`, environment=`config.environment`
- regression 이슈 포함

Sentry MCP 도구를 사용한다. 사용 가능한 도구는 MCP 연결 후 확인한다.

### Step 3: 후보 필터링

state.json의 `processed`와 `ignored`에 이미 있는 이슈를 제외한다.

### Step 4: 수정 가능성 평가

각 이슈에 대해 규칙 기반으로 평가한다:

| 조건 | 판정 |
|---|---|
| 스택트레이스 있음 + 오류 파일이 저장소에 존재 | **높음** |
| 스택트레이스 있음 + 파일 매칭 불확실 | **중간** |
| 스택트레이스 없음 또는 외부 의존성 오류 | **낮음** |
| DB/인프라/외부 API 관련 오류 (TimeoutError, ConnectionError 등) | **스킵** |

파일 존재 여부는 스택트레이스의 파일 경로를 Glob으로 확인한다.

### Step 5: 우선순위 정렬 및 출력

정렬 순서: regression > 발생 빈도 높은 순 > 최근 발생 순

아래 형식으로 출력한다:

```
## Sentry 스캔 결과 (YYYY-MM-DD HH:mm)

| 순위 | 이슈 | 제목 | 빈도 | 수정가능성 | 이유 |
|------|------|------|------|-----------|------|
| 1 | SENTRY-123 | TypeError: Cannot read 'id' of null | 847/day | 높음 | null guard 누락, 스택트레이스 명확 |
| ... | | | | | |

스캔 이슈: N개 / 수정 후보: N개 / 스킵: N개
```

### Step 6: State 갱신

`state.json`의 `lastScanAt`을 현재 시각으로 갱신하고 저장한다.

## Guard Rails

- **코드 수정 금지**: 이 스킬은 읽기 전용이다. Edit, Write 도구를 state.json 외에 사용하지 않는다.
- **Sentry MCP 인증 실패 시**: OAuth 재인증이 필요하다는 안내를 출력하고 중단한다.
