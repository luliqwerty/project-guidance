#!/usr/bin/env bash
# generate-onboarding.sh — 项目导学 skill 的编排器（agent 调用入口）
#
# 用法：
#   bin/generate-onboarding.sh <target_path> [options]
#
# Options:
#   --output-dir <dir>     产物输出目录（默认 <target>/docs）
#   --depth <level>        quick | standard | deep（默认 standard）
#   --language <locale>    zh-CN | en（默认 zh-CN）
#   --type <type>          architecture | workflow | sequence | dataflow | lifecycle（可重复）
#   --run                  立即跑 validate + deliver（默认只生成脚手架）
#   --no-diagram           跳过架构图（即便 archify 可用）
#   --archify <path>       显式指定 archify CLI 路径
#   -h | --help            显示本帮助
#
# 行为：
#   1. archify 检测（可选，不阻断 — 核心产物是 onboarding.md）
#   2. detect_stack.sh → 写入 <out>/detect.txt
#   3. 生成 <type>.json 脚手架（archify 可用时）
#   4. --run + archify 可用时跑 validate + deliver
#
# 内容（onboarding.md）由 agent 根据 references/summary-template.md 编写，本脚本不做。

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET=""
OUTPUT_DIR=""
DEPTH="standard"
LANGUAGE="zh-CN"
DIAGRAM_TYPES=(architecture)
RUN_NOW=false
SKIP_DIAGRAM=false
ARCHIFY_CMD=""

usage() {
  cat <<EOF
Usage: $(basename "$0") <target_path> [options]

Options:
  --output-dir <dir>     产物输出目录（默认 <target>/docs）
  --depth <level>        quick | standard | deep（默认 standard）
  --language <locale>    zh-CN | en（默认 zh-CN）
  --type <type>          architecture | workflow | sequence | dataflow | lifecycle（可重复）
  --run                  立即跑 validate + deliver（默认只生成脚手架）
  --no-diagram           跳过架构图生成（即便 archify 可用）
  --archify <path>       显式指定 archify CLI 路径
  -h | --help            显示本帮助
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --type) DIAGRAM_TYPES+=("$2"); shift 2 ;;
    --run) RUN_NOW=true; shift ;;
    --no-diagram) SKIP_DIAGRAM=true; shift ;;
    --archify) ARCHIFY_CMD="node $2"; shift 2 ;;
    -*) echo "unknown option: $1" >&2; usage; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

[ -z "$TARGET" ] && { echo "ERROR: target_path required" >&2; exit 2; }
[ ! -d "$TARGET" ] && { echo "ERROR: target not a directory: $TARGET" >&2; exit 2; }

OUTPUT_DIR="${OUTPUT_DIR:-$(cd "$TARGET" && pwd)/docs}"
mkdir -p "$OUTPUT_DIR"

# ---- Step 1: archify 检测（不阻断） ----
echo "[1/4] 检测 archify"
if [ "$SKIP_DIAGRAM" = true ]; then
  echo "      → --no-diagram，跳过架构图"
  ARCHIFY_CMD=""
elif [ -z "$ARCHIFY_CMD" ]; then
  ARCHIFY_CMD=$("$SKILL_DIR/bin/check_archify.sh" 2>/dev/null || true)
fi

if [ -n "$ARCHIFY_CMD" ]; then
  echo "      archify: $ARCHIFY_CMD"
  if bash -c "$ARCHIFY_CMD doctor" > /tmp/archify-doctor.txt 2>&1; then
    if grep -q "Archify is ready" /tmp/archify-doctor.txt; then
      echo "      [ok] doctor 通过"
    else
      echo "      [warn] doctor 输出异常，架构图可能失败"
    fi
  else
    echo "      [warn] doctor 失败，回退为不生成架构图"
    ARCHIFY_CMD=""
  fi
else
  echo "      [info] archify 不可用 — 仅产出 onboarding.md"
  echo "             安装方式: npm i -g archify  或  npx skills add tt-a1i/archify -g -y"
fi

# ---- Step 2: 项目探测 ----
echo "[2/4] detect_stack.sh $TARGET"
"$SKILL_DIR/scripts/detect_stack.sh" "$TARGET" > "$OUTPUT_DIR/detect.txt" 2>&1
echo "      → $OUTPUT_DIR/detect.txt"

# ---- Step 3: 生成 IR 脚手架（仅 archify 可用时） ----
echo "[3/4] scaffold JSON IR"
QUALITY="standard"
[ "$DEPTH" = "deep" ] && QUALITY="showcase"

if [ -n "$ARCHIFY_CMD" ]; then
  for TYPE in "${DIAGRAM_TYPES[@]}"; do
    IR_FILE="$OUTPUT_DIR/${TYPE//-/_}.json"
    if [ -f "$IR_FILE" ]; then
      echo "      · $IR_FILE (exists, skipping)"
      continue
    fi
    cat > "$IR_FILE" <<EOF
{
  "schema_version": 1,
  "diagram_type": "$TYPE",
  "meta": {
    "title": "<fill-me>",
    "quality_profile": "$QUALITY",
    "locale": "$LANGUAGE"
  },
  "components": [],
  "connections": []
}
EOF
    echo "      · $IR_FILE (scaffold written)"
  done
else
  echo "      · (skipped — archify 不可用)"
fi

# ---- Step 4: 可选立即渲染 ----
if [ "$RUN_NOW" = true ] && [ -n "$ARCHIFY_CMD" ]; then
  echo "[4/4] archify validate + deliver"
  for TYPE in "${DIAGRAM_TYPES[@]}"; do
    IR_FILE="$OUTPUT_DIR/${TYPE//-/_}.json"
    HTML_FILE="$OUTPUT_DIR/${TYPE//-/_}.html"
    bash -c "$ARCHIFY_CMD validate $TYPE $IR_FILE --quality $QUALITY --json" \
      > "$OUTPUT_DIR/${TYPE//-/_}.diag.json" 2>&1 || true
    bash -c "$ARCHIFY_CMD deliver $TYPE $IR_FILE $HTML_FILE --quality $QUALITY" \
      && echo "      · delivered $HTML_FILE" \
      || echo "      · deliver failed for $IR_FILE (see ${TYPE//-/_}.diag.json)"
  done
else
  if [ -n "$ARCHIFY_CMD" ]; then
    echo "[4/4] (skip) pass --run to invoke validate + deliver after agent fills IR"
  else
    echo "[4/4] (skip) archify 不可用 — 仅产出 onboarding.md（由 agent 撰写）"
  fi
fi

echo
echo "Done. Next:"
if [ -n "$ARCHIFY_CMD" ]; then
  echo "  1. Edit $OUTPUT_DIR/${DIAGRAM_TYPES[0]//-/_}.json with real architecture"
  echo "  2. Run: $0 $TARGET --run --type ${DIAGRAM_TYPES[0]}"
  echo "  3. Write $OUTPUT_DIR/onboarding.md per references/summary-template.md"
else
  echo "  1. Write $OUTPUT_DIR/onboarding.md per references/summary-template.md (主产物)"
  echo "  2. 可选：安装 archify 后重跑以追加 architecture.html"
fi
