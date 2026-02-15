#!/bin/bash
set -euo pipefail

NEED_MANUAL=0
PROXY_HTTP="${HTTP_PROXY:-http://127.0.0.1:7897}"
PROXY_HTTPS="${HTTPS_PROXY:-http://127.0.0.1:7897}"

echo "[bird-twitter] 检查 Bird CLI..."
if command -v bird >/dev/null 2>&1; then
  echo "[bird-twitter] Bird CLI 已安装"
else
  if command -v brew >/dev/null 2>&1; then
    echo "[bird-twitter] 安装 Bird CLI"
    brew install steipete/tap/bird
  else
    echo "[bird-twitter] 未检测到 Homebrew，请手动安装: brew install steipete/tap/bird"
    NEED_MANUAL=1
  fi
fi

if command -v bird >/dev/null 2>&1; then
  if HTTP_PROXY="$PROXY_HTTP" HTTPS_PROXY="$PROXY_HTTPS" \
       bird --cookie-source chrome --timeout 15000 whoami >/dev/null 2>&1; then
    echo "[bird-twitter] Bird 认证已就绪"
  else
    echo "[bird-twitter] Bird 认证检查失败，请先确认："
    echo "  1) Chrome 已登录 X/Twitter"
    echo "  2) 代理可用（HTTP_PROXY/HTTPS_PROXY），默认尝试: http://127.0.0.1:7897"
    echo "  3) 可手动验证:"
    echo "     HTTP_PROXY=$PROXY_HTTP HTTPS_PROXY=$PROXY_HTTPS bird --cookie-source chrome --timeout 15000 whoami"
    NEED_MANUAL=1
  fi
fi

if [ "$NEED_MANUAL" -eq 1 ]; then
  exit 2
fi
