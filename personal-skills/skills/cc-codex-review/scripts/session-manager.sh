#!/bin/bash
# session-manager.sh - CC-Codex 协作审查会话 & 周期管理脚本
#
# 用法:
#   session-manager.sh read <项目根目录> <阶段名>
#   session-manager.sh save <项目根目录> <阶段名> <session_id>
#   session-manager.sh reset <项目根目录> <阶段名>
#   session-manager.sh reset-all <项目根目录>
#   session-manager.sh complete <项目根目录> <阶段名>
#   session-manager.sh complete-all <项目根目录>
#   session-manager.sh check-stale <项目根目录> [阈值分钟数]
#   session-manager.sh auto-cleanup <项目根目录> [阈值分钟数]
#   session-manager.sh cycle-init <项目根目录> [功能描述]
#   session-manager.sh cycle-current <项目根目录>
#   session-manager.sh cycle-cleanup <项目根目录> [保留数量]
#   session-manager.sh status <项目根目录>
#
# 阶段名: plan-review | code-review | final-review
# 阈值分钟数: 默认 60 分钟
# 保留数量: 默认 5 个历史周期

set -euo pipefail

ACTION="${1:-}"
PROJECT_ROOT="${2:-}"
PHASE="${3:-}"
SESSION_ID="${4:-}"

# 数据目录
DATA_DIR=".cc-codex"
CYCLES_DIR="${DATA_DIR}/cycles"
POINTER_FILE="${DATA_DIR}/current-cycle"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "用法: session-manager.sh <action> <project_root> [phase|参数]"
    echo ""
    echo "会话管理:"
    echo "  read <phase>           读取指定阶段的 SESSION_ID"
    echo "  save <phase> <sid>     保存指定阶段的 SESSION_ID"
    echo "  reset <phase>          重置指定阶段的会话"
    echo "  reset-all              重置所有阶段的会话"
    echo "  complete <phase>       归档指定阶段的会话"
    echo "  complete-all           归档所有会话并关闭当前周期"
    echo ""
    echo "周期管理:"
    echo "  cycle-init [描述]      创建新的审查周期"
    echo "  cycle-current          输出当前周期目录路径"
    echo "  cycle-cleanup [N]      清理旧周期，保留最近 N 个（默认5）"
    echo "  status                 显示审查状态总览"
    echo ""
    echo "过期检测:"
    echo "  check-stale [分钟]     检查当前周期是否过期（默认60分钟）"
    echo "  auto-cleanup [分钟]    自动处理过期周期（默认60分钟）"
    echo ""
    echo "Phases: plan-review | code-review | final-review"
    exit 1
}

# ========== 基础工具函数 ==========

validate_phase() {
    local phase="$1"
    case "$phase" in
        plan-review|code-review|final-review) return 0 ;;
        *)
            echo -e "${RED}错误: 无效的阶段名 '${phase}'${NC}" >&2
            echo "合法值: plan-review | code-review | final-review" >&2
            exit 1
            ;;
    esac
}

# 读取当前周期目录名（从指针文件）
read_current_cycle() {
    local root="$1"
    local pfile="${root}/${POINTER_FILE}"
    if [[ -f "$pfile" ]]; then
        cat "$pfile"
    else
        echo ""
    fi
}

# 获取当前周期的完整路径，不存在则返回空
current_cycle_dir() {
    local root="$1"
    local cycle_name
    cycle_name=$(read_current_cycle "$root")
    if [[ -n "$cycle_name" && -d "${root}/${CYCLES_DIR}/${cycle_name}" ]]; then
        echo "${root}/${CYCLES_DIR}/${cycle_name}"
    else
        echo ""
    fi
}

# 获取当前周期的 sessions 目录路径
current_sessions_dir() {
    local cdir
    cdir=$(current_cycle_dir "$1")
    if [[ -n "$cdir" ]]; then
        echo "${cdir}/sessions"
    else
        echo ""
    fi
}

