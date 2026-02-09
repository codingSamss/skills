#!/bin/bash
# session-manager.sh - CC-Codex 协作审查 SESSION_ID 管理脚本
#
# 用法:
#   session-manager.sh read <项目根目录> <阶段名>
#   session-manager.sh save <项目根目录> <阶段名> <session_id>
#   session-manager.sh reset <项目根目录> <阶段名>
#   session-manager.sh reset-all <项目根目录>
#   session-manager.sh status <项目根目录>
#   session-manager.sh check-stale <项目根目录> [阈值分钟数]
#   session-manager.sh auto-cleanup <项目根目录> [阈值分钟数]
#   session-manager.sh complete <项目根目录> <阶段名>
#   session-manager.sh complete-all <项目根目录>
#
# 阶段名: plan-review | code-review | final-review
# 阈值分钟数: 默认 60 分钟

set -euo pipefail

ACTION="${1:-}"
PROJECT_ROOT="${2:-}"
PHASE="${3:-}"
SESSION_ID="${4:-}"

# 数据目录
DATA_DIR=".cc-codex"
SESSIONS_DIR="${DATA_DIR}/sessions"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "用法: session-manager.sh <action> <project_root> [phase] [session_id]"
    echo ""
    echo "Actions:"
    echo "  read          读取指定阶段的 SESSION_ID"
    echo "  save          保存指定阶段的 SESSION_ID"
    echo "  reset         重置指定阶段的会话"
    echo "  reset-all     重置所有阶段的会话"
    echo "  status        显示所有阶段的会话状态"
    echo "  check-stale   检查会话是否过期（第三个参数为阈值分钟数，默认60）"
    echo "  auto-cleanup  自动清理过期会话（第三个参数为阈值分钟数，默认60）"
    echo "  complete      归档指定阶段的会话（保留记录，标记为已完成）"
    echo "  complete-all  归档所有阶段的会话（整个审查周期结束）"
    echo ""
    echo "Phases: plan-review | code-review | final-review"
    exit 1
}

# 验证阶段名是否合法
validate_phase() {
    local phase="$1"
    case "$phase" in
        plan-review|code-review|final-review)
            return 0
            ;;
        *)
            echo -e "${RED}错误: 无效的阶段名 '${phase}'${NC}" >&2
            echo "合法值: plan-review | code-review | final-review" >&2
            exit 1
            ;;
    esac
}

# 确保数据目录存在
ensure_dirs() {
    local root="$1"
    mkdir -p "${root}/${SESSIONS_DIR}"
}

# 获取会话文件路径
session_file() {
    local root="$1"
    local phase="$2"
    echo "${root}/${SESSIONS_DIR}/${phase}.session"
}

# 获取活动时间戳文件路径
activity_file() {
    local root="$1"
    echo "${root}/${SESSIONS_DIR}/.last-activity"
}

# 更新活动时间戳
touch_activity() {
    local root="$1"
    ensure_dirs "$root"
    date +%s > "$(activity_file "$root")"
}

