# CC-Codex 协作审查 - 使用说明与设计文档

## 概述

CC-Codex 协作审查是一个 Claude Code (CC) Skill，通过 CodexMCP 桥接 Claude Code 与 OpenAI Codex，实现**两个 AI 之间的自动化协作审查**。CC 作为开发者的日常编码助手，Codex 作为独立的审查员，二者围绕计划和代码进行多轮讨论（battle），最终达成共识后输出审查结论。

核心价值：让两个不同的 AI 模型从不同视角审查同一份计划或代码，通过辩论机制提升审查质量，减少单一模型的盲区。

## 工作原理

### 整体架构

```
用户 <-> Claude Code (CC) <-> CodexMCP <-> OpenAI Codex
              |                                  |
              |  skill.md 定义工作流程            |  独立的审查视角
              |  session-manager.sh 管理状态      |  通过 SESSION_ID 保持对话连续
              |                                  |
              +---- .cc-codex/ 目录 (本地状态) ---+
```

**CC 的角色**：代码编写者、审查流程控制器。CC 负责收集计划/代码、构造 Prompt、解析 Codex 的审查意见、决定接受或反驳、实际修改代码。

**Codex 的角色**：独立审查员。Codex 以只读沙盒模式运行，从架构、质量、安全等维度给出审查意见，标注优先级，最终给出 APPROVE 或 REQUEST_CHANGES 结论。

**CodexMCP**：连接二者的 MCP Server。本质是一个对 `codex exec` CLI 的无状态封装，通过 `session_id` 参数维持 Codex 端的对话历史。

### 通信流程

```
1. CC 构造审查 Prompt（包含计划/代码 + 项目背景 + 审查要求）
2. CC 调用 codex MCP 工具（首次不带 session_id）
3. CodexMCP 启动 Codex 会话，返回审查意见 + SESSION_ID
4. CC 保存 SESSION_ID 到磁盘
5. CC 分析 Codex 意见，构造回复（接受/反驳/后续优化）
6. CC 调用 codex MCP 工具（携带 SESSION_ID 继续对话）
7. 重复 5-6 直到达成一致或超过最大轮次
```

## 使用方法

### 前置条件

安装 CodexMCP 作为 MCP Server：

```bash
claude mcp add codex -s user --transport stdio -- uvx --from git+https://github.com/GuDaStudio/codexmcp.git codexmcp
```

### 命令触发

| 命令 | 功能 |
|------|------|
| `/review plan` | 计划审查（同时创建新审查周期） |
| `/review code` | 代码审查（要求已有活跃周期） |
| `/review final` | 最终验收（要求已有活跃周期） |
| `/review status` | 查看当前审查状态 |
| `/review reset plan` | 重置计划审查阶段的会话 |
| `/review reset code` | 重置代码审查阶段的会话 |
| `/review reset final` | 重置最终验收阶段的会话 |
| `/review reset-all` | 重置所有阶段的会话 |
| `/review config dir <路径>` | 修改计划文档目录 |

### 自然语言触发

Skill 也支持自然语言触发，CC 会根据意图自动路由到对应阶段：

- "让 codex 审查一下这个计划" / "审查计划" -> 计划审查
- "代码写完了，发给 codex 检查" / "审查代码" -> 代码审查
- "让 codex 做个最终验收" / "整体验收一下" -> 最终验收
- "审查进度怎么样了" -> 查看状态
- "重置审查会话" -> 重置

### 典型工作流

```
# 1. 在 CC 中完成实施计划（plan mode 或手动编写）
#    计划文档放在 doc/ 目录下

# 2. 让 Codex 审查计划
/review plan
#    -> CC 自动收集计划内容、项目背景
#    -> 发给 Codex 审查
#    -> CC 与 Codex 自动 battle（接受合理意见、反驳错误意见）
#    -> 达成一致后保存共识计划

# 3. 按共识计划编写代码...

# 4. 让 Codex 审查代码
/review code
#    -> CC 收集 git diff、读取共识计划
#    -> 发给 Codex 对比审查
#    -> battle 过程中 CC 会实际修改代码
#    -> 达成一致后记录审查结果

# 5. 所有代码完成后，最终验收
/review final
#    -> CC 收集完整 diff + 计划 + 历史审查日志
#    -> Codex 从整体角度验收
#    -> 通过后自动关闭审查周期
```

