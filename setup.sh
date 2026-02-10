#!/bin/bash
set -euo pipefail

# Personal Skills - 外部依赖安装脚本
# 用于安装插件系统无法自动处理的外部依赖

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/personal-skills"

echo "=== Personal Skills Setup ==="
echo ""

# --- 1. Homebrew 工具 ---
if command -v brew &>/dev/null; then
    echo "[1/4] 安装 Homebrew 依赖..."

    # bird-twitter skill 依赖
    if ! command -v bird &>/dev/null; then
        echo "  - 安装 Bird CLI..."
        brew install steipete/tap/bird
    else
        echo "  - Bird CLI 已安装, 跳过"
    fi

    # peekaboo skill 依赖
    if ! command -v peekaboo &>/dev/null; then
        echo "  - 安装 Peekaboo..."
        brew install steipete/tap/peekaboo
    else
        echo "  - Peekaboo 已安装, 跳过"
    fi

    # ui-ux-pro-max skill 依赖
    if ! command -v python3 &>/dev/null; then
        echo "  - 安装 Python 3..."
        brew install python3
    else
        echo "  - Python 3 已安装, 跳过"
    fi

    # drawio skill 依赖（MCP 通过 npx 运行）
    if ! command -v node &>/dev/null; then
        echo "  - 安装 Node.js..."
        brew install node
    else
        echo "  - Node.js 已安装, 跳过"
    fi

    # hooks/notify.sh 依赖
    if ! command -v jq &>/dev/null; then
        echo "  - 安装 jq..."
        brew install jq
    else
        echo "  - jq 已安装, 跳过"
    fi
else
    echo "[1/4] Homebrew 未安装, 跳过工具安装"
    echo "  请手动安装: bird, peekaboo, python3, jq"
fi

echo ""

# --- 2. 符号链接: scripts/committer ---
echo "[2/4] 链接 scripts/committer -> ~/.claude/scripts/committer"
mkdir -p ~/.claude/scripts
ln -sf "$PLUGIN_DIR/scripts/committer" ~/.claude/scripts/committer
echo "  done"

echo ""

# --- 3. 符号链接: hooks/notify.sh ---
echo "[3/4] 链接 hooks/notify.sh -> ~/.claude/hooks/notify.sh"
mkdir -p ~/.claude/hooks
ln -sf "$PLUGIN_DIR/hooks/notify.sh" ~/.claude/hooks/notify.sh
echo "  done"

echo ""

# --- 4. 符号链接: agents ---
echo "[4/4] 链接 agents -> ~/.claude/agents/"
mkdir -p ~/.claude/agents
for agent in "$PLUGIN_DIR"/agents/*.md; do
    name="$(basename "$agent")"
    ln -sf "$agent" ~/.claude/agents/"$name"
    echo "  - $name"
done
echo "  done"

echo ""
echo "=== Setup 完成 ==="
echo "请重启 Claude Code 以加载新配置"
