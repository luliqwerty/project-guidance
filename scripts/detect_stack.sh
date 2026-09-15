#!/usr/bin/env bash
# detect_stack.sh — 快速检测项目技术栈（只读）
# 用法：./detect_stack.sh <target_path>
# 输出：KV 行，agent 可直接 grep / awk 解析
# 退出码：0 始终返回（detect 失败也不阻断 skill）

set -eo pipefail

TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
  echo "ERROR target-not-dir path=$TARGET"
  exit 0
fi
TARGET="$(cd "$TARGET" && pwd)"

echo "target=$TARGET"

# 体积
SIZE=$(du -sh "$TARGET" 2>/dev/null | awk '{print $1}')
echo "size=${SIZE:-unknown}"

# Git?
if [ -d "$TARGET/.git" ]; then
  LAST=$(git -C "$TARGET" log -1 --pretty='%h %s' 2>/dev/null || echo "no-commit")
  echo "git=true last=$LAST"
else
  echo "git=false"
fi

# README? (大小写都查)
README_FOUND=""
for cand in README.md README.MD readme.md readme.MD README.txt readme.rst README.rst; do
  if [ -f "$TARGET/$cand" ]; then
    README_FOUND="$cand"
    break
  fi
done
if [ -n "$README_FOUND" ]; then
  echo "readme=true file=$README_FOUND"
else
  echo "readme=false"
fi

# 顶层结构
echo "top:"
ls -1A "$TARGET" 2>/dev/null | head -20 | sed 's/^/  - /'

