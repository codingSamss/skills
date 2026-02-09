---
name: cc-codex-review
description: "CC-Codex 协作讨论。自由话题驱动的 CC-Codex 协作工具，Battle Loop 辩论机制。关键词: 审查, review, 让codex看看, codex审查, 帮我审查, 讨论, discuss, battle, 让codex检查, 发给codex, 话题, topic, 代码审查, 架构讨论, 技术决策"
---

# CC-Codex 协作讨论 Skill

通过 CodexMCP 实现 Claude Code 与 Codex 的话题驱动协作讨论工具。支持自由话题、Battle Loop 辩论机制和跨会话连续性。

## 触发条件

### 命令触发
- `/review <topic>` - 启动新话题讨论
- `/review 继续` - 继续当前话题
- `/review 结束` - 结束话题并输出制品
- `/review 状态` - 查看状态
- `/review 重置` - 重置 session_id（保留 summary，需用户确认）

### 自然语言触发
- "让 codex 看看这个方案" / "跟 codex 讨论一下" -> 启动新话题
- "继续刚才的讨论" / "接着聊" -> 继续当前话题
- "讨论结束了" / "可以了" -> 结束话题
- "审查状态" / "当前讨论进度" -> 查看状态
- "重置会话" / "重新开始" -> 重置

## 前置依赖

- CodexMCP 已安装为 MCP Server（名称: `codex`）
- 提供 `codex` 工具，支持 `prompt`、`session_id`、`sandbox`、`return_all_messages` 参数
- Python 3.8+（运行 topic-manager.py）

## 通用配置

```
TOPIC_MANAGER=~/.claude/skills/cc-codex-review/scripts/topic-manager.py
DATA_DIR=.cc-codex
MAX_ROUNDS=5
```

## 话题类型与制品映射

| 话题类型 | 说明 | 制品文件名 |
|----------|------|-----------|
| code-implementation | 代码实现方案讨论 | changes.md |
| architecture-design | 架构设计讨论 | plan.md |
| bug-analysis | Bug 分析讨论 | analysis.md |
| technical-decision | 技术决策讨论 | decision.md |
| open-discussion | 开放讨论 | memo.md |

## 话题分类规则

CC 根据用户话题内容自动分类：
- 涉及具体代码修改、实现步骤 -> `code-implementation`
- 涉及系统设计、模块划分、技术选型 -> `architecture-design`
- 涉及 bug 排查、错误分析 -> `bug-analysis`
- 涉及技术方案选择、权衡 -> `technical-decision`
- 其他 / 不确定 -> `open-discussion`

**不确定时询问用户确认。** 用户可通过参数手动指定类型：`/review <topic> --type architecture-design`

## 命令路由

1. **`/review <topic>`** -> 执行「讨论启动流程」
2. **`/review 继续`** -> 执行「继续讨论流程」
3. **`/review 结束`** -> 执行「结束讨论流程」
4. **`/review 状态`** -> 执行 `python3 "$TOPIC_MANAGER" status "$PWD"` 并格式化展示
5. **`/review 重置`** -> 需用户确认后，将 session_id 设为 null（保留 summary.md）

## Codex MCP 工具调用规范

**首次调用（无 session_id）：**
```
工具: codex
参数:
  prompt: <构造的讨论 Prompt>
  sandbox: "read-only"
  return_all_messages: false
```

**后续调用（有 session_id）：**
```
工具: codex
参数:
  prompt: <构造的回复 Prompt>
  session_id: <已保存的 session_id>
  sandbox: "read-only"
  return_all_messages: false
```

**Debug 模式（用户主动要求时开启）：**
- 用户说"debug 模式"/"查看交互过程"/"显示完整对话"时，将 `return_all_messages` 设为 `true`

**从响应中提取 SESSION_ID：**
- Codex 响应 JSON 中的 `SESSION_ID` 字段（大写）
- 首次调用后必须提取并保存

## 新会话初始化流程

每次 CC 新会话启动、用户触发 `/review` 相关命令时，先执行初始化：

