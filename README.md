# sentry-autofix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Leave your Claude Code session open — it finds Sentry errors, writes reproduction tests, fixes the code, and opens Draft PRs. Even on weekends.**

[한국어](./README.ko.md)

```
Friday evening  → /loop 12h /sentry-fix → leave laptop open
Monday morning  → Draft PRs waiting on GitHub → just review and merge
```

3 min to install. 2 min to set up. AI handles the rest.

---

## Why sentry-autofix?

- Automatically detects and prioritizes unresolved Sentry errors
- Analyzes stacktraces to locate root cause in your codebase
- Writes reproduction tests first, verifies they fail, then fixes (TDD)
- Only creates a PR after all tests + type check + lint pass
- Always Draft PR — nothing merges without human review

## How It Works

```
Fetch issues via Sentry MCP
    ↓
Analyze root cause from stacktrace (subagent)
    ↓
Fetch event details (request context, breadcrumbs)
    ↓
Write reproduction test → verify it fails (TDD Red)
    ↓
Minimal code fix → verify test passes (TDD Green)
    ↓
Run full test suite + type check + lint
    ↓
Create Draft PR on auto/sentry-fix/<issue-id> branch
```

All fixes branch from `config.baseBranch` (default: `main`) and open a Draft PR back to it. No auto-merge.

---

## Prerequisites

