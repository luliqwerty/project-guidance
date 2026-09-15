# Archify Integration — 与 archify 对接（可选）

> 本文件以 [archify SKILL.md](https://github.com/tt-a1i/archify) 与本地安装的 `schemas/*.schema.json` 为 ground truth，任何字段冲突以 archify 为准。
>
> **重要**：archify 在本 skill 中是**可选**。仅当需要生成交互式架构图时才走本文件的流程；不需要时直接走 [SKILL.md](../SKILL.md) 的 Phase 2 即可。

## 0. 检测与路径

不要硬编码 archify 路径，统一调 `bin/check_archify.sh`：

```bash
ARCHIFY=$(bin/check_archify.sh) || ARCHIFY=""
if [ -z "$ARCHIFY" ]; then
  echo "archify 未安装 — 跳过架构图生成"
fi
```

`check_archify.sh` 按以下顺序查找：

1. `PATH` 中的 `archify`
2. `$(npm root -g)/archify/bin/archify.mjs`
3. `$HOME/.agents/skills/archify/bin/archify.mjs` 等常见目录
4. 环境变量 `ARCHIFY_BIN`

## 1. 健康检查

```bash
# 仅在 ARCHIFY 非空时执行
[ -n "$ARCHIFY" ] && bash -c "$ARCHIFY doctor"
```

期望输出形如 `[ok] Archify is ready.`，任何 `✗` 都必须先解决。

## 2. CLI 速查（实际命令）

```
archify render <type> <input.json> [output.html] [--quality standard|showcase] [--repo-root path]
archify validate <type> <input.json> [--json] [--layout-json] [--quality standard|showcase] [--repo-root path]
archify deliver <type> <input.json> [output.html] [--json] [--open] [--quality standard|showcase] [--repo-root path]
archify preview <type> <input.json> [output.html] [--quality standard|showcase] [--repo-root path]
archify inspect <type> <input.json>
archify check <output.html]
archify visual-check <output.html] [--json]
archify migrate workflow <old.json> <new.json> --to-schema 2 [--json]
archify compare architecture <base.json> <head.json> [output.html]
archify guide [scenario] [--lang en|zh]
archify demo [output-directory]
```

`<type>` 取值：`architecture | workflow | sequence | dataflow | lifecycle`（注意 `dataflow` 单数，不是 `data-flow`）。

**本 skill 推荐组合**：`validate` 校验 → `deliver` 出 HTML → `visual-check` 自检（可选）。

## 3. JSON IR（typed Intermediate Representation）

archify 接收 typed JSON IR。本 skill 的 agent **必须先在内存中构造完整 JSON，再交给 CLI**，不要让 CLI 自己猜。

### 3.1 顶层结构

```json
{
  "schema_version": 1,
  "diagram_type": "architecture",
  "meta": { ... },
  "components": [ ... ],
  "boundaries": [ ... ],
  "connections": [ ... ],
  "cards": [ ... ],
  "views": [ ... ]
}
```

字段总览：

| 字段 | 必有 | 说明 |
|---|---|---|
| `schema_version` | ✓ | 1（architecture/sequence/dataflow/lifecycle）或 2（workflow 新版） |
| `diagram_type` | ✓ | 同 CLI `<type>` |
| `meta` | ✓ | 标题 / locale / 视图等 |
| `components` | ✓ | 节点数组 |
| `boundaries` | × | 区域 / 安全组包裹（architecture 才有） |
| `connections` | ✓ | 关系数组 |
| `cards` | × | 右侧说明卡片 |
| `views` | × | 引导视图（架构图切换用） |

### 3.2 meta 字段

```json
"meta": {
  "title": "<项目名> 系统架构",
  "quality_profile": "showcase",
  "locale": "zh-CN",
  "visual_preset": "classic",
  "animation": "trace",
  "subtitle": "可选副标题（仅用户明确要时写）",
  "legend": { "mode": "auto" },
  "repository": {
    "url": "https://github.com/owner/repo",
    "revision": "<40字符sha>",
    "provider": "github"
  }
}
```

#### meta 字段约束（来自 archify authoring-contract.md）

- `locale` 仅接受 `en` 或 `zh-CN`。其他语言**不要写**，让 viewer 用英文兜底。
- `visual_preset` 默认 `classic`；只在用户明确要求时才写 `signal-flow` / `blueprint` / `editorial`。
- `engineering_profile` 默认**省略**；仅当用户明确要"生产部署拓扑/责任边界/fail-closed review"时才开 `deployment-ownership`。
- `subtitle` 默认**省略**；只有用户明确要副标题才写，**不要重复 title**。
- `legend.mode`：`auto`（默认，按需呈现）/ `all`（全展示）/ `hidden`（不展示）。
- `repository.revision` 必须是 40 字符完整 SHA。`link_mode` 默认 `web`；内网仓库用 `local-only`。

### 3.3 components（节点）

```json
{
  "id": "api",
  "type": "backend",
  "label": "API 服务",
  "sublabel": "FastAPI :8000",
  "pos": [670, 300],
  "size": [130, 60],
  "tag": "可选",
  "sources": [
    { "path": "src/api/main.py", "line": 1, "end_line": 40, "label": "入口" }
  ]
}
```

`type` 取值（**真实 enum**）：

| 值 | 用途 |
|---|---|
| `frontend` | 浏览器 / 移动端 / SPA |
| `backend` | 自研服务 / 业务逻辑 |
| `database` | Postgres / MySQL / Redis / Mongo / ES |
| `cloud` | CDN / LB / S3 / SQS / Lambda / K8s |
| `security` | 鉴权 / IAM / Vault / OAuth |
| `messagebus` | Kafka / RabbitMQ / NATS / SQS |
| `external` | 第三方 / 用户 / 浏览器外 / 外部 SaaS |

`pos` 是左上角像素坐标，`size` 是宽高像素。架构图网格通常 `col ∈ [40, 250, 460, 670, 880, 1090]`，行高常用 `[110, 300, 440]`。

`sources[].path` 是仓库相对路径，配 `meta.repository` 后 viewer 会渲染成可跳转链接。

### 3.4 connections（关系）

```json
{
  "id": "users-to-cdn",
  "from": "users",
  "to": "cdn",
  "label": "HTTPS",
  "variant": "emphasis",
  "fromSide": "right",
  "toSide": "left"
}
```

字段：

- `from` / `to`：component id
- `label`：语义标签。**不要为布局而删**（archify 会拒绝把它当 spacing repair）。
- `variant`：`default` / `emphasis`（主链路）/ `security`（鉴权相关）/ `dashed`（异步 / 弱依赖）
- `fromSide` / `toSide`：`left` / `right` / `top` / `bottom` — 端口方向
- `via`：手摆路径 `[[x,y], ...]`，仅当自动路由不合预期时用

### 3.5 boundaries（架构图专属）

```json
{
  "kind": "region",
  "label": "AWS Region: us-west-2",
  "wraps": ["cdn", "lb", "api", "db", "s3"]
}
```

`kind`：`region` / `security-group` / `cluster` / `process` / `trust` / `deployment` / `ownership` / `tenant`。

### 3.6 views（引导视图，架构图专属）

```json
{
  "id": "request-path",
  "label": "请求主链路",
  "focus": ["users", "cdn", "lb", "api", "db"],
  "note": "从边缘到持久化状态的完整路径"
}
```

`focus` 列出要突出的 component id。本 skill 默认生成 3 个 views：请求主链路 / 异步与存储 / 安全与配置。

### 3.7 cards（说明卡，架构图专属）

```json
{
  "dot": "cyan",
  "title": "边缘层",
  "items": [
    "CloudFront 缓存静态资源",
    "S3 通过 OAI 提供源"
  ]
}
```

`dot` 颜色：`cyan` / `emerald` / `rose` / `amber` / `sky` / `violet` / `slate`。

## 4. 五种 diagram_type 速记

| type | 节点字段 | 必有字段 |
|---|---|---|
| `architecture` | components + boundaries | `pos`, `size` |
| `workflow` | nodes + lanes + columns | lanes 用 `lane` 字段；列用 `col` ∈ 0..5 |
| `sequence` | participants + messages | `order` 字段定参与方顺序 |
| `dataflow` | stages + rows | `stage` / `row` 字段 |
| `lifecycle` | phases + events | `phase` ∈ 0..4，事件列对齐 x = phase+2 |

workflow 新内容用 `schema_version: 2`，老内容保留 v1 以保几何。

## 5. 校验与交付工作流

```bash
ARCHIFY=$(bin/check_archify.sh) || exit 0  # archify 不可用则跳过

# 1. 校验（强烈推荐先跑）
bash -c "$ARCHIFY validate architecture architecture.json --quality showcase --json" > arch.json.diag
# 退出码 0 且 diagnostics[] 为空 → 通过；否则读 supportedFixes[]

# 2. 交付（渲染 HTML）
bash -c "$ARCHIFY deliver architecture architecture.json architecture.html --quality showcase"

# 3. 自检（可选）
bash -c "$ARCHIFY visual-check architecture.html --json"
```

`--quality` 取 `standard` / `showcase`。**导学文档默认 showcase**。

**重试纪律**：同一份 IR 最多两轮修复；第二轮仍失败 → 把 IR + diagnostics 落到 `<out>/archify-error.json`，停下问用户。

## 6. 仓库证据绑定（`--repo-root` + `meta.repository`）

当架构图要反映真实代码时，必须：

1. 在 JSON 里写：
   ```json
   "meta": {
     "repository": {
       "url": "https://github.com/owner/repo",
       "revision": "<40字符sha>"
     }
   }
   ```
2. 给每个非 `external` 节点加 `sources[].path`（仓库相对路径）。
3. 跑命令时加 `--repo-root /path/to/repo`，archify 会**离线**验证这些源码确实存在 + 行号有效。

注意：这是 **architecture 专属**；workflow / sequence / dataflow / lifecycle 不接受 `--repo-root`。

内网仓库：`link_mode: "local-only"`，viewer 保留路径标签但不做超链接。

## 7. 输出文件清单

```
<output_dir>/
├── architecture.json          # 中间产物（建议保留，便于迭代）
├── architecture.html         # 嵌入 onboarding.md（默认必有）
├── workflow.json / .html     # depth ≥ standard
├── sequence.json / .html     # depth = deep + 有 RPC 链路时
├── dataflow.json / .html     # depth = deep + 有 DB / 队列时
└── lifecycle.json / .html    # depth = deep + 有 CI/CD / K8s 时
```

若 archify 不可用，目录里没有 `.html` / `.json`，仅 `onboarding.md` + `detect.txt`。

## 8. 常见错误对照

| 现象 | 含义 | 修复动作 |
|---|---|---|
| `validate` 退出码非零 | IR 不合法 | 读 `diagnostics[].code` + `supportedFixes` |
| `meta.locale: en-US` 报错 | locale 只接受 en/zh-CN | 改 `en` 或去掉 |
| `schema_version` 错配 | workflow v2 写成 v1 | `archify migrate workflow old.json new.json --to-schema 2` |
| `components[].pos` 越界 | 节点放到画布外 | 用网格 col 0..5 + row 0..2 |
| 关系 label 撞边 | label 距离过近 | 改 `fromSide/toSide` 或加 `via` |
| `components` 数量 > 12 | 节点过载 | 合并同类、删去次要、改用 cards 表达文字 |
| `connections` 环 + 无 direction | 架构图路由失败 | 给环加方向，或拆为子图 |

更详细的 `diagnostics` 处理见 [references/troubleshooting.md](troubleshooting.md) 的 archify 段。
