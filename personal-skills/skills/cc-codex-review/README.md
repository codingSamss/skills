# CC-Codex 协作讨论

## 概述

CC-Codex 协作讨论是一个话题驱动的 Claude Code Skill，通过 CodexMCP 桥接 Claude Code (CC) 与 OpenAI Codex，实现两个 AI 之间的自由话题协作讨论。

**核心理念**：CC 作为开发者的编码助手，Codex 作为独立的技术专家。二者围绕用户提出的任意话题进行多轮 Battle Loop 辩论，通过观点碰撞达成更优共识，最终输出结构化制品。

## 实现原理

### 话题驱动模型

与传统的固定阶段审查流程不同，本工具采用话题驱动模型：

- **自由话题**：用户可以发起任意技术话题（代码实现、架构设计、Bug 分析、技术决策等），不受固定阶段约束
- **自动分类**：CC 根据话题内容自动判断类型，决定对应的制品格式和审查维度；不确定时询问用户确认
- **单活跃话题**：同一时刻只有一个活跃话题，确保讨论焦点集中
- **生命周期完整**：每个话题经历 创建 -> 讨论(Battle) -> 完成/放弃 的完整生命周期

### 架构设计

```
用户 <-> Claude Code (CC) <-> CodexMCP <-> OpenAI Codex
              |                                  |
              |  skill.md (工作流引擎)            |  独立技术视角
              |  topic-manager.py (状态管理)      |  通过 session_id 保持对话连续
              |                                  |
              +---- .cc-codex/ (本地状态) --------+
```

**三层职责划分：**

| 组件 | 职责 | 实现方式 |
|------|------|---------|
| **skill.md** | 工作流引擎：话题分类、Prompt 构造、Battle 逻辑、制品生成、summary.md 维护 | CC 按指令执行 |
| **topic-manager.py** | 状态管理：话题 CRUD、元数据维护、过期清理 | Python CLI，JSON 输出 |
| **CodexMCP** | 通信桥接：CC 与 Codex 之间的 MCP 协议适配 | 外部 MCP Server |

**设计原则：**

- **元数据与内容分离**：元数据（meta.json、active.json）由 topic-manager.py 管理并采用原子写入；summary.md 初始模板由 topic-manager.py 生成，后续每轮由 CC 更新；制品文件由 CC 在结束流程中写入
- **原子元数据写入**：topic-manager.py 的关键文件写入采用 .tmp + os.replace() 原子替换，防止中断导致元数据损坏
- **JSON 标准输出**：topic-manager.py 业务命令的正常输出为 JSON（stdout），帮助信息和错误信息为纯文本（stdout/stderr），便于 CC 解析

### Battle Loop 机制

Battle Loop 是 CC 与 Codex 之间的多轮辩论机制，核心流程：

1. CC 将话题和上下文发送给 Codex
2. Codex 给出意见，每条标注优先级（[必须修改] / [建议优化] / [疑问]）
3. CC 逐条分析并回复：接受 / 反驳（附理由）/ 标记后续优化
4. 重复直到达成共识或达到最大轮次

**终止条件：**

- **正常终止**：Codex 回复 APPROVE（共识达成）
- **提前终止**（AND 逻辑）：无 [必须修改] 未决项 且 连续 2 轮无新分歧
- **超时终止**：超过 5 轮，输出分歧清单交用户裁决
- **用户终止**：用户随时可输入 "stop" 中断

### 跨会话恢复（双保险）

CC 会话可能因各种原因中断。本工具提供双保险恢复：

1. **主路径 -- session_id**：使用已保存的 session_id 直接恢复 Codex 对话上下文
2. **备路径 -- summary.md**：当 session_id 失效时，读取 summary.md（强结构模板）重建上下文，开启新 Codex session

summary.md 采用固定结构模板，每轮 Battle 后由 CC 更新，确保任何时刻都可从 summary.md 恢复讨论进度。

## 使用方式

### 安装前置依赖

```bash
# 安装 CodexMCP
claude mcp add codex -s user --transport stdio -- uvx --from git+https://github.com/GuDaStudio/codexmcp.git codexmcp
```

需要 Python 3.8+ 运行 topic-manager.py（macOS/Linux 通常预装）。

### 快速上手

1. 启动话题：`/review 我想讨论一下数据库选型`
2. 自动 Battle：CC 与 Codex 自动辩论，每轮展示摘要
3. 达成共识后结束：`/review 结束`，生成制品到 `.cc-codex/topics/<id>/artifacts/`（若配置了 `output_dir`，会同步发布到外部目录）
4. 查看状态：`/review 状态`
5. 下次继续：`/review 继续`

### 命令

| 命令 | 功能 |
|------|------|
| `/review <topic>` | 启动新话题讨论 |
| `/review 继续` | 继续当前话题 |
| `/review 结束` | 结束话题并输出制品 |
| `/review 状态` | 查看当前状态 |
| `/review 重置` | 重置 session_id（保留讨论进度） |

### 自然语言触发

除命令外，也支持自然语言：
- "让 codex 看看这个方案" / "跟 codex 讨论一下" -> 启动新话题
- "继续刚才的讨论" / "接着聊" -> 继续当前话题
- "讨论结束了" / "可以了" -> 结束话题