# 获取会话文件路径（当前周期内）
session_file() {
    local root="$1"
    local phase="$2"
    local sdir
    sdir=$(current_sessions_dir "$root")
    if [[ -n "$sdir" ]]; then
        echo "${sdir}/${phase}.session"
    else
        echo ""
    fi
}

# 获取活动时间戳文件路径（当前周期内）
activity_file() {
    local root="$1"
    local sdir
    sdir=$(current_sessions_dir "$root")
    if [[ -n "$sdir" ]]; then
        echo "${sdir}/.last-activity"
    else
        echo ""
    fi
}

# 更新活动时间戳
touch_activity() {
    local root="$1"
    local afile
    afile=$(activity_file "$root")
    if [[ -n "$afile" ]]; then
        mkdir -p "$(dirname "$afile")"
        date +%s > "$afile"
    fi
}

# 读取 cycle.meta 中的字段值
read_meta() {
    local cycle_dir="$1"
    local key="$2"
    local meta="${cycle_dir}/cycle.meta"
    if [[ -f "$meta" ]]; then
        grep "^${key}=" "$meta" 2>/dev/null | head -1 | cut -d'=' -f2-
    else
        echo ""
    fi
}

# 写入/更新 cycle.meta 中的字段
write_meta() {
    local cycle_dir="$1"
    local key="$2"
    local value="$3"
    local meta="${cycle_dir}/cycle.meta"

    if [[ -f "$meta" ]] && grep -q "^${key}=" "$meta" 2>/dev/null; then
        # macOS 和 Linux 兼容的 sed -i
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$meta"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$meta"
        fi
    else
        echo "${key}=${value}" >> "$meta"
    fi
}

# ========== 周期管理 ==========

# 创建新的审查周期
do_cycle_init() {
    local root="$1"
    local description="${2:-}"
    local timestamp
    timestamp=$(date "+%Y%m%d-%H%M%S")
    local cycle_name="${timestamp}"
    local cycle_dir="${root}/${CYCLES_DIR}/${cycle_name}"

    # 如果已有活跃周期，不能重复创建
    local current
    current=$(read_current_cycle "$root")
    if [[ -n "$current" && -d "${root}/${CYCLES_DIR}/${current}" ]]; then
        local status
        status=$(read_meta "${root}/${CYCLES_DIR}/${current}" "status")
        if [[ "$status" == "active" ]]; then
            echo -e "${YELLOW}当前已有活跃周期: ${current}${NC}"
            echo "${root}/${CYCLES_DIR}/${current}"
            return 0
        fi
    fi

    # 创建周期目录
    mkdir -p "${cycle_dir}/sessions"

    # 写入 cycle.meta
    cat > "${cycle_dir}/cycle.meta" <<METAEOF
status=active
description=${description}
created_at=$(date "+%Y-%m-%dT%H:%M:%S")
completed_at=
METAEOF

    # 更新指针
    mkdir -p "${root}/${DATA_DIR}"
    echo "$cycle_name" > "${root}/${POINTER_FILE}"

    echo -e "${GREEN}已创建新审查周期: ${cycle_name}${NC}"
    if [[ -n "$description" ]]; then
        echo -e "${GREEN}  描述: ${description}${NC}"
    fi

    # 创建新周期后自动清理旧周期
    do_cycle_cleanup "$root" 5

    echo "${cycle_dir}"
}

# 输出当前周期目录路径
do_cycle_current() {
    local root="$1"
    local cdir
    cdir=$(current_cycle_dir "$root")
    if [[ -n "$cdir" ]]; then
        echo "$cdir"
    else
        echo ""
    fi
}

