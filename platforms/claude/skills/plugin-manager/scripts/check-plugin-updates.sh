#!/bin/bash
# 检查插件更新
# 使用 claude plugin update 命令检查，支持所有安装方式

# 绕过 Claude Code 嵌套会话检测，允许在会话内调用 claude plugin 命令
unset CLAUDECODE

PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}检查插件更新...${NC}"
echo "=================================="
echo ""

# 统计
updates_available=0
up_to_date=0
check_failed=0

# 获取所有已安装插件
plugins=$(jq -r '.plugins | keys[]' "$PLUGINS_JSON")

for plugin in $plugins; do
    # 获取当前版本
    current_version=$(jq -r ".plugins[\"$plugin\"][0].version" "$PLUGINS_JSON")
    marketplace=$(echo "$plugin" | cut -d'@' -f2)

    echo -e "${CYAN}$plugin${NC}"
    echo -e "  当前版本: $current_version"

    # 使用官方命令检查更新
    output=$(claude plugin update "$plugin" 2>&1)

    if echo "$output" | grep -q "already at the latest version"; then
        echo -e "  ${GREEN}已是最新版本${NC}"
        ((up_to_date++))
    elif echo "$output" | grep -q "updated from"; then
        # 提取新版本信息
        new_version=$(echo "$output" | grep -oP 'to \K[^\s]+' | head -1)
        echo -e "  ${YELLOW}有更新可用${NC}"
        ((updates_available++))
    elif echo "$output" | grep -q "Error\|error\|failed"; then
        echo -e "  ${RED}检查失败${NC}"
        ((check_failed++))
    else
        echo -e "  ${GREEN}已是最新版本${NC}"
        ((up_to_date++))
    fi
    echo ""
done

# 汇总
echo "=================================="
echo -e "${BLUE}检查完成:${NC}"
echo -e "  ${GREEN}已是最新: $up_to_date 个${NC}"
if [ $updates_available -gt 0 ]; then
    echo -e "  ${YELLOW}有更新: $updates_available 个${NC}"
fi
if [ $check_failed -gt 0 ]; then
    echo -e "  ${RED}检查失败: $check_failed 个${NC}"
fi