### 使用示例

**场景 1：架构设计讨论**
```
用户: /review 微服务拆分方案
CC:   自动分类为 architecture-design，收集项目背景，构造 Prompt 发送给 Codex...
CC:   [第 1/5 轮] Codex 提出 5 条意见：
      - [必须修改] 服务边界划分不合理，订单和支付应分离
      - [建议优化] 建议引入事件驱动通信
      - ...
      CC 接受 3 条，反驳 2 条，发送回复...
CC:   [第 2/5 轮] Codex 回复 APPROVE，共识达成。
用户: /review 结束
CC:   制品已输出到 .cc-codex/topics/<id>/artifacts/plan.md
```

**场景 2：代码实现讨论**
```
用户: 让 codex 看看这个 API 的实现方案
CC:   自动分类为 code-implementation，收集 git diff 和相关源码...
      [Battle Loop 进行中...]
CC:   3 轮后达成共识。
用户: /review 结束
CC:   制品: changes.md
```

**场景 3：跨会话继续**
```
# 新的 CC 会话
用户: /review 继续
CC:   检测到未完成的话题: "微服务拆分方案"（第 2/5 轮）
      使用 session_id 恢复 Codex 对话...
      [继续 Battle Loop]
```

用户可以在话题描述中指明类型，CC 会优先尊重用户意图。如果未指明，CC 会自动分类后询问用户确认。

## 话题类型与制品

| 类型 | 说明 | 制品文件 | 典型场景 |
|------|------|---------|---------|
| code-implementation | 代码实现方案 | changes.md | 具体代码修改、实现步骤 |
| architecture-design | 架构设计 | plan.md | 系统设计、模块划分、技术选型 |
| bug-analysis | Bug 分析 | analysis.md | Bug 排查、错误分析 |
| technical-decision | 技术决策 | decision.md | 技术方案选择、权衡 |
| open-discussion | 开放讨论 | memo.md | 其他 / 不确定 |

## 数据结构

```
.cc-codex/
├── active.json                          # {"topic_id": "..."}  活跃话题指针
└── topics/
    └── YYYYMMDD-HHMMSS-<slug>/
        ├── meta.json                    # 话题元数据（状态、轮次、session_id 等）
        ├── summary.md                   # 可恢复摘要（强结构模板，每轮更新）
        └── artifacts/                   # 最终制品（类型决定文件名）
```

### meta.json 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| title | string | 话题标题 |
| type | string | 话题类型（5 种之一） |
| status | string | active / completed / abandoned |
| session_id | string? | Codex 会话 ID，用于跨会话恢复 |
| round | int | 当前 Battle 轮次 |
| max_rounds | int | 最大轮次（默认 5） |
| output_dir | string? | 用户指定的外部输出目录 |
| termination_reason | string? | 终止原因（consensus / user_stopped / max_rounds / abandoned / budget_exhausted） |
| created_at | string | 创建时间 |
| updated_at | string | 最后更新时间 |
| completed_at | string? | 完成时间 |

### summary.md 模板

```markdown
# 话题标题

## 基本信息
- 类型: architecture-design
- 状态: 进行中
- 当前轮次: 2/5

## 当前结论
...

## 未决分歧
...

## 关键证据与上下文
...

## 已确认的决策
...
```

## topic-manager.py CLI

话题生命周期管理工具。业务命令正常输出为 JSON，帮助与错误信息为纯文本。

```bash
python3 topic-manager.py <command> <project_root> [args...]
```

| 命令 | 说明 |
|------|------|
| `topic-create <root> <title> [type]` | 创建新话题 |
| `topic-read <root>` | 读取活跃话题 |
| `topic-update <root> <field> <value>` | 更新活跃话题字段（受白名单约束） |
| `topic-complete <root>` | 完成话题 |
| `topic-list <root>` | 列出所有话题 |
| `auto-cleanup <root> [minutes]` | 清理过期话题（默认 120 分钟） |
| `status <root>` | 输出状态摘要 |

注：`topic-update` 仅更新当前活跃话题，字段受白名单约束（title, type, status, session_id, round, max_rounds, output_dir, termination_reason）。

## 升级说明

如果之前使用过旧版（三阶段审查模式），项目目录下可能存在 `.cc-codex/cycles/` 目录。新版使用 `.cc-codex/topics/` 存储话题数据，旧数据不会自动迁移。首次运行时会检测并提示，如不再需要旧数据可手动删除 `.cc-codex/cycles/` 目录。

## 外部依赖

| 依赖 | 用途 | 安装 |
|------|------|------|
| CodexMCP | CC-Codex 通信桥接 | `claude mcp add codex -s user --transport stdio -- uvx --from git+https://github.com/GuDaStudio/codexmcp.git codexmcp` |
| Python 3.8+ | 运行 topic-manager.py | 系统预装 |

## 文件清单

```
cc-codex-review/
├── skill.md                    # Skill 定义（话题驱动工作流引擎）
├── README.md                   # 本文档
└── scripts/
    └── topic-manager.py        # 话题生命周期管理 CLI
```