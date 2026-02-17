#!/bin/bash
# 批量更新插件脚本
# 直接调用官方命令，检测并更新

# 绕过 Claude Code 嵌套会话检测，允许在会话内调用 claude plugin 命令
unset CLAUDECODE

PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 更新所有插件
update_all_plugins() {
    local updated=0
    local already_latest=0
    local failed=0

    echo -e "${BLUE}正在检查并更新所有插件...${NC}"
    echo ""

    # 获取所有已安装插件
    local plugins=$(jq -r '.plugins | keys[]' "$PLUGINS_JSON")

    for plugin in $plugins; do
        echo -e "${YELLOW}检查:${NC} $plugin"

        # 调用官方命令更新
        output=$(claude plugin update "$plugin" 2>&1)

        if echo "$output" | grep -q "already at the latest version"; then
            echo -e "  ${GREEN}已是最新${NC}"
            ((already_latest++))
        elif echo "$output" | grep -q "updated from"; then
            echo -e "  ${GREEN}已更新${NC}"
            ((updated++))
        else
            echo -e "  ${RED}失败: $output${NC}"
            ((failed++))
        fi
        echo ""
    done

    # 汇总
    echo "=================================="
    echo -e "更新完成:"
    echo -e "  ${GREEN}已更新: $updated 个${NC}"
    echo -e "  已是最新: $already_latest 个"
    if [ $failed -gt 0 ]; then
        echo -e "  ${RED}失败: $failed 个${NC}"
    fi

    if [ $updated -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}请重启 Claude Code 以应用更改${NC}"
    fi
}

# 更新指定插件
update_single() {
    local plugin="$1"
    echo -e "${BLUE}正在更新 $plugin ...${NC}"
    claude plugin update "$plugin" 2>&1
}

# 主逻辑
case "$1" in
    ""|--all|-a)
        update_all_plugins
        ;;
    *)
        update_single "$1"
        ;;
esac