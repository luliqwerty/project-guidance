# Project Scan — 多语言项目扫描策略

本文件定义 Phase 1 的扫描动作。原则：**只读**，最大化信息密度，最小化 token 消耗。

## 1. 通用前置（任何栈都执行）

```bash
# 项目根的快速指纹
ls -la <target_path>
# 取 README / LICENSE / 顶层 5 个文件
ls <target_path> | head -20
# 最近一次提交信息（如果 git 仓库）
git -C <target_path> log -1 --pretty='%h %s (%ad)' --date=short 2>/dev/null
# 项目体积
du -sh <target_path> 2>/dev/null
```

读取（按优先级，单文件 ≤ 200 行）：

| 文件 | 用途 |
|---|---|
| `README*` / `readme*` | 业务背景、快速开始 |
| `LICENSE` | 法律信息（导学文档不强调） |
| `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `pom.xml` / `build.gradle*` | 元数据 + 依赖 |
| `.env.example` / `.env.sample` / `config/*.example.*` | 配置项 |
| `Dockerfile` / `docker-compose*.yml` / `Makefile` / `justfile` / `Taskfile*` | 构建与运行 |
| `CHANGELOG*` / `docs/` 顶层 | 历史与约定 |
| `*.code-workspace` / `.vscode/launch.json` | 调试配置 |

## 2. 按栈分支

### Node.js / TypeScript

- 读 `package.json` 的 `scripts` 段 → 提取 `dev` / `build` / `start` / `test` / `lint`
- 读 `package.json` 的 `dependencies` / `devDependencies` → 技术栈
- 判断框架：`next` / `nuxt` / `remix` / `vite` / `nest` / `express` / `fastify` / `koa`
- 入口：`main` / `module` 字段；或 `src/index.{js,ts}` / `app.{js,ts}`
- 配置：`tsconfig.json` 路径别名、`next.config.*` / `vite.config.*` / `nuxt.config.*`
- 测试：`vitest.config.*` / `jest.config.*` / `playwright.config.*`

### Python

- 读 `pyproject.toml`（PEP 621）或 `setup.py` / `setup.cfg`
- 框架：`django` / `fastapi` / `flask` / `starlette` / `sanic` / `aiohttp`
- 入口：`__main__.py` / `manage.py` / `main.py` / `app.py`
- 依赖管理：`poetry.lock` / `Pipfile.lock` / `requirements.txt`
- 任务：`tox.ini` / `noxfile.py` / `Makefile`

### Go

- `go.mod` 的 `module` 路径与 go 版本
- `cmd/<name>/main.go` 是入口
- 内部包：`internal/` vs `pkg/`
- 框架：`gin` / `echo` / `fiber` / `chi`

### Rust

- `Cargo.toml` 的 `[[bin]]` / `[lib]` 段
- `src/main.rs` / `src/lib.rs`
- 框架：`actix` / `axum` / `rocket` / `warp`

### Java / Kotlin / Scala

- `pom.xml` 的 `<artifactId>` / `<dependencies>` / `<build>`
- `build.gradle*` 的 `dependencies { ... }` / `application` 插件
- `settings.gradle*` 的 `rootProject.name`
- 入口：`src/main/java/.../Application.java` / `*.kt`

### 移动端

- `ios/` → `Podfile` / `*.xcodeproj` / `*.xcworkspace`
- `android/` → `build.gradle` / `AndroidManifest.xml`
- 跨端：`react-native` / `flutter` / `capacitor` / `ionic`

### 单仓库多包（Monorepo）

- 识别工具：`pnpm-workspace.yaml` / `lerna.json` / `nx.json` / `turbo.json` / `rush.json`
- 包根：`packages/*` / `apps/*` / `services/*`
- 重点扫"启动哪一个包能代表整个项目"的那个子目录

## 3. 提取输出（写回 onboarding.md §0）

固定字段：

```
项目名：<name>
一句话定位：<从 README 第一段抽>
版本：<version>
主语言：<language>（占比估算：...）
框架：<framework>
入口：<entry_file>
启动命令：<command>
测试命令：<command>
构建命令：<command>
依赖管理：<tool>
```

未识别字段填"未识别（请人工补充）"，绝不伪造。

## 4. 高级信号（可选，深度模式用）

- 是否有 CI：`<target>/.github/workflows/` / `.gitlab-ci.yml` / `circle.yml` / `.buildkite/`
- 是否有 IaC：`terraform/` / `pulumi/` / `cdk/` / `cloudformation/`
- 是否有 API 规范：`openapi.*` / `swagger.*` / `*.proto` / `*.graphql`
- 是否有数据库 schema：`prisma/schema.prisma` / `migrations/` / `alembic/versions/`
- 是否有多语言模块：`.go` 与 `.py` / `.rs` 同存 → 提示用户确认是混合栈
- 监控/日志：`grafana/` / `dashboards/` / `alerts.yml` / OpenTelemetry 配置

## 5. 常见坑

| 现象 | 处理 |
|---|---|
| 仓库 > 5GB | 跳过 `node_modules` / `target/` / `.venv` 等构建产物目录 |
| 没有 README | 强提示"项目无 README，建议生成"；改用 `package.json` 的 `description` |
| 多语言项目 | 先识别主导语言（按文件数），次要语言作为"模块依赖"列出 |
| monorepo 几十个包 | 只扫描 `package.json` 顶层 + `pnpm-workspace.yaml`，子包按需求细化 |
| 没有 git 仓库 | 跳过提交历史相关字段；不报错 |