### Debug 模式

默认情况下只返回 Codex 的最终结论。如需查看完整交互过程：

- 告诉 CC "debug 模式" / "查看交互过程" / "显示完整对话"
- CC 会将 `return_all_messages` 设为 `true`，返回 Codex 的思考过程和工具调用记录

## 三阶段审查详解

### 阶段一：计划审查 (`/review plan`)

**目的**：在编码前确保实施计划的架构合理性、技术可行性和完整性。

**审查维度**：
1. 架构合理性 - 是否符合项目现有架构？是否引入不必要的复杂度？
2. 技术可行性 - 技术方案在当前技术栈版本下是否可行？
3. 完整性 - 是否覆盖所有必要修改点？是否遗漏边界情况？
4. 风险点 - 性能、安全、兼容性等风险
5. 改进建议 - 可优化的地方

**执行流程**：
1. 自动检测过期周期 + 创建新审查周期（如果没有活跃周期）
2. 从 `doc/` 目录或对话上下文收集计划内容
3. 读取项目背景（优先 `CLAUDE.md`，其次 `.claude/CLAUDE.md`）
4. 构造 Prompt 发送给 Codex
5. 进入 battle 循环（最多 5 轮）
6. 达成一致后保存共识计划到周期目录和用户可见的 `doc/` 目录
7. 归档该阶段会话

**计划文档查找优先级**：
1. `$PWD/doc/` 下最近修改的 `.md` 文件
2. 当前对话上下文中的计划内容
3. 周期目录内的 `plan.md` 缓存

### 阶段二：代码审查 (`/review code`)

**目的**：确保代码实现符合共识计划，发现质量和安全问题。

**审查维度**：
1. 计划符合度 - 代码是否按计划实现？
2. 代码质量 - 命名、注释、异常处理、边界条件
3. 架构一致性 - 是否符合项目分层规范？
4. 性能考量 - N+1 查询、缺少索引等
5. 安全性 - 注入、越权、信息泄露
6. 可测试性 - 是否便于单元测试？

**特殊行为**：
- 自动探测基线分支（origin/HEAD -> main -> master）并收集完整差异（提交差异 + 工作区改动）
- 如果 diff 超过 8000 行，自动按模块分批审查
- battle 过程中如果 CC 接受了修改意见，会**先实际修改代码**，然后将最新 diff 发给 Codex 复查
- 同一个审查周期内可以多次执行 `/review code`（每次代码审查使用独立的 Codex session，归档后下次创建新 session）

### 阶段三：最终验收 (`/review final`)

**目的**：从全局视角验收整个功能的完整实现。

**审查维度**：
1. 计划完整实现 - 每个计划点是否都已实现？
2. 代码整体质量 - 风格一致性、可维护性
3. 集成风险 - 模块间集成是否存在风险？
4. 遗留问题 - 未解决的 TODO 或已知问题
5. 上线准备 - 是否具备上线条件？

**特殊行为**：
- 会读取历史审查日志（如果存在），让 Codex 了解之前的审查过程
- battle 最多 3 轮（比计划和代码审查更严格）
- 通过后调用 `complete-all` 关闭整个审查周期

## 自动 Battle 机制

所有审查阶段共享同一套 battle 循环逻辑，这是整个 Skill 的核心。

### 循环流程

