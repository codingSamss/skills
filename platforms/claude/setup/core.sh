#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[core] 配置公共组件..."

# hooks（使用复制，避免软链接失效）
echo "[core] 复制 hooks/notify.sh -> ~/.claude/hooks/notify.sh"
mkdir -p "$HOME/.claude/hooks"
install -m 755 "$PLUGIN_DIR/hooks/notify.sh" "$HOME/.claude/hooks/notify.sh"

# agents（使用复制，避免软链接失效）
echo "[core] 复制 agents -> ~/.claude/agents/"
mkdir -p "$HOME/.claude/agents"
for agent in "$PLUGIN_DIR"/agents/*.md; do
  [ -f "$agent" ] || continue
  name="$(basename "$agent")"
  install -m 644 "$agent" "$HOME/.claude/agents/$name"
  echo "  - $name"
done

# skills（同步 SKILL.md 到 ~/.claude/skills/）
echo "[core] 同步 skills -> ~/.claude/skills/"
for skill_dir in "$PLUGIN_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target_dir="$HOME/.claude/skills/$skill_name"
  mkdir -p "$target_dir"
  # 同步 SKILL.md（同时处理大小写差异，统一为 SKILL.md）
  if [ -f "$skill_dir/SKILL.md" ]; then
    # 清理可能存在的旧小写文件
    [ -f "$target_dir/skill.md" ] && [ ! -f "$target_dir/SKILL.md" ] && rm -f "$target_dir/skill.md"
    install -m 644 "$skill_dir/SKILL.md" "$target_dir/SKILL.md"
  fi
  echo "  - $skill_name"
done

echo "[core] 完成"