# 栈识别（按优先级，单文件命中即停）
detect_node() {
  [ -f "$TARGET/package.json" ] || return 1
  echo "stack=node file=package.json"
  NAME=$(grep -m1 '"name"' "$TARGET/package.json" 2>/dev/null | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
  VER=$(grep -m1 '"version"' "$TARGET/package.json" 2>/dev/null | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
  echo "  name=$NAME version=$VER"
  grep -oE '"(next|nuxt|remix|vite|express|fastify|nest|react|vue|svelte|astro|solid-js|koa|hapi)"[[:space:]]*:[[:space:]]*"?[^",}]*' \
    "$TARGET/package.json" 2>/dev/null | head -5 \
    | sed -E 's/.*"([^"]+)".*/  framework-candidate=\1/'
  # scripts 段
  echo "  scripts:"
  awk '/"scripts"/,/}/' "$TARGET/package.json" 2>/dev/null | grep -oE '"[a-z]+"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -8 | sed 's/^/    /'
  return 0
}

detect_python() {
  if [ -f "$TARGET/pyproject.toml" ]; then
    echo "stack=python file=pyproject.toml"
    grep -E '^(name|version)' "$TARGET/pyproject.toml" 2>/dev/null | head -2 | sed 's/^/  /'
    grep -oE '(django|fastapi|flask|starlette|aiohttp|sanic|tornado|pyramid)' \
      "$TARGET/pyproject.toml" 2>/dev/null | head -3 | sort -u | sed 's/^/  framework-candidate=/'
    return 0
  fi
  if [ -f "$TARGET/setup.py" ]; then
    echo "stack=python file=setup.py"
    return 0
  fi
  if [ -f "$TARGET/requirements.txt" ]; then
    echo "stack=python file=requirements.txt"
    grep -oE '(django|fastapi|flask|starlette|aiohttp)' "$TARGET/requirements.txt" 2>/dev/null \
      | head -3 | sort -u | sed 's/^/  framework-candidate=/'
    return 0
  fi
  return 1
}

detect_go() {
  [ -f "$TARGET/go.mod" ] || return 1
  echo "stack=go file=go.mod"
  head -3 "$TARGET/go.mod" 2>/dev/null | sed 's/^/  /'
  grep -oE '(gin|echo|fiber|chi|gorilla/mux)' "$TARGET/go.mod" 2>/dev/null \
    | head -3 | sort -u | sed 's/^/  framework-candidate=/'
  return 0
}

detect_rust() {
  [ -f "$TARGET/Cargo.toml" ] || return 1
  echo "stack=rust file=Cargo.toml"
  grep -E '^(name|version)' "$TARGET/Cargo.toml" 2>/dev/null | head -2 | sed 's/^/  /'
  return 0
}

detect_java_maven() {
  [ -f "$TARGET/pom.xml" ] || return 1
  echo "stack=java-maven file=pom.xml"
  grep -oE '<artifactId>[^<]+</artifactId>' "$TARGET/pom.xml" 2>/dev/null | head -3 | sed 's/^/  /'
  return 0
}

detect_java_gradle() {
  { [ -f "$TARGET/build.gradle" ] || [ -f "$TARGET/build.gradle.kts" ]; } || return 1
  echo "stack=java-gradle file=build.gradle*"
  return 0
}

detect_ruby() { [ -f "$TARGET/Gemfile" ] && echo "stack=ruby file=Gemfile" && return 0 || return 1; }
detect_php() { [ -f "$TARGET/composer.json" ] && echo "stack=php file=composer.json" && return 0 || return 1; }
detect_dotnet() { ls "$TARGET"/*.csproj "$TARGET"/*.sln 2>/dev/null | head -1 | grep -q . && echo "stack=dotnet file=*.csproj" && return 0 || return 1; }
detect_elixir() { [ -f "$TARGET/mix.exs" ] && echo "stack=elixir file=mix.exs" && return 0 || return 1; }
detect_dart() { [ -f "$TARGET/pubspec.yaml" ] && echo "stack=dart file=pubspec.yaml" && return 0 || return 1; }

# 顺序敏感：单仓库多包时优先匹配更具体的栈
detect_node \
  || detect_python \
  || detect_go \
  || detect_rust \
  || detect_java_maven \
  || detect_java_gradle \
  || detect_ruby \
  || detect_php \
  || detect_dotnet \
  || detect_elixir \
  || detect_dart \
  || echo "stack=unknown"

# Monorepo 信号
for f in pnpm-workspace.yaml lerna.json nx.json turbo.json rush.json deno.json; do
  if [ -f "$TARGET/$f" ]; then
    echo "monorepo=true tool=$f"
    break
  fi
done

# 容器化
for f in Dockerfile docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$TARGET/$f" ]; then
    echo "container=true file=$f"
    break
  fi
done

# CI
[ -d "$TARGET/.github/workflows" ] && echo "ci=github-actions"
[ -f "$TARGET/.gitlab-ci.yml" ] && echo "ci=gitlab"
[ -f "$TARGET/.circleci/config.yml" ] && echo "ci=circleci"
[ -f "$TARGET/.buildkite/pipeline.yml" ] && echo "ci=buildkite"

# IaC
for f in terraform/ pulumi/ cdk.json serverless.yml; do
  if [ -e "$TARGET/$f" ]; then
    echo "iac=true hint=$f"
    break
  fi
done

# API 规范
for f in openapi.yaml openapi.json openapi.yml swagger.yaml swagger.json; do
  if [ -f "$TARGET/$f" ]; then
    echo "api-spec=true file=$f"
    break
  fi
done
shopt -s nullglob 2>/dev/null || true
PROTO_COUNT=0
for pat in "$TARGET"/*.proto "$TARGET"/proto/*.proto; do
  [ -e "$pat" ] && PROTO_COUNT=$((PROTO_COUNT + 1))
done
# 跳过深层 proto 扫描以免慢
[ "$PROTO_COUNT" -gt 0 ] && echo "api-spec=protobuf count=$PROTO_COUNT"
[ -f "$TARGET/schema.graphql" ] || [ -f "$TARGET/graphql/schema.graphql" ] && echo "api-spec=graphql"

# ORM / 数据库 schema
[ -f "$TARGET/prisma/schema.prisma" ] && echo "orm=prisma"
[ -f "$TARGET/drizzle.config.ts" ] || [ -f "$TARGET/drizzle.config.js" ] && echo "orm=drizzle"
[ -d "$TARGET/alembic/versions" ] && echo "orm=alembic"
[ -d "$TARGET/migrations" ] && echo "orm=migrations"

# 入口文件提示（声明式 + 启发式）
echo "entry-candidates:"
ENTRIES=()

# 策略 1：package.json 的 main / module / bin 声明
if [ -f "$TARGET/package.json" ]; then
  for field in main module bin; do
    VAL=$(grep -E "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$TARGET/package.json" 2>/dev/null \
          | head -1 | sed -E "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/" || true)
    if [ -n "$VAL" ] && [ -e "$TARGET/$VAL" ]; then
      ENTRIES+=("${VAL} (declared: $field)")
    fi
  done
fi

# 策略 2：常见入口模式
PATTERNS=(
  "src/index.ts" "src/index.js" "src/index.tsx" "src/index.jsx"
  "src/main.ts" "src/main.js" "src/main.tsx" "src/main.jsx"
  "src/main.py" "src/app.py" "main.py" "manage.py" "app.py" "server.py" "__main__.py"
  "src/main.go" "cmd/*/main.go" "main.go"
  "src/main.rs" "src/lib.rs" "src/bin/*.rs"
  "src/main/java/*/Application.java" "src/main/java/*/Main.java"
  "bin/*.rb" "lib/*.rb" "config/application.rb"
  "index.php" "public/index.php" "artisan"
  "lib/*/application.ex"
  "bin/main.dart" "lib/main.dart"
  "App.tsx" "App.jsx" "App.ts" "App.js"
  # 浏览器扩展 / WXT / Plasmo
  "src/entrypoints/background.ts" "src/entrypoints/background.js"
  "src/entrypoints/content.ts" "src/entrypoints/content.tsx"
  # 桌面 / Electron / Tauri
  "electron.{ts,js}" "src/main/index.{ts,js}" "src-tauri/src/main.rs"
)
for pat in "${PATTERNS[@]}"; do
  for hit in $TARGET/$pat; do
    [ -e "$hit" ] && ENTRIES+=("${hit#$TARGET/}")
    [ ${#ENTRIES[@]} -ge 8 ] && break 2
  done
done

SEEN_FILE=$(mktemp)
trap 'rm -f "$SEEN_FILE"' EXIT
for e in "${ENTRIES[@]}"; do
  if ! grep -Fxq "$e" "$SEEN_FILE" 2>/dev/null; then
    echo "$e" >> "$SEEN_FILE"
    echo "  - $e"
  fi
done
[ ${#ENTRIES[@]} -eq 0 ] && echo "  - (none auto-detected)"

echo "done"