# 检查会话是否过期
# 返回: exit 0 = 过期, exit 1 = 仍活跃, exit 2 = 无历史会话
# 输出: stale|闲置分钟数|上次活动时间 / fresh|闲置分钟数 / no-session
do_check_stale() {
    local root="$1"
    local threshold_minutes="${2:-60}"
    local afile
    afile=$(activity_file "$root")

    if [[ ! -f "$afile" ]]; then
        echo "no-session"
        return 2
    fi

    local last_ts now_ts diff_seconds diff_minutes
    last_ts=$(cat "$afile")
    now_ts=$(date +%s)
    diff_seconds=$((now_ts - last_ts))
    diff_minutes=$((diff_seconds / 60))

    if [[ $diff_minutes -ge $threshold_minutes ]]; then
        # macOS 和 Linux 兼容的时间格式化
        local last_time
        last_time=$(date -r "$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        echo "stale|${diff_minutes}|${last_time}"
        return 0
    else
        echo "fresh|${diff_minutes}"
        return 1
    fi
}

# 自动清理过期会话
do_auto_cleanup() {
    local root="$1"
    local threshold_minutes="${2:-60}"

    local result exit_code
    result=$(do_check_stale "$root" "$threshold_minutes") && exit_code=$? || exit_code=$?

    if [[ $exit_code -eq 2 ]]; then
        echo -e "${GREEN}无历史会话，无需清理${NC}"
        return 0
    fi

    if [[ $exit_code -eq 1 ]]; then
        local minutes
        minutes=$(echo "$result" | cut -d'|' -f2)
        echo -e "${GREEN}会话仍在活跃期内（闲置 ${minutes} 分钟），无需清理${NC}"
        return 0
    fi

    # exit_code == 0，会话已过期
    local minutes last_time
    minutes=$(echo "$result" | cut -d'|' -f2)
    last_time=$(echo "$result" | cut -d'|' -f3)

    echo -e "${YELLOW}检测到过期会话（上次活动: ${last_time}，已闲置 ${minutes} 分钟）${NC}"
    echo -e "${YELLOW}自动重置所有 Codex 会话...${NC}"
    do_reset_all "$root"
    # 清除活动时间戳，下次 save 时会重建
    rm -f "$(activity_file "$root")"
    echo -e "${GREEN}已清理，将开始新的审查周期${NC}"
}

# 读取 SESSION_ID
do_read() {
    local root="$1"
    local phase="$2"
    validate_phase "$phase"

    local file
    file=$(session_file "$root" "$phase")

    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo ""
    fi
}

# 保存 SESSION_ID
do_save() {
    local root="$1"
    local phase="$2"
    local sid="$3"
    validate_phase "$phase"

    if [[ -z "$sid" ]]; then
        echo -e "${RED}错误: SESSION_ID 不能为空${NC}" >&2
        exit 1
    fi

    ensure_dirs "$root"
    local file
    file=$(session_file "$root" "$phase")
    echo "$sid" > "$file"
    touch_activity "$root"
    echo -e "${GREEN}已保存 ${phase} 的 SESSION_ID${NC}"
}

# 重置指定阶段
do_reset() {
    local root="$1"
    local phase="$2"
    validate_phase "$phase"

    local file
    file=$(session_file "$root" "$phase")

    if [[ -f "$file" ]]; then
        rm "$file"
        echo -e "${YELLOW}已重置 ${phase} 的会话${NC}"
    else
        echo -e "${YELLOW}${phase} 无活跃会话${NC}"
    fi
}

# 重置所有阶段
do_reset_all() {
    local root="$1"
    local dir="${root}/${SESSIONS_DIR}"

    if [[ -d "$dir" ]]; then
        rm -f "${dir}"/*.session
        echo -e "${YELLOW}已重置所有阶段的会话${NC}"
    else
        echo -e "${YELLOW}无活跃会话${NC}"
    fi
}

# 归档指定阶段的会话（保留记录，标记为已完成）
do_complete() {
    local root="$1"
    local phase="$2"
    validate_phase "$phase"

    local file
    file=$(session_file "$root" "$phase")

    if [[ -f "$file" ]]; then
        local timestamp
        timestamp=$(date "+%Y%m%d-%H%M%S")
        mv "$file" "${file%.session}.${timestamp}.archived"
        echo -e "${GREEN}已归档 ${phase} 的会话${NC}"
    else
        echo -e "${YELLOW}${phase} 无活跃会话，跳过归档${NC}"
    fi
}

# 归档所有阶段的会话（整个审查周期结束）
do_complete_all() {
    local root="$1"
    local phases=("plan-review" "code-review" "final-review")
    local timestamp
    timestamp=$(date "+%Y%m%d-%H%M%S")
    local archived=0

    for phase in "${phases[@]}"; do
        local file
        file=$(session_file "$root" "$phase")
        if [[ -f "$file" ]]; then
            mv "$file" "${file%.session}.${timestamp}.archived"
            echo -e "${GREEN}  已归档 ${phase}${NC}"
            archived=$((archived + 1))
        fi
    done

    # 清除活动时间戳
    rm -f "$(activity_file "$root")"

    if [[ $archived -gt 0 ]]; then
        echo -e "${GREEN}已归档 ${archived} 个会话，审查周期结束${NC}"
    else
        echo -e "${YELLOW}无活跃会话需要归档${NC}"
    fi
}

# 显示状态
do_status() {
    local root="$1"
    local phases=("plan-review" "code-review" "final-review")

    echo "=== CC-Codex 审查会话状态 ==="
    echo "项目: ${root}"
    echo ""

    # 显示活动时间
    local afile
    afile=$(activity_file "$root")
    if [[ -f "$afile" ]]; then
        local last_ts now_ts diff_minutes last_time
        last_ts=$(cat "$afile")
        now_ts=$(date +%s)
        diff_minutes=$(( (now_ts - last_ts) / 60 ))
        last_time=$(date -r "$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        echo -e "  上次活动: ${last_time}（${diff_minutes} 分钟前）"
    else
        echo -e "  上次活动: ${RED}无记录${NC}"
    fi
    echo ""

    for phase in "${phases[@]}"; do
        local file
        file=$(session_file "$root" "$phase")
        if [[ -f "$file" ]]; then
            local sid
            sid=$(cat "$file")
            local short_id="${sid:0:12}..."
            echo -e "  ${phase}: ${GREEN}活跃${NC} (${short_id})"
        else
            echo -e "  ${phase}: ${RED}无会话${NC}"
        fi
    done

    echo ""

    # 检查归档会话
    local archive_count
    archive_count=$(find "${root}/${SESSIONS_DIR}" -name "*.archived" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $archive_count -gt 0 ]]; then
        echo -e "  历史归档: ${archive_count} 个"
    fi

    echo ""

    # 检查计划文件
    if [[ -f "${root}/${DATA_DIR}/plan.md" ]]; then
        echo -e "  共识计划: ${GREEN}存在${NC}"
    else
        echo -e "  共识计划: ${RED}未创建${NC}"
    fi

    # 检查审查日志
    if [[ -f "${root}/${DATA_DIR}/review-log.md" ]]; then
        echo -e "  审查日志: ${GREEN}存在${NC}"
    else
        echo -e "  审查日志: ${RED}未创建${NC}"
    fi
}

# 参数校验
if [[ -z "$ACTION" ]]; then
    usage
fi

if [[ -z "$PROJECT_ROOT" ]]; then
    echo -e "${RED}错误: 必须指定项目根目录${NC}" >&2
    usage
fi

# 分发命令
case "$ACTION" in
    read)
        [[ -z "$PHASE" ]] && usage
        do_read "$PROJECT_ROOT" "$PHASE"
        ;;
    save)
        [[ -z "$PHASE" ]] && usage
        [[ -z "$SESSION_ID" ]] && usage
        do_save "$PROJECT_ROOT" "$PHASE" "$SESSION_ID"
        ;;
    reset)
        [[ -z "$PHASE" ]] && usage
        do_reset "$PROJECT_ROOT" "$PHASE"
        ;;
    reset-all)
        do_reset_all "$PROJECT_ROOT"
        ;;
    status)
        do_status "$PROJECT_ROOT"
        ;;
    check-stale)
        do_check_stale "$PROJECT_ROOT" "$PHASE"
        ;;
    auto-cleanup)
        do_auto_cleanup "$PROJECT_ROOT" "$PHASE"
        ;;
    complete)
        [[ -z "$PHASE" ]] && usage
        do_complete "$PROJECT_ROOT" "$PHASE"
        ;;
    complete-all)
        do_complete_all "$PROJECT_ROOT"
        ;;
    *)
        echo -e "${RED}错误: 未知操作 '${ACTION}'${NC}" >&2
        usage
        ;;
esac
