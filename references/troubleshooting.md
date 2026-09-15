# Troubleshooting — 常见失败模式与回退

## A. archify 相关

| 症状 | 原因 | 回退 |
|---|---|---|
| `npx skills add` 卡住 | 网络 / 代理问题 | 让用户设 `HTTPS_PROXY`；或手工 clone `git clone https://github.com/tt-a1i/archify ~/.skills/archify` |
| `archify: command not found` | PATH 未生效 | `export PATH=$(npm root -g)/bin:$PATH`；或用绝对路径 `node $(npm root -g)/archify/bin/archify.mjs ...` |
| `validate` 持续 fail | JSON IR 字段错误 | 读 `diagnostics[]`，按 `supportedFixes` 修，最多两轮；超两轮停下 |
| `deliver` 报错但 JSON 合法 | archify 自身 bug | 把 IR 与报错粘进 issue；本 skill 停下 |
| Node 版本 < 18 | 旧 Node 不支持 archify | 提示 `nvm install 18` |

### A.1 Layout validation 失败（最常见）

`validate` 走到 `stage: "render"` 时报三类错，按出现频率排序：

#### A.1.1 Label 撞 component

```
Label "xxx" overlaps component "yyy" — adjust labelDx/labelDy/labelSegment or set labelAt.
  label rect: [lx, ly, w, h]
  component "yyy" rect: [cx, cy, w, h]
  Suggested fix: labelAt [a, b] or labelDy +N (below); ...
```

**修复纪律**：

1. 先试 `labelDy: ±24` / `labelDy: ±48`（按 diagnostic 推荐的 N 选）
2. 还不行用 `labelAt: [x, y]` 显式定位（按 diagnostic 建议的 `[a, b]`）
3. 一条 connection 只动一个 control，不要同时改 `labelDx` 和 `labelDy`
4. **避免语义删除 label**：archify 视 label 删除为"spacing 修复"而拒绝，保留有意义的标签

#### A.1.2 Edge 撞 component（crosses component）

```
connections[X] id "abc" crosses component "yyy" (unrelated to this relationship)
  on segment N [x1,y1] -> [x2,y2] (2px clearance)
```

**修复顺序**（按 archify authoring-contract.md 的 repair order）：

1. **删多余 connection**（最有效）— 如果 IR 中 > 10 条连线，必然交叉
2. **移动 component** — 改 x/y 让连线绕过
3. **加 via** — 显式拐点 `via: [[x1,y1], [x2,y2]]`，但 `via` 的方向必须与 `fromSide/toSide` 一致
4. **改 component 大小** — 缩小 `size` 减少遮挡

#### A.1.3 Edge 互穿（proper-crossing）

```
connections[X] id "abc" crosses connections[Y] id "def" at [px, py]
```

**修复**：

1. 让两条边在不同 corridor — 一个走上方、一个走下方
2. 加 `via` 显式分层
3. 重排 component 让连线方向自然分开

### A.2 quality_profile 选错

| 场景 | 推荐 |
|---|---|
| 第一次迭代（还不知道布局） | `standard`（更宽松） |
| 出片给新人看 | `showcase`（更严格，渲染更精致） |
| `--quality` 报错 | 检查拼写；只接受 `standard` / `showcase` |

### A.3 IR 节点 / 连线数量

| 数量 | 渲染效果 |
|---|---|
| < 6 节点 + < 6 连线 | 通常一次过 |
| 6–10 节点 + 6–8 连线 | 1–2 轮 labelDy 修复 |
| 10–12 节点 + 8–10 连线 | 多轮 label/edge 修复，可能 3 轮 |
| > 12 节点 | **必须拆** — archify 推荐 6–12 节点。超过就要么合并，要么分多个图 |

> **dogfood 经验**：project-guidance 自举 IR 第一版用了 11 节点 + 10 连线，触发 8 个 diagnostics；简化到 9 节点 + 6 连线后一次过。

### A.4 type 字段误用

历史 schema 用过 `kind` / `componentType`，现在 archify v0.13+ 用 **`type`**：

| 旧版 | 新版（archify v0.13+） |
|---|---|
| `kind: "service"` | `type: "backend"` |
| `kind: "storage"` | `type: "database"` |
| `kind: "queue"` | `type: "messagebus"` |
| `kind: "gateway"` | `type: "cloud"` |
| `kind: "external"` | `type: "external"` |

