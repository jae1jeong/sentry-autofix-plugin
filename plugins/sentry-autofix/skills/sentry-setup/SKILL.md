---
name: sentry-setup
description: Use when first setting up sentry-autofix in a project, connecting to Sentry, or running initial configuration. Run this before using /sentry-scan or /sentry-fix.
---

# Sentry Setup

프로젝트에서 sentry-autofix를 처음 사용하기 위한 초기 설정. Sentry 연결 확인 + 프로젝트 설정을 진행한다.

## Usage

```
/sentry-setup
```

## Execution Flow

### Step 1: 이미 설정되어 있는지 확인

`.sentry-autofix/state.json`이 존재하면:
```
이미 설정되어 있습니다. 설정을 변경하려면 /sentry-config를 사용하세요.
현재 설정: sentryOrg=<값>, sentryProject=<값>, baseBranch=<값>
```
를 출력하고 종료한다.

### Step 2: Sentry 연결 확인

Sentry MCP 도구를 호출하여 연결을 테스트한다.

**연결 성공 시:**
```
✅ Sentry 연결 완료
```
→ Step 3으로 진행.

**연결 실패 시:**

아래 순서로 안내한다:

```
❌ Sentry에 연결할 수 없습니다.

아래 단계를 따라주세요:

1. MCP 서버 등록 (최초 1회):
   터미널에서 실행: claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

2. Claude Code 재시작

3. /mcp 입력 → sentry 선택 → Authenticate 클릭
   (브라우저에서 Sentry OAuth 인증이 진행됩니다)

4. 인증 완료 후 다시 /sentry-setup 실행
```
→ 여기서 중단한다.

### Step 3: 프로젝트 유형 감지

프로젝트 루트에서 빌드 파일을 확인하여 유형을 자동 감지한다:

| 감지 기준 | 유형 | testCommand | lintCommand |
|---|---|---|---|
| `build.gradle` 또는 `build.gradle.kts` | Android | `./gradlew test` | `./gradlew lint` |
| `package.json` | Node.js | scripts.test | scripts.lint |
| `pyproject.toml` 또는 `setup.py` | Python | `pytest` | `ruff check .` |
| `go.mod` | Go | `go test ./...` | `golangci-lint run` |
| 해당 없음 | 기타 | 사용자 입력 | 사용자 입력 |

### Step 3.5: 테스트 컨벤션 감지

프로젝트의 테스트 라이브러리와 코딩 스타일을 감지하여 `testConvention`에 저장한다. 이 정보는 `/sentry-fix` 루프에서 매번 기존 테스트를 읽지 않고도 올바른 스타일로 재현 테스트를 작성할 수 있게 한다.

**1. 프레임워크 감지**

프로젝트 유형별로 의존성 파일에서 테스트 프레임워크를 감지한다:

| 유형 | 감지 파일 | 감지 대상 |
|---|---|---|
| Android | `build.gradle(.kts)` | JUnit4(`junit:junit`), JUnit5(`org.junit.jupiter`), Kotest(`io.kotest`) |
| Android (mock) | `build.gradle(.kts)` | Mockito(`org.mockito`), MockK(`io.mockk`) |
| Node.js | `package.json` devDependencies | jest, vitest, mocha, @testing-library/* |
| Python | `pyproject.toml`, `requirements*.txt` | pytest, unittest(내장), pytest-mock |
| Go | — | testing(내장), testify(`github.com/stretchr/testify`) |

감지 결과를 `testConvention.framework`, `testConvention.mockLibrary`에 저장한다.

**2. 스니펫 추출**

Glob으로 프로젝트의 테스트 파일을 탐색한다:
- Android: `**/src/test/**/*Test.kt`, `**/src/test/**/*Test.java`
- Node.js: `**/*.test.{ts,js,tsx,jsx}`, `**/*.spec.{ts,js,tsx,jsx}`, `**/__tests__/**`
- Python: `**/test_*.py`, `**/*_test.py`
- Go: `**/*_test.go`

찾은 테스트 파일 중 **가장 최근 수정된 1개**를 Read한다 (50줄 이하). 이 파일에서:
- import 문
- 테스트 함수/메서드 1개 전체 (setup ~ assertion)
- assertion 스타일 (`assertThat`, `assertEquals`, `expect`, `assert` 등)

을 추출하여 `testConvention.exampleSnippet`에 저장한다.

`testConvention.assertionStyle`은 스니펫에서 가장 많이 사용된 assertion 패턴으로 설정한다.

**3. 테스트 파일이 0개인 경우**

테스트 파일을 찾을 수 없으면:
- `testConvention.framework`와 `testConvention.mockLibrary`는 의존성 파일 기반으로 설정
- `testConvention.exampleSnippet`은 `null`로 설정
- `testConvention.assertionStyle`은 프레임워크 기본값 사용 (JUnit5: `assertEquals`, pytest: `assert`, Jest: `expect` 등)

### Step 4: 필수 설정 입력

```
감지된 프로젝트: Android (Gradle)

== 필수 ==
Sentry 조직 slug: ___
  (URL에서 확인: https://sentry.io/organizations/{여기}/...)

Sentry 프로젝트 slug: ___
  (URL에서 확인: ...issues/?project={여기})

기본 브랜치: ___ [감지: main]
  (수정 브랜치의 시작점이자 PR 대상)
```

- `baseBranch`는 `git symbolic-ref refs/remotes/origin/HEAD`로 자동 감지
- 사용자가 입력한 브랜치는 `git rev-parse --verify`로 존재 확인
- 존재하지 않으면 `git branch -a`에서 유사 브랜치를 검색하여 "혹시 이 브랜치를 의미하셨나요?" 제안

### Step 5: 자동 감지 확인

```
== 자동 감지 (Enter로 기본값 사용) ==
테스트 명령: ./gradlew test
린트 명령: ./gradlew lint
타입체크 명령: (없음)
대상 환경: production

맞으면 Enter, 변경하려면 값을 입력하세요.
```

각 항목에서 Enter를 누르면 감지된 기본값을 사용한다.

### Step 6: 저장 및 완료

1. `.sentry-autofix/` 디렉토리 생성
2. `state.json` 저장
3. `.gitignore`에 `.sentry-autofix/`가 없으면 자동 추가
4. 완료 메시지 출력:

```
✅ 설정 완료!

다음 명령어를 사용할 수 있습니다:
  /sentry-scan              Sentry 오류 조회 + 우선순위 리포트
  /sentry-fix SENTRY-123    특정 이슈 TDD 수정 + Draft PR
  /sentry-fix               최우선 이슈 자동 선택 + 수정
  /loop 12h /sentry-fix     하루 2회 자동 실행

설정 변경: /sentry-config
```
