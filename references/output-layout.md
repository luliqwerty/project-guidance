# Output Layout — 产物布局与命名

## 1. 目录约定

所有产物落在 `<target_path>/docs/`。**禁止**写入 `<target_path>/` 顶层或污染源码。

```
<target_path>/
├── ...（原有项目文件，不动）
└── docs/                     # ← 导学产物全部在这里
    ├── onboarding.md         # 主交付物
    ├── architecture.html     # 架构图（必有）
    ├── architecture.json     # 中间产物（保留便于迭代）
    ├── workflow.html         # 业务流（depth ≥ standard）
    ├── workflow.json
    ├── sequence.html         # 时序（depth = deep）
    ├── sequence.json
    ├── data-flow.html        # 数据流（depth = deep）
    ├── data-flow.json
    ├── lifecycle.html        # 生命周期（depth = deep）
    └── lifecycle.json
```

如果 `<target_path>/docs/` 不存在 → 创建；如果存在但已有 `onboarding.md` → 提示用户是否覆盖，**默认覆盖并保留 .bak**。

## 2. onboarding.md 内部结构（固定）

```markdown
# <项目名> · 导学

> 生成于 YYYY-MM-DD · 参数：depth=<...> audience=<...> language=<...>

## 0. 项目速览
（4-6 行 + 关键事实卡片：语言 / 框架 / 入口 / 规模 / 启动命令）

## 1. 架构图
> 在浏览器中打开 [`architecture.html`](architecture.html) 获得交互体验（搜索 / 主题切换 / 导出 / 路径追溯）。
> 
> ![架构图](architecture.svg)（可选 PNG/SVG 备份）

## 2. 这个项目解决什么问题
…

## 3. 技术栈与决策
…

## 4. 目录结构导读
…

## 5. 核心模块拆解
…

## 6. 一个请求的生命周期
…

## 7. 上手工作流
…

## 8. 踩坑预警
…

## 9. 下一步建议
…

---
### 产物清单
- `docs/onboarding.md` — 本文档
- `docs/architecture.html` — 交互式架构图
- （按需列出其它图）
```

## 3. 嵌入 HTML 而非 PNG 的原因

- HTML 支持搜索 (`/`)、主题 (`T`)、节点跳转 (`SRC`)、导出 (`E`)——这是 PNG 做不到的。
- 邮件 / Wiki 不能渲染 HTML 时，让 archify 额外导出一份 PNG/SVG（`--export png` / `svg`）。
- Markdown 渲染器（如 GitHub）会把 HTML 折叠成链接，**保留"在浏览器中打开"提示语**。

## 4. 命名冲突处理

| 冲突 | 处理 |
|---|---|
| 已存在 `docs/onboarding.md` | 备份为 `docs/onboarding.md.bak.YYYYMMDD-HHMMSS` 后覆盖 |
| 已存在 `docs/architecture.html` | 同上备份后覆盖 |
| 用户禁止覆盖 | 写入 `<output_dir>/onboarding-<timestamp>.md` 并提示 |
| target_path 是 git 仓库 | 不自动 commit；文档末尾给出 `git add docs/ && git commit -m "docs: onboarding"` 建议 |

## 5. 多语种输出

- `language=zh-CN`（默认）：正文中文，专有名词括号注英文
- `language=en`：正文英文，技术名词保持原状
- 文件名不变（`onboarding.md`），不生成 `onboarding.zh.md` / `onboarding.en.md`——避免多版本不同步
- 若用户明确要双语，生成两份并加后缀：`onboarding.zh.md` / `onboarding.en.md`

## 6. 文档元信息块（每篇 onboarding.md 顶部必有）

```markdown
<!-- project-guidance-meta
target: <target_path>
language: <language>
depth: <depth>
audience: <audience>
generated_at: <ISO-8601>
generator: project-guidance v0.1.0 + archify
-->
```

HTML 注释，不影响渲染；下游工具可读取以做版本管理。