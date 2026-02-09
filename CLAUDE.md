# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Claude Code Skills repository, packaged as a CC plugin. Contains skills, scripts, hooks, and agent configurations that can be installed via the CC plugin system.

## Repository Layout

```
skills/
├── marketplace.json              # Marketplace registration
├── setup.sh                      # External dependency installer
└── personal-skills/              # Plugin root
    ├── .claude-plugin/plugin.json
    ├── .mcp.json                 # MCP server config (codex)
    ├── skills/                   # All skills
    │   ├── bird-twitter/
    │   ├── committer/
    │   ├── cc-codex-review/
    │   ├── json-canvas/
    │   ├── peekaboo/
    │   ├── plugin-manager/
    │   └── ui-ux-pro-max/
    ├── scripts/                  # External scripts
    │   └── committer
    ├── hooks/                    # Hook scripts
    │   └── notify.sh
    └── agents/                   # Agent configs
        ├── code-review-expert.md
        └── tech-research-advisor.md
```

## Skill File Format

Each skill is defined by a Markdown file (`skill.md` or `SKILL.md`) with this structure:

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
| committer | Git, `scripts/committer` | Bash |
| cc-codex-review | Codex MCP server | Python (`scripts/topic-manager.py`) |
| plugin-manager | Claude Code plugin system | Bash (`scripts/`) |
| ui-ux-pro-max | Python 3 | Python (`scripts/search.py`, `scripts/core.py`) |
| json-canvas | None | - |

## Architecture Patterns

**Skill-per-directory**: Each skill is isolated in its own directory under `personal-skills/skills/`. No cross-skill dependencies exist.

**Script delegation**: Skills with complex logic (plugin-manager, ui-ux-pro-max) use a main entry script that delegates to specialized sub-scripts, rather than embedding all logic in the Markdown prompt.

**Data-driven design** (ui-ux-pro-max): Uses CSV files as searchable knowledge bases with a BM25 search engine (`core.py`), queried via `search.py` CLI.

## Conventions

- Skill descriptions should include Chinese and English trigger keywords
- Shell scripts in `scripts/` should be executable and self-contained
- Commit messages follow Conventional Commits format (e.g., `feat:`, `fix:`, `chore:`)
