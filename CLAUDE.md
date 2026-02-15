# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-platform skills repository with fully isolated sources for Claude and Codex. Contains skills, scripts, hooks, and agent configurations.

## Repository Layout

```
skills/
├── .claude-plugin/marketplace.json # Marketplace registration
├── setup.sh                      # Claude platform setup entry
├── scripts/                      # Sync/bootstrap scripts
└── platforms/
    ├── claude/                   # Claude source of truth
    │   ├── .claude-plugin/plugin.json
    │   ├── .mcp.json
    │   ├── skills/
    │   ├── hooks/
    │   └── agents/
    └── codex/                    # Codex source of truth
        ├── skills/
        ├── hooks/
        ├── agents/
        └── scripts/
```

## Skill File Format

Each skill is defined by a Markdown file (`SKILL.md`) with this structure:

```markdown
---
name: skill-name
description: "Description with trigger keywords"
---

# Skill Title

Instructions for Claude...
```

- `name` and `description` in YAML frontmatter control how the skill is discovered and triggered
- `description` should include keywords in both Chinese and English for search/matching
- The Markdown body contains the full prompt/instructions Claude will follow
- Parameters: `$ARGUMENTS` for all args, `$1`/`$2` for positional args

## Key Skills and Their Dependencies

| Skill | External Dependency | Script Runtime |
|---|---|---|
| bird-twitter | Bird CLI (`brew install steipete/tap/bird`) | - |
| peekaboo | Peekaboo (`brew install steipete/tap/peekaboo`) | - |
| cc-codex-review | Codex MCP server | Python (`scripts/topic-manager.py`) |
| plugin-manager | Claude Code plugin system | Bash (`scripts/`) |
| ui-ux-pro-max | Python 3 | Python (`scripts/search.py`, `scripts/core.py`) |

## Architecture Patterns

**Skill-per-directory**: Each skill is isolated in its own directory under platform-specific `skills/` roots. No cross-skill dependencies exist.

**Script delegation**: Skills with complex logic (plugin-manager, ui-ux-pro-max) use a main entry script that delegates to specialized sub-scripts, rather than embedding all logic in the Markdown prompt.

**Data-driven design** (ui-ux-pro-max): Uses CSV files as searchable knowledge bases with a BM25 search engine (`core.py`), queried via `search.py` CLI.

## Local Sync Rule

本项目按平台同步生效。**提交 git 时必须同步验证**。

- Claude 同步入口: `./setup.sh`（源目录 `platforms/claude`）
- Codex 同步入口: `./scripts/sync_to_codex.sh`（源目录 `platforms/codex/skills`，镜像同步到 `~/.agents/skills`）
- 每次 git commit 涉及 `platforms/claude/` 或 `platforms/codex/` 变更时，必须执行对应同步并验证

## Conventions

- Skill descriptions should include Chinese and English trigger keywords
- Shell scripts in `scripts/` should be executable and self-contained
- Commit messages follow Conventional Commits format (e.g., `feat:`, `fix:`, `chore:`)
