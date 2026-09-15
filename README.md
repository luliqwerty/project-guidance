# Project Guidance

为任意代码仓库生成新人入职导学材料。

- 主文档：[SKILL.md](SKILL.md)
- 触发词："做项目导学"、"项目导读"、"新人 onboarding"、"project guide"
- 默认语言：中文
- **核心产物**：`docs/onboarding.md`（不依赖任何外部工具）
- **可选产物**：`docs/architecture.html`（需要 [archify](https://github.com/tt-a1i/archify)）

## 设计原则

1. **Markdown 优先** — onboarding.md 始终产出；架构图是可选增强。
2. **archify 可选** — 未安装时只生成导学文档，不阻断。
3. **只读** — 只读目标项目源码，写入 `target/docs/`。
4. **路径锚定** — 文档里每个引用都给可点击的路径。

## 快速使用

```
为 /path/to/project 生成导学文档
```

skill 会自动：

1. 扫描项目，识别栈、入口、依赖 → 写入 `<target>/docs/detect.txt`
2. 检查 archify 是否可用
3. 按统一模板写 `docs/onboarding.md`（主产物）
4. archify 可用时再生成 `docs/architecture.html`（可选）

## 目录结构

```
project-guidance/
├── SKILL.md                     # 主入口
├── Makefile                     # 简化常用命令
├── bin/
│   ├── check_archify.sh         # archify 安装检测
│   └── generate-onboarding.sh   # 编排入口
├── scripts/
│   ├── detect_stack.sh          # 栈检测（只读）
│   └── test-smoke.sh            # skill 自检
└── references/
    ├── project-scan.md          # 多语言项目扫描
    ├── archify-integration.md   # archify CLI 对接（可选）
    ├── summary-template.md      # 要点梳理模板
    ├── output-layout.md         # 产物布局
    └── troubleshooting.md       # 常见失败
```

## 安装到全局

```bash
# 软链 / 复制到 ~/.claude/skills/
ln -s "$(pwd)" ~/.claude/skills/project-guidance

# 可选：安装 archify（不安装也能用 skill，只是没架构图）
npm i -g archify
# 或
npx skills add tt-a1i/archify -g -y
```

## 反馈

有问题 / 想贡献：直接编辑本目录下的 markdown / shell 即可。
