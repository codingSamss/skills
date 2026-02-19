#!/usr/bin/env bash
set -euo pipefail

echo "=== orbit-os setup ==="
echo "Checking Obsidian vault..."

VAULT_PATH="$HOME/Documents/Obsidian Vault"
if [ ! -d "$VAULT_PATH" ]; then
  echo "Creating vault directory: $VAULT_PATH"
  mkdir -p "$VAULT_PATH"
fi

DIRS=(
  "00_收件箱"
  "10_日记"
  "20_项目"
  "30_研究"
  "40_知识库"
  "50_资源/Newsletters"
  "50_资源/产品发布"
  "90_计划/Archives"
  "99_系统/模板"
  "99_系统/提示词"
  "99_系统/归档/项目"
  "99_系统/归档/收件箱"
)

for dir in "${DIRS[@]}"; do
  target="$VAULT_PATH/$dir"
  if [ ! -d "$target" ]; then
    mkdir -p "$target"
    echo "  Created: $dir"
  fi
done

echo "Vault ready at: $VAULT_PATH"
echo "=== orbit-os setup complete ==="