```
当前轮次 = 1
最大轮次 = 阶段配置值（plan: 5, code: 5, final: 3）

WHILE 当前轮次 <= 最大轮次 AND 未达成一致:

  1. CC 逐条分析 Codex 意见:
     - 明确 bug / 逻辑错误 -> 接受
     - 合理架构建议且符合项目约束 -> 接受
     - 基于错误前提的意见 -> 反驳并提供正确上下文
     - 风格偏好 / 非关键优化 -> 低成本则接受，否则标记"后续优化"

  2. CC 构造回复（列出接受/反驳/后续优化 + 更新后的内容）

  3. 调用 codex MCP 工具（携带 SESSION_ID 继续对话）

  4. 判断是否达成一致:
     - Codex 回复 "APPROVE" -> 达成一致
     - Codex 回复无 [必须修改] 标记 -> 达成一致
     - 否则 -> 轮次 +1，继续 battle

超过最大轮次: 输出分歧摘要，由用户最终裁决
```

### CC 回复模板

每轮 battle 中 CC 按以下结构回复 Codex：

```markdown
## CC 回复（第 N 轮）

### 已接受的修改
1. [意见摘要] -> 已按建议修改：[具体调整说明]

### 不同意的观点
1. [意见摘要] -> 不同意，理由：[详细理由和项目上下文]

### 标记为后续优化
1. [意见摘要] -> 认可价值，但当前优先级不高

### 更新后的内容
[更新后的计划文本 或 更新后的代码 diff]

请基于以上回复重新审查，如果所有 [必须修改] 项已解决，请回复 APPROVE。
```

### 用户可见信息

battle 过程中，CC 会向用户展示：
- 当前轮次 / 最大轮次
- Codex 的主要意见摘要（非完整原文，除非用户要求）
- CC 的处理决策（接受/反驳/标记后续）
- 当前状态（继续 battle / 已达成一致 / 需要用户裁决）

用户可随时输入 "stop" 中断 battle，手动处理剩余分歧。

## 审查周期（Review Cycle）

### 设计动机

早期版本中，`plan.md` 和 `review-log.md` 存放在扁平的 `.cc-codex/` 目录中，没有生命周期管理。这导致：
- 不同功能的审查数据混在一起
- 旧数据无限累积
- 跨 CC 会话时无法区分新旧审查

周期机制将每次审查流程隔离在独立目录中，解决上述问题。

### 周期状态

| 状态 | 含义 | 转换条件 |
|------|------|---------|
| `active` | 正在进行的审查 | `cycle-init` 创建时设置 |
| `completed` | 正常完成 | `complete-all` 关闭时设置 |
| `abandoned` | 超时未完成 | `auto-cleanup` 检测到过期时设置 |

同一时刻只有一个 `active` 周期。

### 周期生命流程

```
┌─────────────┐
│ /review plan│  （用户触发）
└──────┬──────┘
       │
       v
┌──────────────┐     已有活跃周期？
│ auto-cleanup │────── 是 ──> 检查是否过期
└──────┬───────┘              │
       │                 过期 -> abandoned
       │               未过期 -> 继续使用
       v
┌──────────────┐     已有活跃周期？
│  cycle-init  │────── 是 ──> 返回现有周期目录
└──────┬───────┘
       │ 否
       v
  创建新周期目录
  写入 cycle.meta (status=active)
  更新 current-cycle 指针
  触发 cycle-cleanup（保留最近 5 个旧周期）
       │
       v
  进行 plan / code / final 审查
       │
       v
┌──────────────┐
│ complete-all │  （final review 通过后）
└──────┬───────┘
       │
  归档所有 session 文件
  写入 status=completed + completed_at
  清除 current-cycle 指针
       │
       v
  周期结束，下次 /review plan 创建新周期
```

### 数据目录结构

```
项目根目录/
└── .cc-codex/                         # 审查运行时数据（不提交到 git）
    ├── config                         # 全局配置（PLAN_DOC_DIR 等）
    ├── current-cycle                  # 纯文本指针 -> 当前活跃周期目录名
    └── cycles/
        ├── 20260209-143000/           # 一个审查周期
        │   ├── cycle.meta             # 元数据文件
        │   ├── plan.md               # 本周期的共识计划
        │   ├── review-log.md         # 本周期的审查日志
        │   └── sessions/
        │       ├── plan-review.session        # 活跃会话 ID
        │       ├── code-review.session
        │       ├── final-review.session
        │       ├── .last-activity             # Unix 时间戳
        │       ├── plan-review.20260209-150000.archived  # 归档
        │       └── code-review.20260209-160000.archived
        ├── 20260208-100000/           # 已完成的旧周期
        │   ├── cycle.meta             # status=completed
        │   └── ...
        └── 20260207-090000/           # 已废弃的旧周期
            ├── cycle.meta             # status=abandoned
            └── ...
```

