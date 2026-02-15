# Codex 平台目录（codex）

## 目录说明

`platforms/codex` 是 Codex 平台唯一配置源，包含：

- `platforms/codex/skills/`
- `platforms/codex/agents/`
- `platforms/codex/hooks/`
- `platforms/codex/scripts/`

其中，Codex Skills 官方加载路径对应 `~/.agents/skills`，并要求每个 skill 目录包含 `SKILL.md`。

## 同步入口

```bash
./scripts/sync_to_codex.sh
```

预览：

```bash
./scripts/sync_to_codex.sh --dry-run
```

说明：

- 同步为镜像模式（`rsync --delete`），会清理 `~/.agents/skills` 下与源目录不一致的旧 skill。
- 建议先执行 `--dry-run` 预览变更，再正式执行。

## 当前策略

- `cc-codex-review` 不进入 Codex 平台（该 Skill 专用于 Claude 调 Codex）
- `cc-codex-review` 关联的 Battle Agent 也不进入 Codex 平台
- skills 按 Codex 官方规范管理；agents/hooks/scripts 作为扩展资产单独维护
