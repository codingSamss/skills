#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_ROOT="$REPO_ROOT/platforms/codex/skills"
AGENTS_HOME_DIR="${AGENTS_HOME:-$HOME/.agents}"
TARGET_ROOT="$AGENTS_HOME_DIR/skills"
DRY_RUN="false"

usage() {
  cat <<'USAGE'
用法:
  ./scripts/sync_to_codex.sh
  ./scripts/sync_to_codex.sh --dry-run
  ./scripts/sync_to_codex.sh --agents-home /path/to/.agents

说明:
  按 Codex 官方方式，同步 skills 到 ~/.agents/skills
  目录内每个 skill 必须包含 SKILL.md
  使用镜像同步（rsync --delete），会清理目标目录中的陈旧 skill
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-home)
      shift
      [ $# -gt 0 ] || { echo "[错误] --agents-home 缺少参数"; exit 1; }
      AGENTS_HOME_DIR="$1"
      TARGET_ROOT="$AGENTS_HOME_DIR/skills"
      ;;
    --dry-run)
      DRY_RUN="true"
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "[错误] 未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [ ! -d "$SOURCE_ROOT" ]; then
  echo "[错误] Codex skills 目录不存在: $SOURCE_ROOT"
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "[错误] 未找到 rsync，无法执行镜像同步"
  exit 1
fi

# 严格校验：每个 skill 必须有 SKILL.md（Codex 官方要求）
has_skill="false"
for skill_dir in "$SOURCE_ROOT"/*; do
  [ -d "$skill_dir" ] || continue
  has_skill="true"
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    echo "[错误] 缺少 SKILL.md: $skill_dir"
    exit 1
  fi
done

if [ "$has_skill" != "true" ]; then
  echo "[错误] 未发现任何可同步 skill: $SOURCE_ROOT"
  exit 1
fi

echo "=== Codex 平台同步 ==="
echo "源目录(官方 skills): $SOURCE_ROOT"
echo "目标目录(官方路径): $TARGET_ROOT"

mkdir -p "$TARGET_ROOT"

rsync_args=("-a" "--delete" "--exclude" ".gitkeep")
if [ "$DRY_RUN" = "true" ]; then
  rsync_args+=("--dry-run" "--itemize-changes")
fi

rsync "${rsync_args[@]}" "$SOURCE_ROOT"/ "$TARGET_ROOT"/

skill_count="$(find "$SOURCE_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
echo "技能数: $skill_count"

echo ""
if [ "$DRY_RUN" = "true" ]; then
  echo "预览完成（未写入目标目录）。"
else
  echo "同步完成（目标目录已与官方 skills 源镜像一致）。"
fi
