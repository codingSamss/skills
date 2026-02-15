#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'USAGE'
用法:
  ./scripts/bootstrap.sh all      # Claude + Codex
  ./scripts/bootstrap.sh claude   # 仅 Claude
  ./scripts/bootstrap.sh codex    # 仅 Codex

退出码:
  0: 全部自动完成
  1: 存在失败
  2: 存在需手动完成项（无失败）
USAGE
}

run_claude_setup() {
  local code=0
  if "$REPO_ROOT/setup.sh" all; then
    code=0
  else
    code=$?
  fi

  if [ "$code" -eq 0 ]; then
    return 0
  fi

  if [ "$code" -eq 2 ]; then
    return 2
  fi
  return 1
}

run_codex_sync() {
  "$REPO_ROOT/scripts/sync_to_codex.sh"
}

target="${1:-all}"
status=0

echo "=== 新机初始化引导 ==="

case "$target" in
  all)
    echo "[1/2] 配置 Claude Code 侧..."
    if run_claude_setup; then
      echo "[1/2] Claude 侧自动完成"
    else
      code=$?
      if [ "$code" -eq 2 ]; then
        echo "[1/2] Claude 侧存在需手动完成项"
        status=2
      else
        echo "[1/2] Claude 侧执行失败"
        exit 1
      fi
    fi

    echo "[2/2] 同步 Codex Skills（官方目录 ~/.agents/skills）..."
    run_codex_sync
    ;;
  claude)
    echo "[1/1] 配置 Claude Code 侧..."
    if run_claude_setup; then
      status=0
    else
      code=$?
      if [ "$code" -eq 2 ]; then
        status=2
      else
        exit 1
      fi
    fi
    ;;
  codex)
    echo "[1/1] 同步 Codex Skills（官方目录 ~/.agents/skills）..."
    run_codex_sync
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "[错误] 未知目标: $target"
    usage
    exit 1
    ;;
esac

echo ""
if [ "$status" -eq 2 ]; then
  echo "初始化已完成，但存在需手动补齐项。"
  echo "建议按 setup 汇总清单逐项补齐后再执行一次。"
  exit 2
fi

echo "初始化完成。建议重启 Claude Code 与 Codex 客户端。"