### cycle.meta 格式

```
status=active
description=用户认证模块重构
created_at=2026-02-09T14:30:00
completed_at=
```

`completed_at` 在周期关闭时写入。

### current-cycle 指针

纯文本文件，内容为活跃周期的目录名（非完整路径），例如 `20260209-143000`。

选择纯文本指针而非符号链接的原因：跨平台兼容性更好，避免 Windows/macOS/Linux 的符号链接行为差异。

## 会话管理实现

### session-manager.sh

这是整个 Skill 的状态管理核心，一个纯 Bash 脚本，负责所有磁盘状态的读写。CC 的 skill.md 通过 Bash 调用它来管理状态。

#### 命令一览

| 命令 | 参数 | 功能 |
|------|------|------|
| `read` | `<project_root> <phase>` | 读取指定阶段的 SESSION_ID |
| `save` | `<project_root> <phase> <sid>` | 保存 SESSION_ID + 更新活动时间 |
| `reset` | `<project_root> <phase>` | 删除指定阶段的 session 文件 |
| `reset-all` | `<project_root>` | 删除所有阶段的 session 文件 |
| `complete` | `<project_root> <phase>` | 归档指定阶段（重命名为 .archived） |
| `complete-all` | `<project_root>` | 归档所有 + 标记周期 completed + 清除指针 |
| `check-stale` | `<project_root> [分钟]` | 检查是否过期，返回状态字符串 |
| `auto-cleanup` | `<project_root> [分钟]` | 检测过期周期并标记 abandoned |
| `cycle-init` | `<project_root> [描述]` | 创建新周期或返回现有活跃周期 |
| `cycle-current` | `<project_root>` | 输出当前周期目录完整路径 |
| `cycle-cleanup` | `<project_root> [保留数]` | 清理旧周期，保留最近 N 个 |
| `status` | `<project_root>` | 彩色输出审查状态总览 |

阶段名（phase）取值：`plan-review` | `code-review` | `final-review`

#### 关键内部函数

```
read_current_cycle()     从 current-cycle 指针文件读取周期目录名
current_cycle_dir()      返回活跃周期的完整路径
current_sessions_dir()   返回活跃周期的 sessions/ 子目录路径
session_file()           返回指定阶段的 .session 文件路径
activity_file()          返回 .last-activity 文件路径
touch_activity()         写入当前 Unix 时间戳到 .last-activity
read_meta()              从 cycle.meta 读取指定 key 的值
write_meta()             写入/更新 cycle.meta 中的 key=value
require_cycle()          断言活跃周期存在，否则报错退出
```

#### 过期检测逻辑

```bash
# check-stale 返回值：
# exit 0 + "stale|分钟数|上次活动时间"  -> 过期
# exit 1 + "fresh|分钟数"              -> 仍活跃
# exit 2 + "no-session"               -> 无活动记录

# auto-cleanup 处理：
# 1. 无活跃周期 -> 静默跳过
# 2. check-stale 返回非过期 -> 静默跳过
# 3. check-stale 返回过期 -> 标记 abandoned + 清除指针
```

#### 周期清理策略

```
1. 列出 cycles/ 下所有目录，按时间戳倒序排列
2. 跳过当前活跃周期
3. 收集 completed 和 abandoned 状态的周期
4. 如果总数 <= 保留数量（默认 5），不清理
5. 保留最新的 N 个，删除其余
6. 保护机制：至少保留 1 个 completed 周期（如果有的话）
```

## SESSION_ID 生命周期

SESSION_ID 是 Codex 端维持对话连续性的关键。每个审查阶段有独立的 SESSION_ID。

