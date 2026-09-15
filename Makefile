# project-guidance skill — Makefile
# 让日常操作一条命令搞定

SHELL := /bin/bash
SKILL_DIR := $(shell pwd)
DETECT := $(SKILL_DIR)/scripts/detect_stack.sh
GENERATOR := $(SKILL_DIR)/bin/generate-onboarding.sh
ARCHIFY_CHECK := $(SKILL_DIR)/bin/check_archify.sh
ARCHIFY := $(shell $(ARCHIFY_CHECK) 2>/dev/null)

.PHONY: help doctor detect onboard clean test

help: ## 列出所有命令
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

archify-check: ## 检测 archify 是否已安装
	@if [ -n "$(ARCHIFY)" ]; then \
	  echo "[ok] archify: $(ARCHIFY)"; \
	else \
	  echo "[info] archify 未安装 — 跳过架构图，仅产出 onboarding.md"; \
	  echo "        安装: npm i -g archify"; \
	fi

doctor: ## archify 健康检查（不可用时跳过）
	@if [ -n "$(ARCHIFY)" ]; then \
	  bash -c "$(ARCHIFY) doctor"; \
	else \
	  echo "[skip] archify 未安装 — 跳过 doctor"; \
	  echo "        安装: npm i -g archify"; \
	fi

detect: ## 检测目标项目栈（TARGET=path）
	@test -n "$(TARGET)" || { echo "用法: make detect TARGET=/path/to/project"; exit 2; }
	@$(DETECT) $(TARGET)

onboard: ## 给目标项目生成导学（TARGET=path, TYPE=architecture,...）
	@test -n "$(TARGET)" || { echo "用法: make onboard TARGET=/path/to/project [TYPE=workflow]"; exit 2; }
	@$(GENERATOR) $(TARGET) --depth $(or $(DEPTH),standard) --type $(or $(TYPE),architecture) --run
	@echo "→ 编辑 $(TARGET)/docs/onboarding.md 完成导学文档"

clean: ## 清理产物（仅本 skill 的 docs/）
	@rm -rf $(SKILL_DIR)/docs
	@echo "cleaned $(SKILL_DIR)/docs"

test: ## 跑自检
	@bash $(SKILL_DIR)/scripts/test-smoke.sh
