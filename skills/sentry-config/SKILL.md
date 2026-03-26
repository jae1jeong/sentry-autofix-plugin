---
name: sentry-config
description: Use when changing sentry-autofix settings, updating Sentry project, switching base branch, or modifying test commands. Interactive config editor.
---

# Sentry Config

sentry-autofix 설정을 인터랙티브하게 변경한다.

## Usage

```
/sentry-config                  # 전체 설정 보기 + 수정
/sentry-config baseBranch       # 특정 설정만 변경
```

## Execution Flow

### Step 1: State 확인

`.sentry-autofix/state.json`을 읽는다. 파일이 없으면 "sentry-autofix가 초기화되지 않았습니다. /sentry-scan을 먼저 실행하세요."를 출력하고 중단한다.

### Step 2: 현재 설정 표시

현재 config를 테이블로 보여준다:

```
== 현재 sentry-autofix 설정 ==

| # | 설정 | 값 |
|---|------|-----|
| 1 | sentryOrg | my-org |
| 2 | sentryProject | my-project |
| 3 | environment | production |
| 4 | baseBranch | main |
| 5 | testCommand | ./gradlew test |
| 6 | lintCommand | ./gradlew lint |
| 7 | typeCheckCommand | (없음) |
| 8 | scanInterval | 12h |
| 9 | notifications | 비활성 |

변경할 항목의 번호를 입력하세요 (여러 개: 1,4,8 / 전체: all / 취소: q):
```

### Step 3: 선택 항목 변경

$ARGUMENTS에 특정 설정 키가 있으면 해당 항목만 바로 변경 모드로 진입한다.

변경 시:
- `baseBranch`: `git rev-parse --verify`로 존재 확인. 없으면 유사 브랜치 제안.
- `notifications`: enabled/slackWebhookUrl/notifyOn을 순서대로 질문.
- 나머지: 현재 값을 보여주고 새 값 입력. 빈 값이면 유지.

### Step 4: 저장

변경된 config를 `state.json`에 저장하고 변경 내역을 출력한다:

```
✅ 설정 변경 완료:
  baseBranch: main → develop
  scanInterval: 12h → 8h
```

## Guard Rails

- state.json의 config 섹션만 수정한다. processed/ignored/lastScanAt 등은 건드리지 않는다.
- 코드 수정 금지.
