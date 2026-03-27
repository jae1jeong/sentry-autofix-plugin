# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

sentry-autofix is a Claude Code plugin that automatically fixes Sentry production errors using TDD and creates Draft PRs. It runs as a set of skills inside Claude Code, using Sentry MCP for issue data and `gh` CLI for PR creation.

## Repository Structure

This is a **Claude Code marketplace plugin**, not a standalone application. There is no build system, test suite, or runtime to execute.

```
.claude-plugin/marketplace.json     # Marketplace catalog entry (owner, plugin list)
plugins/sentry-autofix/
  .claude-plugin/plugin.json        # Plugin manifest (name, version, skill paths)
  .mcp.json                         # Sentry MCP server registration
  skills/
    sentry-setup/SKILL.md           # One-time onboarding wizard
    sentry-scan/SKILL.md            # Read-only Sentry issue scanner
    sentry-fix/SKILL.md             # Full TDD pipeline (core skill)
    sentry-fix/issue-analyzer-prompt.md  # Subagent prompt for issue analysis
    sentry-fix/pr-template.md       # Draft PR body template
    sentry-config/SKILL.md          # Interactive config editor
    sentry-tdd/SKILL.md             # TDD principles (background skill)
    sentry-verify/SKILL.md          # Verification principles (background skill)
install.sh                          # Copies plugin to ~/.claude/plugins/local/
```

## Key Architecture Concepts

- **Skills are pure markdown** — all logic lives in SKILL.md files as structured instructions for Claude Code. There is no executable code.
- **sentry-fix is the core pipeline** — 12-step process: load state → select issue → pre-checks → analysis (subagent) → fetch event details → write reproduction test (Red) → verify failure → fix code (Green) → verify all → git + Draft PR → notify → log.
- **sentry-tdd and sentry-verify are background skills** — loaded as `REQUIRED BACKGROUND` by sentry-fix, not invoked directly. They define TDD and verification principles.
- **State lives in the target project** at `.sentry-autofix/state.json` (created by sentry-setup, gitignored). Contains config, processed issues, ignored list, and lock state.
- **issue-analyzer-prompt.md** is dispatched to a subagent via the Agent tool. It returns structured JSON analysis. The main pipeline then fetches detailed event data directly from Sentry MCP.
- **pr-template.md** is a fill-in template used when creating Draft PRs via `gh pr create --draft`.

## Plugin Installation Flow

Two paths: marketplace (`/plugin marketplace add`) or `install.sh` which copies `plugins/sentry-autofix/` contents to `~/.claude/plugins/local/sentry-autofix/` and registers the Sentry MCP server.

## Critical Rules Enforced by Skills

- Never modify existing tests — only add new test files or new test cases
- Reproduction test must fail before any code fix (TDD Red)
- All verification (test/typecheck/lint) must pass before PR creation
- Max 5 files changed per fix (scope guard)
- 2 consecutive failures → issue added to ignore list
- `analyzing` state older than 30 minutes is treated as stale lock
- sentry-scan is read-only — no code modifications allowed

## Working on This Repo

Changes are markdown authoring. When editing skills:
- Maintain the `---` frontmatter (name, description) — Claude Code uses it for skill discovery
- `REQUIRED BACKGROUND` lines in sentry-fix link to sentry-tdd and sentry-verify
- The analysis subagent prompt (issue-analyzer-prompt.md) must return the exact JSON schema expected by Step 4 of sentry-fix
- State machine transitions in sentry-fix (analyzing → test_written → fixed → pr_created / failed) must stay consistent with pre-check logic in Step 3
