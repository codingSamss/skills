---
name: orbit-os
version: "1.1.0"
updated: 2026-02-19
description: "知识库 OrbitOS Obsidian Vault 共享配置。Vault 结构、格式规则、排版规范。被 orbit-* 系列 skill 引用，不直接调用。"
---
OrbitOS 共享配置，供 orbit-* 系列 skill 引用。

# Vault 结构

库路径: `"$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Sam's"`

| 目录 | 用途 |
|------|------|
| `01_日记` | 每日日志 (`YYYY-MM-DD.md`) |
| `02_项目` | 活跃项目（扁平结构，按名称组织） |
| `03_研究` | 永久参考资料 |
| `04_知识库` | 原子概念笔记 |
| `05_资讯` | 策展内容（Newsletters/、产品发布/） |
| `06_计划` | 执行计划（完成后归档） |

# 结构与元数据规范

- Frontmatter 必须在文件第一行，`---` 开头和结尾
- 多值字段用数组: `tags: [tag1, tag2]`
- 不允许重复键
- `---` 结束后不留空行
- 使用 wikilinks `[[NoteName]]` 连接笔记
- 项目通过 frontmatter 的 `area` 字段关联领域，不用文件夹层级
- 相关链接放在正文底部 `## See Also`，不放 frontmatter
- 外部脚本写入 `.md` 后必须执行 `touch <file>` 以触发 iCloud 同步和 Obsidian 感知

# 内容呈现规范

输出到 Obsidian 的文档必须遵循以下排版风格:

## 文档开头
- 第一个内容块用 `> [!info]` callout 概括核心目标或文档定位

## 标题层级
- H2 带编号: `## 1. 标题名 (English Name)`，中英文双语
- H3 用于子节，不带编号
- 章节之间用 `---` 分隔

## 强调与标记
- 关键术语首次出现时加粗
- 技术名词、代码符号用行内代码包裹
- 代码块必须标注语言

## Callout 使用
- `> [!info]` 用于关键洞察、原理解释
- `> [!warning]` 用于注意事项、风险提示
- 普通引用块 `>` 用于类比、比喻、形象说明

## 内容组织
- 复杂概念先给出简短直觉解释，再展开细节
- 对比说明用并列代码块或表格
- 每个主要章节结尾可加引导思考或小结

# 日记填充规则

写日记（`01_日记/YYYY-MM-DD.md`）时，`## 日志` 部分应自动从 GitHub 拉取当天跨仓库的 commit 记录。

- GitHub 用户名: `codingSamss`
- 数据源: `gh api` Events API + Commits API
- 不加 `author` 参数，避免邮箱不匹配

## 写入格式

按仓库分组，每个仓库一个 H3，附 commit 数量。每条 commit 用列表项，末尾括号标 short sha。同仓库多条 commit 归纳出一句主线描述。

```markdown
### {repo}（N commits）

主线：一句话概括本仓库今天的改动方向

- commit 描述（`sha`）
- commit 描述（`sha`）
```

# 项目笔记结构 (C.A.P.)

- **背景 (Context)**: 目标、背景、为什么重要
- **行动 (Actions)**: 阶段/里程碑与任务
- **进展 (Progress)**: 更新记录

最小模板:

```markdown
---
area:
tags: [project]
status: active
---
## Context
## Actions
## Progress
```

# 规范优先级

当子 skill（如 orbit-diary）定义的规则与本文件冲突时，子 skill 特例优先于 orbit-os 基线。

# 校验清单

写入 Vault 前必检:

- [ ] Frontmatter 在第一行，无重复键
- [ ] H2 带编号且中英双语
- [ ] 代码块标注语言
- [ ] `## See Also` 在正文底部
- [ ] 外部写入后执行 `touch`
