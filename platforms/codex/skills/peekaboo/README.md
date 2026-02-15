# peekaboo

## 作用
用于 macOS 场景的截图与视觉分析，辅助定位 UI/交互问题。

## 平台支持
- Claude Code（已支持）
- Codex（已支持）

## 工作原理
Skill 调用 `peekaboo` 进行窗口捕获、标注与分析；输出截图到固定目录，并在任务结束后清理。

## 配置命令

```bash
./setup.sh peekaboo
# 或直接执行
platforms/codex/skills/peekaboo/setup.sh
```

## 配置脚本行为

- 退出码：`0` 自动完成，`2` 需手动补齐，`1` 执行失败
- 自动检查项：
  - Peekaboo 是否可用（缺失时尝试 `brew install steipete/tap/peekaboo`）
  - 屏幕访问能力（`peekaboo list windows --json`）
- 需手动补齐项：
  - 没有 Homebrew 时，手动安装 Peekaboo
  - 未授予系统屏幕录制权限

## 验证命令

```bash
peekaboo list windows --json
```

## 使用方式
- 触发词：`截图`、`界面`、`显示`、`报错弹窗`
- 详细策略与清理规则见：`platforms/codex/skills/peekaboo/SKILL.md`

## 依赖
- Peekaboo（`brew install steipete/tap/peekaboo`）
- 系统已授予屏幕录制权限