| Tool | Check | Install |
|------|-------|---------|
| Claude Code | `claude --version` | [claude.ai/download](https://claude.ai/download) |
| gh CLI | `gh auth status` | `brew install gh && gh auth login` |
| git | `git --version` | `brew install git` |
| Sentry account | [sentry.io](https://sentry.io) | - |

**Supported project types:**

| Type | Detection | Test | Lint |
|------|-----------|------|------|
| Android (Gradle) | `build.gradle(.kts)` | `./gradlew test` | `./gradlew lint` |
| Node.js/TypeScript | `package.json` | `scripts.test` | `scripts.lint` |
| Python | `pyproject.toml` / `setup.py` | `pytest` | `ruff` / `flake8` |
| Go | `go.mod` | `go test ./...` | `golangci-lint run` |
| Other | — | manual config | manual config |

---

## Installation

### Option 1: Plugin command (recommended)

```
/plugin marketplace add jae1jeong/sentry-autofix-plugin
/plugin install sentry-autofix@sentry-autofix
```

Then register Sentry MCP and restart:
```bash
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

### Option 2: Clone + install script

```bash
git clone https://github.com/jae1jeong/sentry-autofix-plugin.git
cd sentry-autofix-plugin
./install.sh
```

Restart Claude Code.

<details>
<summary>Manual installation</summary>

```bash
# 1. Copy plugin files
mkdir -p ~/.claude/plugins/local/sentry-autofix
cp -r .claude-plugin skills .mcp.json ~/.claude/plugins/local/sentry-autofix/

# 2. Register Sentry MCP
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# 3. Enable plugin in settings.json
#   "enabledPlugins": { "sentry-autofix@local": true }
```

</details>

---

## Quick Start (5 min)

```bash
# 1. Install (choose one)
/plugin marketplace add jae1jeong/sentry-autofix-plugin
/plugin install sentry-autofix@sentry-autofix
# or: git clone https://github.com/jae1jeong/sentry-autofix-plugin.git && cd sentry-autofix-plugin && ./install.sh

# 2. Restart Claude Code, then open your project
cd /path/to/your-project
claude

# 3. Initial setup (one-time, ~2 min)
/sentry-setup
```

`/sentry-setup` will:
1. **Verify Sentry connection** — registers MCP + guides you through `/mcp` → Authenticate
2. **Ask 2 required settings** — Sentry org slug + project slug
3. **Auto-detect the rest** — base branch, test/lint commands (press Enter to accept defaults)

### Fix a specific issue

```
/sentry-fix SENTRY-12345
```

This will:
1. Checkout `main` + pull latest
2. Analyze the issue via Sentry MCP (subagent)
3. Write reproduction test → verify failure
4. Fix code → verify test passes
5. Run full test suite + type check + lint
6. Create `auto/sentry-fix/SENTRY-12345` branch
7. Open Draft PR → return to `main`

### Auto mode — leave the session open

```
/loop 12h /sentry-fix
```

While the Claude Code session is open:
- Checks Sentry for new errors every 12 hours
- Picks the most fixable issue, runs TDD pipeline
- Opens Draft PR on success, logs and moves on if it fails

> **Note:** `/loop` only works while the session is open. It disappears when you close the session and auto-expires after 3 days.
> For session-independent scheduling, use Desktop schedule (`/schedule`) or Cloud schedule.
>
> **Permission mode:** For fully unattended auto mode, Claude Code needs to run without permission prompts. Otherwise it will pause and wait for approval on every file edit, git push, and PR creation. Check your Claude Code permission settings before setting up `/loop`.

**Set it up Friday before you leave. PRs will be waiting Monday morning.**

---

## Skills

| Skill | Description |
|-------|-------------|
| `/sentry-setup` | One-time onboarding (Sentry auth + project config) |
| `/sentry-scan` | Scan Sentry for unresolved errors, report fixability (read-only) |
| `/sentry-fix` | Full TDD pipeline: analyze → test → fix → verify → Draft PR |
| `/sentry-config` | Change settings interactively |

---

## Scheduling

### `/loop` vs `/schedule`

**`/loop`** — In-session timer. Like keeping a browser tab open.
- Disappears when session closes. Expires after 3 days.
- Best for quick testing.

**`/schedule` (Desktop)** — Background job on your machine. Like macOS launchd / cron.
- Runs without Claude Code open. Persists across restarts.
- Requires computer to be on.

**Cloud schedule** — Runs on Anthropic servers. Like GitHub Actions.
- Works even when your computer is off.
- No local file access (fresh clone each run).

| Method | Command | Computer needed | Session needed | Survives restart |
|--------|---------|----------------|----------------|-----------------|
| `/loop` | `/loop 12h /sentry-fix` | Yes | Yes | No (3-day expiry) |
| Desktop | `/schedule` | Yes | No | Yes |
| Cloud | Set up on claude.ai | No | No | Yes |

```bash
# /loop (session must be open)
/loop 12h /sentry-fix

# Desktop schedule (computer on, no session needed)
/schedule daily 09:00 /sentry-fix
/schedule "0 9,21 * * *" /sentry-fix    # twice daily
```

**Cancel:**
```bash
# loop
/loop                    # list active loops
/loop stop <id>          # cancel

# Desktop schedule
/schedule                # list schedules
/schedule stop <id>      # cancel
```

---

## Configuration

`/sentry-setup` creates `.sentry-autofix/state.json` on first run. Change settings with `/sentry-config` or edit the file directly.

| Setting | Default | Description |
|---------|---------|-------------|
| `scanInterval` | `"12h"` | Minimum interval between runs |
| `testCommand` | auto-detect | Per project type |
| `typeCheckCommand` | auto-detect | Per project type |
| `lintCommand` | auto-detect | Per project type |
| `baseBranch` | `"main"` | PR target + branch start point |
| `sentryOrg` | (required) | Sentry organization slug |
| `sentryProject` | (required) | Sentry project slug |
| `environment` | `"production"` | Issue filter environment |
| `testConvention` | auto-detect | Test framework, mock library, assertion style, and example snippet (cached at setup to save tokens per loop) |

### Slack Notifications (optional)

```json
{
  "notifications": {
    "enabled": true,
    "slackWebhookUrl": "https://hooks.slack.com/services/T00/B00/xxx",
    "notifyOn": ["pr_created", "failed"]
  }
}
```

| Event | Message |
|-------|---------|
| `pr_created` | `[SENTRY-123] Draft PR created: https://github.com/.../pull/42` |
| `failed` | `[SENTRY-456] Fix failed: regression` |

`.sentry-autofix/` is automatically added to `.gitignore` on first run.

---

## Safety

### Allowed fixes

- Exception handling
- Null/undefined guards
- Input validation
- Branch condition fixes
- Type guards / boundary conditions

### Auto-stopped (never attempted)

- Large structural changes
- DB migrations
- External API contract changes
- Deploy config changes
- Security policy changes
- Changes touching 5+ files

### Auto-stop conditions

| Condition | Action |
|-----------|--------|
| Uncommitted changes in working tree | Full stop |
| Reproduction test doesn't fail | Skip (can't reproduce) |
| Existing tests break after fix | Rollback + record failure |
| 5+ files changed | Skip (scope too large) |
| Open PR already exists | Skip |
| 2 consecutive failures | Add to ignore list |

---

## Troubleshooting

### Sentry MCP not connected

```bash
# 1. Register MCP server
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# 2. Restart Claude Code

# 3. Inside Claude Code:
/mcp → select sentry → click Authenticate
# Browser opens for Sentry OAuth
```

### Skills not showing up

```bash
cat ~/.claude/settings.json | grep sentry
# Should see: "sentry-autofix@local": true
```

If missing, add manually and restart Claude Code.

### OAuth not working (Custom Integration token)

1. Sentry web → **Settings → Developer Settings → Custom Integrations**
2. **Create New Integration** → **Internal Integration**
3. Permissions: Project(Read), Issue & Event(Read), Organization(Read)
4. Copy token and add to `~/.claude/settings.json`:

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

### Uncommitted changes error

```bash
git stash && /sentry-fix SENTRY-123 && git stash pop
```

### Ignore specific issues

Add issue IDs to `.sentry-autofix/state.json`:

```json
{
  "ignored": ["SENTRY-789", "SENTRY-012"]
}
```

---

## Plugin Structure

```
sentry-autofix/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace catalog
├── .mcp.json                    # Sentry MCP remote server
├── skills/
│   ├── sentry-setup/SKILL.md    # Onboarding
│   ├── sentry-scan/SKILL.md     # Scan only
│   ├── sentry-fix/              # Full pipeline
│   │   ├── SKILL.md
│   │   ├── issue-analyzer-prompt.md
│   │   └── pr-template.md
│   ├── sentry-config/SKILL.md   # Config editor
│   ├── sentry-tdd/SKILL.md      # TDD principles
│   └── sentry-verify/SKILL.md   # Verification principles
├── install.sh
├── README.md
└── README.ko.md
```

## Known Limitations

- **One issue per run.** `/sentry-fix` processes a single issue per execution. Use `/loop` or `/schedule` to process more over time. Batch mode is not supported to avoid code conflicts between fixes.
- **State file grows over time.** `.sentry-autofix/state.json` accumulates entries for every processed issue. After hundreds of PRs, the file becomes large and hard to read manually. There is no built-in cleanup yet — you can delete old entries from `processed` manually.
- **Not all bugs are fixable.** Infrastructure issues, external API failures, data integrity problems, and flaky tests are automatically skipped. The plugin targets application-level bugs with clear stacktraces.
- **Reproduction test quality varies.** The AI writes reproduction tests based on stacktrace analysis. Complex bugs involving race conditions, specific data states, or multi-step user flows may not be accurately reproduced.
- **`/loop` is session-scoped.** It stops when you close the session and expires after 3 days. For persistent automation, use `/schedule` (Desktop) or Cloud scheduling.
- **Single repo only.** Cross-repo dependency fixes are not supported.
- **LLM token costs.** Each `/sentry-fix` run uses tokens for analysis (subagent), code reading, test writing, and fixing. Frequent runs on large codebases will consume more tokens.

---

## Disclaimer

> **This plugin is an AI assistant, not a replacement for human code review.**
>
> - **Always review Draft PRs before merging.** AI-generated fixes may introduce subtle bugs, miss edge cases, or misunderstand business logic.
> - **The reproduction test may not fully cover the original bug.** Verify that the fix actually addresses the root cause, not just the symptom.
> - **AI can make mistakes.** Wrong analysis, incorrect fixes, and flawed tests are all possible. Treat every auto-generated PR as if a junior developer wrote it — review thoroughly.
> - **You are responsible for what gets merged.** Draft PRs exist specifically so nothing ships without your approval.
>
> Use with caution. Trust but verify.

---

## Credits

TDD and verification skills (`sentry-tdd`, `sentry-verify`) are lightweight adaptations of `test-driven-development` and `verification-before-completion` from the [superpowers](https://github.com/obra/superpowers) plugin, tailored for Sentry bug fixing.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