7 个合法 type：`frontend` / `backend` / `database` / `cloud` / `security` / `messagebus` / `external`。

### A.5 views 在哪

历史示例把 `views` 放在顶层，正确位置是 `meta.views`：

```jsonc
{
  "meta": {
    "views": [
      { "id": "...", "label": "...", "focus": [...], "note": "..." }
    ]
  }
}
```

放到顶层会报 `additionalProperties: views`。

### A.6 boundaries.kind 取值

只接受 `region` / `security-group`：

| 想表达的 | 用 |
|---|---|
| 一个部署区域 | `region` |
| 安全隔离 | `security-group` |
| 模块边界 / 业务域 | 用 `region`（最接近的合法值）+ 描述 label |
| 流程阶段 | 不适合 `boundaries`，改用 `cards` 表达 |

## B. 项目扫描相关

| 症状 | 原因 | 回退 |
|---|---|---|
| 没有 README | 项目未写 | 强提示"建议补 README"，用 `package.json.description` 兜底 |
| 仓库 > 1GB 扫描慢 | 含构建产物 / 大资源 | 跳过 `node_modules` / `target/` / `dist/` / `.venv/`；只扫源码 |
| 全二进制 / lockfile-only | 配置仓库 | 改用 §B 通用前置，从 `*.lock` / `*.toml` 反推 |
| 多语言项目 | 混合栈 | 主语言按文件数；其它作"模块依赖"列出，并在文档明示 |
| 没有 git | 非版本管理项目 | 跳过 commit 历史字段；产物路径用绝对路径而非相对 |
| 文件权限拒绝 | 受保护目录 | `ls -la` 排查；提示用户用 sudo 或换路径 |

## C. 产物生成相关

| 症状 | 原因 | 回退 |
|---|---|---|
| `docs/` 已存在关键文件 | 与本 skill 冲突 | 备份为 `.bak.YYYYMMDD-HHMMSS` 后覆盖 |
| 写文件权限拒绝 | 目录只读 | 提示用户 `chmod` 或换 `--output-dir` |
| onboarding.md 超长 | 项目过大 / 信息冗余 | 提示用户降级到 `depth=quick`；或拆为多篇（每篇一个子系统） |
| 架构图节点 > 30 | 信息过载 | 合并相邻节点；提升节点层级（聚合多个内部模块为一个 service） |
| 中文字符在 HTML 中乱码 | archify 默认 locale | JSON IR 中 `meta.locale = "zh-CN"`；浏览器手动切 UTF-8 |

## D. 内容质量相关

| 症状 | 原因 | 回退 |
|---|---|---|
| 文档几乎全是文件路径列表 | 没有走 summary-template | 重写 §4 / §5；强制要求"职责 + 入口 + 依赖 + 第一件事"四要素 |
| 推断出的"为什么"被质疑 | 缺乏 ADR / 注释 | 显式标"（推断，未找到 ADR）"；保留可证伪性 |
| 模块清单 > 10 | 没排序 / 没合并 | 按引用度排序；内部小模块合并到所属业务模块下 |
| 引用了不存在的文件路径 | 拼写错或路径漂移 | 自检阶段用 `ls` / `find` 验证 |
| 中英混排混乱 | 术语没统一 | 首次出现的专有名词给中英对照（如"依赖注入（Dependency Injection）"） |

## E. 重置与清理

若用户对产物不满意，可：

```bash
# 删除本 skill 生成的产物（不动项目源码）
rm -rf <target_path>/docs/

# 重置全局 archify 安装
npx skills remove archify -g
```

## F. 何时该停下来问用户

| 触发 | 处理 |
|---|---|
| archify 两次都校验失败 | 停下，问是否人工调整 JSON IR 或换工具 |
| 文档里有主观判断被反驳 | 停下，让用户改写或删除该段 |
| 用户给的路径是公司内网仓库 | 不要尝试外网下载；只基于本地能读到的内容 |
| 项目没有任何源码（空仓库） | 停下，问"是否要分析 README + issue 列表做概要" |
| 用户要求把导学文档写进 Wiki / Confluence | 不直接发；先生成本地 md，让用户审阅 |

## G. 错误日志格式

skill 执行失败时统一输出：

```
[project-guidance] ✗ <phase> 失败
原因：<diagnostic or message>
已尝试：<次数> 次
产物：<保留/已清理>
下一步：<建议>
```