```
1. 旧数据检测: 如果 $PWD/.cc-codex/cycles/ 目录存在，提示用户：
   "检测到旧版审查数据（.cc-codex/cycles/），新版使用 .cc-codex/topics/。旧数据不会自动迁移，如不再需要可手动删除 .cc-codex/cycles/ 目录。"
2. auto-cleanup: python3 "$TOPIC_MANAGER" auto-cleanup "$PWD" 120
3. 检测活跃话题: python3 "$TOPIC_MANAGER" topic-read "$PWD"
4. 如果有活跃话题:
   - 告知用户："检测到未完成的话题: [标题]（第 N/5 轮）"
   - 提示用户选择：继续讨论 / 结束话题 / 放弃并开始新话题
5. 如果无活跃话题: 正常进入命令处理
```

## 讨论启动流程（`/review <topic>`）

**Step 1: 创建话题**
```bash
# CC 自动分类话题类型（或用户指定）
python3 "$TOPIC_MANAGER" topic-create "$PWD" "<话题标题>" "<类型>"
```

**Step 2: 收集上下文**
- 读取项目背景：先查 `$PWD/CLAUDE.md`，再查 `$PWD/.claude/CLAUDE.md`
- 根据话题类型收集相关素材：
  - `code-implementation`: git diff、相关源码
  - `architecture-design`: 现有架构描述、相关文档
  - `bug-analysis`: 错误日志、相关代码
  - `technical-decision`: 备选方案描述
  - `open-discussion`: 用户提供的素材

**Step 3: 构造 Prompt 并调用 Codex**

根据话题类型使用不同角色设定，但共享统一的输出格式要求：

```
你是一位资深技术专家，正在与另一位工程师（CC）进行技术讨论。

## 话题
[话题标题和描述]

## 项目背景
[从 CLAUDE.md 提取的信息摘要]

## 讨论素材
[收集到的上下文内容]

## 讨论要求
请从你的专业角度分析这个话题，提出你的观点和建议。

## 输出格式要求
- 每条意见标注优先级：[必须修改] / [建议优化] / [疑问]
- 最终给出结论：APPROVE（同意当前方案）或 REQUEST_CHANGES（需要调整）
- 如果 REQUEST_CHANGES，列出所有 [必须修改] 项
```

**Step 4: 提取 SESSION_ID 并保存**
```bash
python3 "$TOPIC_MANAGER" topic-update "$PWD" session_id "<从响应中提取的session_id>"
python3 "$TOPIC_MANAGER" topic-update "$PWD" round 1
```

**Step 5: 进入 Battle 循环**

## Battle 循环核心逻辑

```
当前轮次 = 1
最大轮次 = 5

WHILE 当前轮次 <= 最大轮次 AND 未达成一致:

  1. CC 逐条分析 Codex 意见:
     - 明确 bug / 逻辑错误 -> 接受
     - 合理架构建议且符合项目约束 -> 接受
     - 基于错误前提的意见 -> 反驳并提供正确上下文
     - 风格偏好 / 非关键优化 -> 低成本则接受，否则标记"后续优化"

  2. CC 构造回复:
     - 列出已接受的修改及具体调整
     - 列出不同意的观点及详细理由
     - 附上更新后的内容

  3. 调用 codex MCP 工具（携带 session_id 继续对话）
     调用完成后刷新活动时间:
     python3 "$TOPIC_MANAGER" topic-update "$PWD" round <当前轮次>

  4. 每轮更新 summary.md（强结构模板，由 CC 直接写入话题目录）
     路径: $PWD/.cc-codex/topics/<topic_id>/summary.md
     （topic_id 从 topic-read 返回值获取）

  5. 判断是否达成一致:
     - Codex 回复包含 "APPROVE" -> 达成一致，退出循环
     - Codex 回复包含 "REQUEST_CHANGES" -> 继续 battle
     - 格式异常 -> 展示原始响应给用户确认

  6. 提前终止条件（AND 逻辑，两个条件同时满足）:
     - 无高风险（[必须修改]）未决项
     - 连续 2 轮无新分歧
     满足时可提前结束

超过 5 轮: 输出分歧清单交用户裁决
```

**CC 回复 Codex 的格式模板：**

```
## CC 回复（第 N 轮）

### 已接受的修改
1. [意见摘要] -> 已按建议修改：[具体调整说明]

### 不同意的观点
1. [意见摘要] -> 不同意，理由：[详细理由和项目上下文]

### 标记为后续优化
1. [意见摘要] -> 认可价值，但当前阶段优先级不高，标记后续处理

### 更新后的内容
[更新后的方案/代码/分析]

请基于以上回复重新审查，如果所有 [必须修改] 项已解决，请回复 APPROVE。
```

