# reddit

## 作用
通过 Composio MCP 以只读方式访问 Reddit（搜索、热帖、帖子与评论）。

## 平台支持
- Claude Code（已支持）
- Codex（已支持）

## 工作原理
Skill 调用 `composio-reddit` MCP 工具链，仅开放只读能力，避免写操作风险。

## 配置命令

```bash
./setup.sh reddit
# 或直接执行
platforms/claude/skills/reddit/setup.sh
```

## 配置脚本行为

- 退出码：`0` 自动完成，`2` 需手动补齐，`1` 执行失败
- 自动检查项：
  - Python3 是否可用（缺失时尝试安装）
  - Composio SDK 是否可导入（缺失时尝试 `python3 -m pip install composio`）
  - `composio-reddit` MCP 是否已在 `~/.claude.json` 注册
- 需手动补齐项：
  - 没有 Homebrew 且缺少 Python3
  - Composio Reddit OAuth 未完成

## 验证命令

```bash
python3 -c "import composio"
claude mcp list
```

## 使用方式
- 触发词：`search reddit`、`hot posts`、`reddit comments`
- 详细工具映射见：`platforms/claude/skills/reddit/SKILL.md`

## 依赖
- Python3
- Composio SDK（`python3 -m pip install composio`）
- Composio Reddit OAuth 授权
