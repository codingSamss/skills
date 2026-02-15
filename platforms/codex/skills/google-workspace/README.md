# google-workspace

## 作用
通过 gogcli 以只读方式访问 Gmail、Drive、Docs、Sheets、Calendar 等 Google Workspace 能力。

## 平台支持
- Claude Code（已支持）
- Codex（已支持）

## 工作原理
Skill 调用 `gog` 命令，通过 OAuth 授权访问 Google API；默认使用只读权限，避免误写数据。

## 配置命令

```bash
./setup.sh google-workspace
# 或直接执行
platforms/codex/skills/google-workspace/setup.sh
```

## 配置脚本行为

- 退出码：`0` 自动完成，`2` 需手动补齐，`1` 执行失败
- 自动检查项：
  - `gog` 是否可用（缺失时尝试 `brew install steipete/tap/gogcli`）
  - OAuth 授权状态（`gog auth status`）
- 需手动补齐项：
  - 没有 Homebrew 时，手动安装 gogcli
  - 尚未完成 Google OAuth 授权

## 验证命令

```bash
gog auth status
gog auth services
```

## 使用方式
- 触发词：`search email`、`drive files`、`calendar`
- 详细命令与 OAuth 配置见：`platforms/codex/skills/google-workspace/SKILL.md`

## 依赖
- gogcli（`brew install steipete/tap/gogcli`）
- Google OAuth 凭据与账号授权