# 清理旧周期，保留最近 N 个非活跃周期
do_cycle_cleanup() {
    local root="$1"
    local keep_count="${2:-5}"
    local cycles_dir="${root}/${CYCLES_DIR}"

    if [[ ! -d "$cycles_dir" ]]; then
        return 0
    fi

    local current_name
    current_name=$(read_current_cycle "$root")

    # 收集可清理的周期（completed/abandoned，不含 active 和 current）
    local deletable=()
    local has_completed=false

    # 按目录名倒序排列（时间戳格式保证字典序 = 时间序）
    while IFS= read -r dir_name; do
        [[ -z "$dir_name" ]] && continue
        # 跳过当前活跃周期
        [[ "$dir_name" == "$current_name" ]] && continue

        local cdir="${cycles_dir}/${dir_name}"
        [[ ! -d "$cdir" ]] && continue

        local status
        status=$(read_meta "$cdir" "status")

        # 只清理 completed 和 abandoned
        if [[ "$status" == "completed" || "$status" == "abandoned" ]]; then
            deletable+=("$dir_name")
            if [[ "$status" == "completed" ]]; then
                has_completed=true
            fi
        fi
    done < <(ls -1 "$cycles_dir" 2>/dev/null | sort -r)

    # 保留最近 keep_count 个
    local total=${#deletable[@]}
    if [[ $total -le $keep_count ]]; then
        return 0
    fi

    local deleted=0
    local completed_remaining=0

    # 先统计保留部分中有多少 completed
    for ((i=0; i<keep_count && i<total; i++)); do
        local status
        status=$(read_meta "${cycles_dir}/${deletable[$i]}" "status")
        if [[ "$status" == "completed" ]]; then
            completed_remaining=$((completed_remaining + 1))
        fi
    done

    # 从第 keep_count+1 个开始删除
    for ((i=keep_count; i<total; i++)); do
        local dir_name="${deletable[$i]}"
        local cdir="${cycles_dir}/${dir_name}"
        local status
        status=$(read_meta "$cdir" "status")

        # 保护：至少保留 1 个 completed（如果保留部分没有 completed 的话）
        if [[ "$status" == "completed" && $completed_remaining -eq 0 ]]; then
            completed_remaining=1
            continue
        fi

        rm -rf "$cdir"
        deleted=$((deleted + 1))
    done

    if [[ $deleted -gt 0 ]]; then
        echo -e "${YELLOW}已清理 ${deleted} 个旧周期（保留最近 ${keep_count} 个）${NC}"
    fi
}

# ========== 会话管理（基于当前周期） ==========

# 确保当前周期存在
require_cycle() {
    local root="$1"
    local cdir
    cdir=$(current_cycle_dir "$root")
    if [[ -z "$cdir" ]]; then
        echo -e "${RED}错误: 无活跃审查周期。请先执行 /review plan 开始新的审查。${NC}" >&2
        exit 1
    fi
    echo "$cdir"
}

do_read() {
    local root="$1"
    local phase="$2"
    validate_phase "$phase"

    local file
    file=$(session_file "$root" "$phase")

    if [[ -n "$file" && -f "$file" ]]; then
        cat "$file"
    else
        echo ""
    fi
}

do_save() {
    local root="$1"
    local phase="$2"
    local sid="$3"
    validate_phase "$phase"

    if [[ -z "$sid" ]]; then
        echo -e "${RED}错误: SESSION_ID 不能为空${NC}" >&2
        exit 1
    fi

    local cdir
    cdir=$(require_cycle "$root")
    mkdir -p "${cdir}/sessions"

    echo "$sid" > "${cdir}/sessions/${phase}.session"
    touch_activity "$root"
    echo -e "${GREEN}已保存 ${phase} 的 SESSION_ID${NC}"
}

do_reset() {
    local root="$1"
    local phase="$2"
    validate_phase "$phase"

    local file
    file=$(session_file "$root" "$phase")

    if [[ -n "$file" && -f "$file" ]]; then
        rm "$file"
        echo -e "${YELLOW}已重置 ${phase} 的会话${NC}"
    else
        echo -e "${YELLOW}${phase} 无活跃会话${NC}"
    fi
}

do_reset_all() {
    local root="$1"
    local sdir
    sdir=$(current_sessions_dir "$root")

    if [[ -n "$sdir" && -d "$sdir" ]]; then
        rm -f "${sdir}"/*.session
        echo -e "${YELLOW}已重置所有阶段的会话${NC}"
    else
        echo -e "${YELLOW}无活跃会话${NC}"
    fi
}

do_complete() {
    local root="$1"
    local phase="$2"
    validate_phase "$phase"

    local file
    file=$(session_file "$root" "$phase")

    if [[ -n "$file" && -f "$file" ]]; then
        local timestamp
        timestamp=$(date "+%Y%m%d-%H%M%S")
        mv "$file" "${file%.session}.${timestamp}.archived"
        echo -e "${GREEN}已归档 ${phase} 的会话${NC}"
    else
        echo -e "${YELLOW}${phase} 无活跃会话，跳过归档${NC}"
    fi
}

do_complete_all() {
    local root="$1"
    local cdir
    cdir=$(current_cycle_dir "$root")

    if [[ -z "$cdir" ]]; then
        echo -e "${YELLOW}无活跃周期${NC}"
        return 0
    fi

    local sdir="${cdir}/sessions"
    local timestamp
    timestamp=$(date "+%Y%m%d-%H%M%S")
    local archived=0

    # 归档所有活跃 session
    if [[ -d "$sdir" ]]; then
        local phases=("plan-review" "code-review" "final-review")
        for phase in "${phases[@]}"; do
            local file="${sdir}/${phase}.session"
            if [[ -f "$file" ]]; then
                mv "$file" "${file%.session}.${timestamp}.archived"
                echo -e "${GREEN}  已归档 ${phase}${NC}"
                archived=$((archived + 1))
            fi
        done
    fi

    # 标记周期为 completed
    write_meta "$cdir" "status" "completed"
    write_meta "$cdir" "completed_at" "$(date '+%Y-%m-%dT%H:%M:%S')"

    # 清除指针
    rm -f "${root}/${POINTER_FILE}"

    echo -e "${GREEN}审查周期已关闭（归档 ${archived} 个会话）${NC}"
}

# ========== 过期检测（基于当前周期） ==========

do_check_stale() {
    local root="$1"
    local threshold_minutes="${2:-60}"
    local afile
    afile=$(activity_file "$root")

    if [[ -z "$afile" || ! -f "$afile" ]]; then
        echo "no-session"
        return 2
    fi

    local last_ts now_ts diff_seconds diff_minutes
    last_ts=$(cat "$afile")
    now_ts=$(date +%s)
    diff_seconds=$((now_ts - last_ts))
    diff_minutes=$((diff_seconds / 60))

    if [[ $diff_minutes -ge $threshold_minutes ]]; then
        local last_time
        last_time=$(date -r "$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        echo "stale|${diff_minutes}|${last_time}"
        return 0
    else
        echo "fresh|${diff_minutes}"
        return 1
    fi
}

do_auto_cleanup() {
    local root="$1"
    local threshold_minutes="${2:-60}"

    local cdir
    cdir=$(current_cycle_dir "$root")

    # 无活跃周期，无需处理
    if [[ -z "$cdir" ]]; then
        return 0
    fi

    local result exit_code
    result=$(do_check_stale "$root" "$threshold_minutes") && exit_code=$? || exit_code=$?

    # 无记录或仍活跃
    if [[ $exit_code -ne 0 ]]; then
        return 0
    fi

    # 过期：标记当前周期为 abandoned，清除指针
    local minutes last_time
    minutes=$(echo "$result" | cut -d'|' -f2)
    last_time=$(echo "$result" | cut -d'|' -f3)

    echo -e "${YELLOW}检测到过期周期（上次活动: ${last_time}，已闲置 ${minutes} 分钟）${NC}"
    write_meta "$cdir" "status" "abandoned"
    rm -f "${root}/${POINTER_FILE}"
    echo -e "${YELLOW}已标记为 abandoned，下次审查将创建新周期${NC}"
}

# ========== 状态展示 ==========

do_status() {
    local root="$1"
    local cycles_dir="${root}/${CYCLES_DIR}"

    echo "=== CC-Codex 审查状态 ==="
    echo "项目: ${root}"
    echo ""

    # 当前周期
    local cdir
    cdir=$(current_cycle_dir "$root")
    if [[ -n "$cdir" ]]; then
        local cycle_name
        cycle_name=$(read_current_cycle "$root")
        local desc
        desc=$(read_meta "$cdir" "description")
        local created
        created=$(read_meta "$cdir" "created_at")
        echo -e "  当前周期: ${GREEN}${cycle_name}${NC}"
        [[ -n "$desc" ]] && echo -e "  描述: ${desc}"
        [[ -n "$created" ]] && echo -e "  创建时间: ${created}"

        # 活动时间
        local afile
        afile=$(activity_file "$root")
        if [[ -n "$afile" && -f "$afile" ]]; then
            local last_ts now_ts diff_minutes last_time
            last_ts=$(cat "$afile")
            now_ts=$(date +%s)
            diff_minutes=$(( (now_ts - last_ts) / 60 ))
            last_time=$(date -r "$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$last_ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
            echo -e "  上次活动: ${last_time}（${diff_minutes} 分钟前）"
        fi
        echo ""

        # 各阶段会话状态
        local phases=("plan-review" "code-review" "final-review")
        for phase in "${phases[@]}"; do
            local file="${cdir}/sessions/${phase}.session"
            if [[ -f "$file" ]]; then
                local sid
                sid=$(cat "$file")
                echo -e "  ${phase}: ${GREEN}活跃${NC} (${sid:0:12}...)"
            else
                echo -e "  ${phase}: ${RED}无会话${NC}"
            fi
        done
        echo ""

        # 周期内文件
        [[ -f "${cdir}/plan.md" ]] && echo -e "  共识计划: ${GREEN}存在${NC}" || echo -e "  共识计划: ${RED}未创建${NC}"
        [[ -f "${cdir}/review-log.md" ]] && echo -e "  审查日志: ${GREEN}存在${NC}" || echo -e "  审查日志: ${RED}未创建${NC}"
    else
        echo -e "  当前周期: ${RED}无${NC}"
    fi

    echo ""

    # 历史周期统计
    if [[ -d "$cycles_dir" ]]; then
        local completed=0 abandoned=0
        while IFS= read -r dir_name; do
            [[ -z "$dir_name" ]] && continue
            local d="${cycles_dir}/${dir_name}"
            [[ ! -d "$d" ]] && continue
            local s
            s=$(read_meta "$d" "status")
            case "$s" in
                completed) completed=$((completed + 1)) ;;
                abandoned) abandoned=$((abandoned + 1)) ;;
            esac
        done < <(ls -1 "$cycles_dir" 2>/dev/null)

        # 从统计中排除当前活跃周期
        local current_name
        current_name=$(read_current_cycle "$root")
        echo -e "  历史周期: ${completed} 个已完成, ${abandoned} 个已废弃"
    fi
}

# ========== 参数校验与命令分发 ==========

if [[ -z "$ACTION" ]]; then
    usage
fi

if [[ -z "$PROJECT_ROOT" ]]; then
    echo -e "${RED}错误: 必须指定项目根目录${NC}" >&2
    usage
fi

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
    complete)
        [[ -z "$PHASE" ]] && usage
        do_complete "$PROJECT_ROOT" "$PHASE"
        ;;
    complete-all)
        do_complete_all "$PROJECT_ROOT"
        ;;
    check-stale)
        do_check_stale "$PROJECT_ROOT" "$PHASE"
        ;;
    auto-cleanup)
        do_auto_cleanup "$PROJECT_ROOT" "$PHASE"
        ;;
    cycle-init)
        do_cycle_init "$PROJECT_ROOT" "$PHASE"
        ;;
    cycle-current)
        do_cycle_current "$PROJECT_ROOT"
        ;;
    cycle-cleanup)
        do_cycle_cleanup "$PROJECT_ROOT" "$PHASE"
        ;;
    status)
        do_status "$PROJECT_ROOT"
        ;;
    *)
        echo -e "${RED}错误: 未知操作 '${ACTION}'${NC}" >&2
        usage
        ;;
esac