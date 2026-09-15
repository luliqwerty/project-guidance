---
name: project-guidance
description: 项目导学技能 — 为任意代码仓库生成新人入职导学材料。核心产物是结构化的 Markdown 导学文档（docs/onboarding.md）；若 archify 可用则可选生成交互式架构图（docs/architecture.html）。Use this skill when the user says "做项目导学"、"项目导读"、"生成导学文档"、"新人引导"、"onboarding"、"project guide"，或需要为不熟悉的项目快速生成上手材料时。
metadata:
  version: "0.5.0"
  language_default: "zh-CN"
  depends_on:
    - archify (optional, tt-a1i/archify v0.13+) — 仅用于生成架构图
---

# Project Guidance — 项目导学技能

把任意代码仓库在数分钟内变成一份让新人"读完即上手"的导学材料。

**核心设计**：

- **主产物**：`docs/onboarding.md` — 结构化 Markdown 导学文档（**必出**，不依赖 archify）。
- **可选产物**：`docs/architecture.html` — 交互式架构图（仅当 archify 可用时生成）。

两层做法：

1. **导学文档（Text Layer — 主）** — agent 直接读源码抽取要点，按统一模板组织为 Markdown。
2. **架构图（Visual Layer — 选）** — 若 [archify](https://github.com/tt-a1i/archify) 可用且需要，生成可交互 HTML（5 种图类型：Architecture / Workflow / Sequence / Data Flow / Lifecycle）。

---

## 触发条件

满足任意一条即可触发：

- 用户说："为 XXX 项目做导学"、"生成项目导学文档"、"这个项目怎么上手"、"写一份新人 onboarding"
- 用户提供了项目路径并要求总结 / 介绍 / 概览
- 用户提到 "archify"、"架构图 + 总结" 的组合需求

不需要触发：

- 用户只要架构图（直接调用 archify，本 skill 不挡）
- 用户只要改某个具体模块（普通编码任务）

---

## 入参约定

| 参数 | 默认 | 说明 |
|---|---|---|
| `target_path` | 当前工作目录 | 要导学的项目根路径 |
| `language` | `zh-CN` | 导学文档语言（`zh-CN` / `en`） |
| `output_dir` | `<target_path>/docs` | 产物输出目录 |
| `include_architecture_diagram` | `auto` | `yes` / `no` / `auto`（archify 可用则生成，否则跳过并在文档中说明） |
| `diagram_types` | `["architecture"]` | architecture / workflow / sequence / data-flow / lifecycle |
| `depth` | `standard` | `quick`（核心 5 模块）/ `standard`（默认）/ `deep`（含数据流、时序、子模块） |
| `audience` | `newcomer` | `newcomer`（新人）/ `cross-team`（跨团队）/ `reviewer`（评审者） |

缺失必填项时，使用默认值并在文档头部记录"本次生成采用的参数"。

---

## 执行流程（必读）

整个 skill 是一个 **Plan → Do · Check · Act** 循环。任何一步失败都不能跳过，必须就地修复或要求用户决策。

### Phase 0 — 环境检查（archify 检测，不阻断）

调 `bin/check_archify.sh`，按以下顺序查找 archify：

1. `PATH` 中是否有 `archify` 可执行
2. 全局 npm 安装：`$(npm root -g)/archify/bin/archify.mjs`
3. 常见 skill 目录：`$HOME/.agents/skills/archify/`、`$HOME/.claude/skills/archify/`、`$HOME/.skills/archify/`
4. 环境变量 `ARCHIFY_BIN` 显式指定

- **archify 可用** → 跑 `doctor` 自检，记 `INCLUDE_DIAGRAM=true`
- **archify 不可用** → 提示用户可安装（`npm i -g archify`），但**不阻断** — onboarding.md 才是核心产物。记 `INCLUDE_DIAGRAM=false`
- **`--no-diagram` 显式传入** → `INCLUDE_DIAGRAM=false`

### Phase 1 — 项目扫描（Project Scan，必做）

读取 [references/project-scan.md](references/project-scan.md) 中定义的扫描策略，按栈类型分类执行。**只读不写**。

产出：

- 项目名、版本、简介（来自 README / package.json / Cargo.toml / pyproject.toml 等）
- 技术栈语言与框架
- 顶层目录结构（一棵树，深度 ≤ 3）
- 入口文件 / 启动命令
- 依赖列表（按运行时 / 开发分类）
- 构建 / 测试 / 运行命令
- 已知配置项 / 环境变量
- 外部依赖（数据库、缓存、消息队列、云服务等）

可借助 `scripts/detect_stack.sh` 拿到机器可读的栈指纹（写入 `<out>/detect.txt`）。

### Phase 2 — 导学文档生成（必做 — **主输出**）

读取 [references/summary-template.md](references/summary-template.md) 与 [references/output-layout.md](references/output-layout.md)，按 6 个固定维度梳理，**不是简单列文件，而是讲"为什么"和"怎么用"**：

1. **这个项目解决什么问题** — 业务背景、目标用户、核心价值
2. **技术决策** — 为什么选这个栈、关键 trade-off
3. **核心模块拆解** — 每个模块的职责、依赖、入口（≤ 8 个，按重要性排序）
4. **请求 / 数据流** — 一个端到端的例子（用户操作 → 系统响应）
5. **开发工作流** — 环境准备、首次运行、热重载、调试
6. **踩坑预警** — 配置陷阱、外部依赖、性能瓶颈、常见报错

组装最终 markdown，固定结构见 `references/output-layout.md`。

### Phase 3 — 架构图生成（仅当 `INCLUDE_DIAGRAM=true`）

读取 [references/archify-integration.md](references/archify-integration.md)。要点：

1. **生成 typed JSON IR** — agent 先在内存中构造完整 JSON，再交给 CLI
2. **校验** — `archify validate <json> --quality <q> --json`，按 `supportedFixes` 修复，最多两轮
3. **交付** — `archify deliver <json> <output.html> --quality <q>`，失败保留 JSON + diagnostics

附加图（按 `diagram_types` 与项目特性）：workflow / sequence / data-flow / lifecycle。深度 ≥ `standard` 时按需生成。

**`INCLUDE_DIAGRAM=false` 时**：跳过此 phase，在 onboarding.md §1 写明：

```markdown
## 1. 架构图

> 本次未生成交互式架构图（archify 不可用 / 用户跳过）。
> 安装：`npm i -g archify` 或 `npx skills add tt-a1i/archify -g -y`，重跑本 skill 即可附加。
```

### Phase 4 — 自检（Self-Check，必做）

结束前回答下面 5 个问题，任何一个答不上来都要回去补：

1. 一个完全没见过这个项目的人读完 onboarding.md，能在 30 分钟内 `git clone && <启动命令>` 把项目跑起来吗？
2. （若生成了架构图）HTML 在浏览器里打开能正常切换主题 / 搜索节点 / 导出吗？
3. 文档里所有"在哪看"的文件路径，是否都真实存在？
4. 文档是否避免了直接复制大段代码（而是讲清"看哪里、为什么"）？
5. 文档语言、术语是否一致（中英混排时给出括注）？

---

## 资源引用

- [references/project-scan.md](references/project-scan.md) — 多语言项目扫描策略
- [references/archify-integration.md](references/archify-integration.md) — archify CLI 与 JSON IR 对接（可选）
- [references/summary-template.md](references/summary-template.md) — 要点梳理模板
- [references/output-layout.md](references/output-layout.md) — 产物布局与命名
- [references/troubleshooting.md](references/troubleshooting.md) — 常见失败模式与回退
- [scripts/detect_stack.sh](scripts/detect_stack.sh) — 项目栈快速检测（只读）
- [scripts/test-smoke.sh](scripts/test-smoke.sh) — skill 自检
- [bin/check_archify.sh](bin/check_archify.sh) — archify 安装检测
- [bin/generate-onboarding.sh](bin/generate-onboarding.sh) — 编排入口

---

## 全局纪律

1. **Markdown 优先** — onboarding.md 是必出产物；架构图是锦上添花。
2. **archify 可选** — 不可用不阻断，不假装生成了图，文档中诚实说明。
3. **只读优先** — Phase 1/2 不修改任何目标项目文件。
4. **本地产物** — 产物全部落在 `target_path/docs/`，绝不污染项目源码。
5. **路径锚定** — 文档里每个引用都要写绝对或相对路径，新人 `Ctrl+Click` 能跳过去。
6. **不可生成内容时显式说明** — 比如"未找到 README"，不要伪造。
7. **尊重用户语言** — 默认中文；用户切换英文时整体跟随，但保留专有名词原文。

## 反模式（不要做）

- ❌ archify 不可用时假装生成了架构图
- ❌ 直接 `cat README.md` 然后原样粘进导学文档（要二次加工）
- ❌ 用 mermaid 块代替交互式架构图（除非用户明确要求）
- ❌ 模块清单超过 10 个（要排序与合并）
- ❌ 在导学文档里写"建议看下 xxx 文件"但不解释为什么
- ❌ 把架构图、要点、目录结构分到三个完全独立的文档（合并阅读才有用）
