#!/usr/bin/env bash
# check_archify.sh — 检测 archify 是否已安装
#
# 用法（在脚本中）：
#   ARCHIFY=$(bin/check_archify.sh) || ARCHIFY=""
#   if [ -n "$ARCHIFY" ]; then ... fi
#
# 输出：archify 启动命令字符串（可能含 `node` 前缀）；未找到时输出空，退出码非零。
#
# 查找顺序（命中即返回）：
#   1. PATH 里直接有 `archify`
#   2. 全局 npm 安装：$(npm root -g)/archify/bin/archify.mjs
#   3. 常见 skill 目录：$HOME/.agents/skills/archify/bin/archify.mjs 等
#   4. 环境变量 ARCHIFY_BIN 显式指定

set -e

# 1) PATH
if command -v archify >/dev/null 2>&1; then
  echo "archify"
  exit 0
fi

# 2) 全局 npm
NPM_GLOBAL=$(npm root -g 2>/dev/null || true)
if [ -n "$NPM_GLOBAL" ] && [ -f "$NPM_GLOBAL/archify/bin/archify.mjs" ]; then
  echo "node $NPM_GLOBAL/archify/bin/archify.mjs"
  exit 0
fi

# 3) 常见 skill 安装目录
for candidate in \
  "$HOME/.agents/skills/archify/bin/archify.mjs" \
  "$HOME/.claude/skills/archify/bin/archify.mjs" \
  "$HOME/.skills/archify/bin/archify.mjs"; do
  if [ -f "$candidate" ]; then
    echo "node $candidate"
    exit 0
  fi
done

# 4) 显式 ARCHIFY_BIN
if [ -n "$ARCHIFY_BIN" ] && [ -f "$ARCHIFY_BIN" ]; then
  echo "node $ARCHIFY_BIN"
  exit 0
fi

# 未找到
exit 1