```
首次调用 codex MCP（不带 session_id）
  -> Codex 创建新会话，返回 SESSION_ID
  -> CC 通过 session-manager.sh save 保存到磁盘

后续同阶段调用（携带 session_id）
  -> Codex 在同一会话上下文中继续对话
  -> CC 和 Codex 的讨论历史在 Codex 端累积

阶段完成后
  -> CC 调用 session-manager.sh complete 归档
  -> .session 文件重命名为 .archived（带时间戳）
  -> read 返回空值，下次调用自动创建新 session

CC 会话中断/崩溃
  -> 旧 SESSION_ID 留在磁盘上
  -> 下次审查时 auto-cleanup 检测过期（60分钟阈值）
  -> 标记周期为 abandoned，指针清除
  -> /review plan 创建全新周期
```

### 跨会话问题

当用户关闭 CC 会话后重新打开，CC 端上下文丢失但 Codex 端 session 仍有效。这会导致 CC（空白上下文）和 Codex（有历史上下文）之间的认知不对称。

**解决方案：双重机制**
1. **主动归档**：审查完成时立即归档 session，避免残留
2. **过期兜底**：60 分钟无活动自动标记 abandoned，下次创建新周期

## 配置

### 计划文档目录

默认读取 `$PWD/doc/` 目录下的 `.md` 文件作为计划文档。

**自定义**：
```bash
# 通过命令修改
/review config dir plans

# 或手动编辑 .cc-codex/config
PLAN_DOC_DIR=plans
```

配置持久化在 `.cc-codex/config` 中，跨周期共享。

### .gitignore

首次运行时检查项目 `.gitignore` 是否包含 `.cc-codex/`。如果没有，会提示添加：

```
# CC-Codex 协作审查运行时数据
.cc-codex/
```

`.cc-codex/` 包含会话 ID、审查日志等运行时数据，不应提交到 git。

## 异常处理

| 场景 | 处理方式 |
|------|---------|
| Codex 调用失败 | 自动重试 1 次，仍失败则报告错误，询问用户是否手动继续 |
| SESSION_ID 失效 | 重置该阶段会话，重新开始（CC 端上下文仍在） |
| Codex 响应格式异常 | 展示原始响应，由用户判断 |
| git diff 超过 8000 行 | 按模块分批审查，每批不超过 3000 行 |
| battle 超过最大轮次 | 输出分歧摘要，由用户裁决 |
| 无活跃周期时执行 code/final | 报错并提示先执行 `/review plan` |

## 文件清单

```
cc-codex-review/
├── skill.md                    # Skill 定义文件（CC 的工作流 Prompt）
├── README.md                   # 本文档
└── scripts/
    └── session-manager.sh      # 会话 & 周期管理脚本
```

- `skill.md`：定义了 CC 在审查流程中应遵循的完整指令，包括 Prompt 模板、battle 逻辑、异常处理等。这是 CC 的 "剧本"。
- `session-manager.sh`：纯 Bash 实现的状态管理器，负责磁盘上所有审查状态的 CRUD。CC 通过 Bash 工具调用它。

## 外部依赖

| 依赖 | 用途 | 安装方式 |
|------|------|---------|
| CodexMCP | CC 与 Codex 的通信桥梁 | `claude mcp add codex -s user --transport stdio -- uvx --from git+https://github.com/GuDaStudio/codexmcp.git codexmcp` |
| Git | 收集代码变更 (diff) | 系统预装 |

CodexMCP 是一个无状态的 CLI 封装，底层调用 `codex exec`。它不做上下文管理，MCP 响应有 25000 token 的限制（CC 端设置），但 Codex 模型本身有 200k+ token 上下文，在结构化 Prompt 场景下足够使用。

## 设计约束

- **单用户设计**：本 Skill 面向个人开发者在单台机器上使用，session-manager.sh 不做并发锁控制。多终端同时对同一项目执行审查操作可能导致状态不一致。
- **Codex 只读模式**：所有 Codex 调用均使用 `sandbox: "read-only"`，Codex 不会修改任何项目文件，所有代码修改由 CC 执行。
