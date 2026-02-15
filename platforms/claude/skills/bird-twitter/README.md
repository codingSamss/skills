# bird-twitter

## 作用
通过 Bird CLI 只读访问 X/Twitter 内容（推文、搜索、书签、趋势、时间线）。

## 平台支持
- Claude Code（已支持）
- Codex（已支持）

## 工作原理
Skill 调用本地 `bird` 命令并使用浏览器 Cookie 做认证，不提供发帖/评论等写操作。

## 配置命令

```bash
./setup.sh bird-twitter
# 或直接执行
platforms/claude/skills/bird-twitter/setup.sh
```

## 配置脚本行为

- 退出码：`0` 自动完成，`2` 需手动补齐，`1` 执行失败
- 自动检查项：
  - Bird CLI 是否可用（缺失时尝试 `brew install steipete/tap/bird`）
  - Bird 认证状态（`bird --cookie-source chrome whoami`）
- 需手动补齐项：
  - 没有 Homebrew 时，手动安装 Bird CLI
  - 未登录 X/Twitter 时，先在 Chrome 登录并完成 Bird 认证

## 验证命令

```bash
bird --cookie-source chrome whoami
```

## 使用方式
- 触发词：`read tweet`、`search twitter`、`my bookmarks`、`trending`
- 详细命令与触发规则见：`platforms/claude/skills/bird-twitter/SKILL.md`

## 依赖
- Bird CLI（`brew install steipete/tap/bird`）
- Chrome 已登录 X/Twitter