## 制品输出规则

**两步发布策略：**

1. **先写入内部目录**（单一真源）：
   `$PWD/.cc-codex/topics/<topic_id>/artifacts/<制品文件>`
   （topic_id 从 topic-read 返回值获取，制品文件名由话题类型决定，见映射表）

2. **用户指定目录时，成功后发布到外部**：
   - 话题创建时或结束时，用户可指定 `output_dir`
   - 指定后通过 `topic-update` 保存: `python3 "$TOPIC_MANAGER" topic-update "$PWD" output_dir "<路径>"`
   - 结束时将制品从 artifacts/ 复制到用户指定目录

中间产物（battle 过程中的 summary.md 更新等）不展示给用户，除非用户主动查询。

## 跨会话恢复（双保险）

**主路径：SESSION_ID 恢复**
- CC 新会话启动时，`topic-read` 检测到活跃话题且有 session_id
- 使用已保存的 session_id 继续与 Codex 的对话
- Codex 端保有历史上下文

**备路径：summary.md 重建上下文**
- 如果 session_id 失效（Codex 返回错误）
- 读取 summary.md 获取之前的讨论进展
- 将 summary.md 内容作为上下文构造新 Prompt
- 开启新 Codex session，从中断处继续
- 重置 session_id: `python3 "$TOPIC_MANAGER" topic-update "$PWD" session_id null`
- 保存新 session_id

## 继续讨论流程（`/review 继续`）

1. 读取活跃话题: `python3 "$TOPIC_MANAGER" topic-read "$PWD"`
2. 如果无活跃话题，提示用户先创建
3. 尝试主路径恢复（使用 session_id）
4. 如果 session_id 失效，走备路径（summary.md 重建）
5. 进入 Battle 循环继续讨论

## 结束讨论流程（`/review 结束`）

1. 读取活跃话题元数据和 summary.md
2. 根据话题类型生成对应制品文件，写入 artifacts/
3. 如果有 output_dir，复制到用户指定目录
4. 完成话题: `python3 "$TOPIC_MANAGER" topic-complete "$PWD"`
5. 向用户报告：话题标题、轮次、结论摘要、制品位置

## 异常处理

### Codex 调用失败
- 重试一次，仍失败则向用户报告错误信息
- 展示当前讨论进度，询问是否手动继续

### SESSION_ID 失效
- 自动切换到备路径：summary.md 重建上下文 + 新 session
- 重置 session_id 并保存新值

### 响应格式异常
- Codex 响应中无法识别 APPROVE / REQUEST_CHANGES
- 将原始响应展示给用户，由用户判断

### topic-manager.py 调用失败
- 检查 Python 3 是否可用
- 检查脚本路径是否正确
- 展示 stderr 错误信息

### 话题目录损坏（CC 侧处理）
- meta.json 损坏：CC 读取 summary.md 解析基本信息（标题、类型、轮次），手动调用 topic-create 重建话题
- summary.md 丢失：CC 从 meta.json 读取元数据，用 Write 工具重建空的 summary.md 模板
- 注意：这些恢复逻辑由 CC 执行，topic-manager.py 本身不提供自动修复

### 预算耗尽
- 将 termination_reason 设为 `budget_exhausted`
- 保存当前进展到 summary.md
- 结束话题并告知用户

## 用户交互规范

### Battle 过程中的信息展示
每轮 battle 向用户展示：
- 当前轮次 / 最大轮次
- Codex 的主要意见摘要（不展示完整原文，除非用户要求）
- CC 的处理决策（接受/反驳/标记后续）
- 当前状态（继续 battle / 已达成一致 / 需要用户裁决）

### 用户干预点
- Battle 超过 5 轮时，展示分歧清单，等待用户裁决
- 用户可随时输入 "stop" 中断 battle，手动处理

## .gitignore 提示

首次运行时，检查项目 `.gitignore` 是否包含 `.cc-codex/`，如果没有则提示用户添加：
```
# CC-Codex 协作讨论运行时数据
.cc-codex/
```

## CodexMCP 依赖

如果 codex 工具不可用，所有命令将报错并提示安装：
```
claude mcp add codex -s user --transport stdio -- uvx --from git+https://github.com/GuDaStudio/codexmcp.git codexmcp
```
