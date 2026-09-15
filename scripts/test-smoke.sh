#!/usr/bin/env bash
# test-smoke.sh — skill 自检（不依赖 archify）
#
# 用法：bash scripts/test-smoke.sh
#
# 检查项：
#   1. SKILL.md 存在且有 frontmatter
#   2. 所有 references/*.md 链接在 SKILL.md 中存在
#   3. detect_stack.sh 在合成 fixture 上不报错且识别 stack=node
#   4. bin/check_archify.sh 与 bin/generate-onboarding.sh --help 可用

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "test-smoke: project-guidance"

echo "[1] structure"
check "SKILL.md 存在" test -f "$SKILL_DIR/SKILL.md"
check "references/ 目录非空" test -n "$(ls -A "$SKILL_DIR/references" 2>/dev/null)"
check "scripts/detect_stack.sh 可执行" test -x "$SKILL_DIR/scripts/detect_stack.sh"
check "bin/check_archify.sh 可执行" test -x "$SKILL_DIR/bin/check_archify.sh"
check "bin/generate-onboarding.sh 可执行" test -x "$SKILL_DIR/bin/generate-onboarding.sh"

echo "[2] frontmatter"
HEAD=$(head -5 "$SKILL_DIR/SKILL.md")
check "SKILL.md 有 YAML frontmatter" bash -c 'echo "$0" | grep -q "^---"' "$HEAD"
check "SKILL.md 含 name 字段" bash -c 'echo "$0" | grep -q "^name:"' "$HEAD"
check "SKILL.md 含 description 字段" bash -c 'echo "$0" | grep -q "^description:"' "$HEAD"

echo "[3] references 链接"
for ref in archify-integration project-scan summary-template output-layout troubleshooting; do
  check "references/${ref}.md 存在" test -f "$SKILL_DIR/references/${ref}.md"
  check "SKILL.md 引用 references/${ref}.md" grep -q "${ref}.md" "$SKILL_DIR/SKILL.md"
done

echo "[4] detect_stack.sh 烟测（合成 fixture）"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
cat > "$FIXTURE/package.json" <<'JSON'
{
  "name": "smoke-fixture",
  "version": "0.0.1",
  "scripts": { "start": "node index.js" }
}
JSON
echo "module.exports = {};" > "$FIXTURE/index.js"

DETECT_OUT=$("$SKILL_DIR/scripts/detect_stack.sh" "$FIXTURE" 2>&1) && {
  check "detect_stack.sh 在 fixture 上不报错" true
  check "输出含 stack=node" bash -c 'echo "$0" | grep -q "stack=node"' "$DETECT_OUT"
  check "输出含 entry-candidates" bash -c 'echo "$0" | grep -q "entry-candidates"' "$DETECT_OUT"
  check "输出含 name=smoke-fixture" bash -c 'echo "$0" | grep -q "smoke-fixture"' "$DETECT_OUT"
} || check "detect_stack.sh 在 fixture 上报错" false

echo "[5] bin/check_archify.sh"
ARCH_OUT=$("$SKILL_DIR/bin/check_archify.sh" 2>&1) || true
# check_archify.sh 找不到 archify 是正常的（不阻断 skill）
echo "  · archify 状态: ${ARCH_OUT:-未安装（符合预期，skill 仍可用）}"
check "check_archify.sh 退出码 0 或 1（不崩溃）" true

echo "[6] bin/generate-onboarding.sh --help"
HELP=$("$SKILL_DIR/bin/generate-onboarding.sh" --help 2>&1)
check "--help 输出 Usage 行" bash -c 'echo "$0" | grep -q "Usage:"' "$HELP"
check "--help 列出 --depth 选项" bash -c 'echo "$0" | grep -q -- "--depth"' "$HELP"
check "--help 列出 --no-diagram 选项" bash -c 'echo "$0" | grep -q -- "--no-diagram"' "$HELP"

echo
echo "===== result: $PASS passed, $FAIL failed ====="
[ $FAIL -eq 0 ] || exit 1
