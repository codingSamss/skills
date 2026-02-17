# AI Dotfiles（Claude Code + Codex）

这个仓库现在采用**平台完全隔离**：

- Claude 平台源：`platforms/claude/`
- Codex 平台源：`platforms/codex/`

两边目录独立维护，技术实现允许不同，不强行统一。

## 目录约定

1. `platforms/claude/`
- Claude 的 `skills/agents/hooks/.mcp.json/.claude-plugin` 等完整配置源。

2. `platforms/codex/`
- Codex 的 `skills` 官方配置源（`SKILL.md` 规范）。
- 同时维护 Codex 根目录受管配置：`AGENTS.md`、`config.toml`、`agents/bin/hooks/scripts/rules`。

## 快速使用

### Claude 侧

```bash
# 读取 platforms/claude 作为源执行配置
./setup.sh

# 按 skill 执行
./setup.sh reddit
./setup.sh cc-codex-review peekaboo
```

`setup.sh` 退出码：
- `0`：全部自动完成
- `2`：存在需手动完成项
- `1`：存在失败项

### Codex 侧

```bash
# 默认同步到 ~/.codex（skills + 受管 root 配置）
./scripts/sync_to_codex.sh

# 预览
./scripts/sync_to_codex.sh --dry-run
```

### 新机一键

```bash
./scripts/bootstrap.sh all
```

## 设计原则

- 不再维护 `personal-skills` 中间目录。
- 仓库内以 `platforms/claude` 与 `platforms/codex` 作为唯一真源。

## 平台差异约束

- `cc-codex-review` 只保留在 Claude 平台，不同步到 Codex。
- Codex Skills 严格使用 `SKILL.md`，默认同步到 `~/.codex/skills`。
- Codex 根目录受管配置同步到 `~/.codex/{AGENTS.md,config.toml,agents,bin,hooks,scripts,rules}`。
- 同步策略：增量同步（保留 `.system` 与本地未托管内容）。
- 换机若用户名或目录不同，请复核 `~/.codex/config.toml` 的绝对路径配置。
- 各平台 README 作为第一手操作指引。

## 平台文档入口

- Claude：`platforms/claude/README.md`
- Codex：`platforms/codex/README.md`
