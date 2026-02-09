---
name: cc-codex-review
description: "CC-Codex 协作审查。让 Codex 审查计划、审查代码、验收。关键词: 审查, review, 让codex看看, codex审查, 帮我审查, 审查计划, 审查代码, 代码审查, 计划审查, 验收, 最终验收, 审查状态, 重置审查, battle, 让codex检查, 发给codex"
---

# CC-Codex 协作审查 Skill

通过 CodexMCP 实现 Claude Code 与 Codex 的全自动协作审查工作流。

## 触发条件

### 命令触发
- `/review plan` - 计划审查
- `/review code` - 代码审查
- `/review final` - 最终验收
- `/review status` - 查看审查状态
- `/review reset [phase]` - 重置指定阶段会话
- `/review reset-all` - 重置所有会话

### 自然语言触发

当用户的话语匹配以下意图时，自动触发对应阶段：

**计划审查（-> plan）：**
- "让 codex 审查一下这个计划"
- "把计划发给 codex 看看"
- "帮我审查一下实施方案"
- "这个计划你觉得行不行，让 codex 也看看"
- "审查计划" / "plan review"

**代码审查（-> code）：**
- "让 codex 审查一下代码"
- "代码写完了，发给 codex 检查"
- "帮我 review 一下这些改动"
- "让 codex 看看代码有没有问题"
- "审查代码" / "code review"

**最终验收（-> final）：**
- "代码都写完了，让 codex 做个最终验收"
- "整体验收一下"
- "最终审查" / "final review"

**查看状态（-> status）：**
- "审查进度怎么样了"
- "当前审查状态"

**重置（-> reset）：**
- "重置审查会话"
- "重新开始审查"

## 前置依赖

- CodexMCP 已安装为 MCP Server（名称: `codex`）
- 提供 `codex` 工具，支持 `prompt`、`session_id`、`sandbox`、`return_all_messages` 参数

## 通用配置

```
SESSION_MANAGER=~/.claude/skills/cc-codex-review/scripts/session-manager.sh
DATA_DIR=.cc-codex
CONFIG_FILE=$DATA_DIR/config
PLAN_DOC_DIR=doc              # 默认值，可由用户动态指定
MAX_PLAN_ROUNDS=5
MAX_CODE_ROUNDS=5
MAX_FINAL_ROUNDS=3
```

## 项目根目录识别

使用当前工作目录作为项目根目录（即 `$PWD`）。

## 计划文档目录配置

`PLAN_DOC_DIR` 表示用户可见的计划文档存放目录（相对于项目根目录），默认为 `doc`。

**读取优先级：**
1. 读取 `$PWD/$DATA_DIR/config` 中保存的 `PLAN_DOC_DIR` 值（用户之前指定过）
2. 如果 config 不存在，使用默认值 `doc`

**首次使用时：**
- 如果默认目录 `$PWD/doc/` 下找不到计划文档，询问用户指定目录
- 用户指定后，将目录路径保存到 `$PWD/$DATA_DIR/config`：
```
PLAN_DOC_DIR=<用户指定的相对路径>
```

**后续使用时：**
- 自动从 config 读取，无需重复询问
- 用户可通过 `/review config dir <新路径>` 修改

## 命令路由

解析用户输入的 `/review` 命令参数，路由到对应处理流程：

1. **`/review plan`** -> 执行「阶段一：计划审查」
2. **`/review code`** -> 执行「阶段二：代码审查」
3. **`/review final`** -> 执行「阶段三：最终验收」
4. **`/review status`** -> 执行 `$SESSION_MANAGER status $PWD`，展示结果
5. **`/review reset plan`** -> 执行 `$SESSION_MANAGER reset $PWD plan-review`
6. **`/review reset code`** -> 执行 `$SESSION_MANAGER reset $PWD code-review`
7. **`/review reset final`** -> 执行 `$SESSION_MANAGER reset $PWD final-review`
8. **`/review reset-all`** -> 执行 `$SESSION_MANAGER reset-all $PWD`
9. **`/review config dir <路径>`** -> 修改计划文档目录，保存到 `$PWD/$DATA_DIR/config`

## SESSION_ID 管理

每个审查阶段使用独立的 SESSION_ID，通过 session-manager.sh 管理：

**读取 SESSION_ID：**
```bash
SESSION_ID=$($SESSION_MANAGER read $PWD plan-review)
```

**保存 SESSION_ID（从 Codex 首次响应中提取）：**
```bash
$SESSION_MANAGER save $PWD plan-review "<session_id>"
```

**关键规则：**
- 首次调用 codex 工具时不传 session_id，从响应中提取并保存
- 后续同阶段调用必须携带已保存的 session_id
- 不同阶段使用不同的 session_id（plan-review / code-review / final-review）

## Codex MCP 工具调用规范

调用 `codex` MCP 工具时，使用以下参数：

**首次调用（无 SESSION_ID）：**
```
工具: codex
参数:
  prompt: <构造的审查 Prompt>
  sandbox: "read-only"
  return_all_messages: false
```

**后续调用（有 SESSION_ID）：**
```
工具: codex
参数:
  prompt: <构造的回复 Prompt>
  session_id: <已保存的 SESSION_ID>
  sandbox: "read-only"
  return_all_messages: false
```

**Debug 模式（仅在用户主动要求时开启）：**
- 当用户明确要求查看 Codex 的思考过程、工具调用记录等中间信息时，将 `return_all_messages` 设为 `true`
- 触发方式：用户说"debug 模式"、"查看交互过程"、"显示完整对话"等
- 非 debug 模式下，`return_all_messages` 始终为 `false`，仅返回 Codex 的最终结论

**从响应中提取 SESSION_ID：**
- Codex 响应的 JSON 中包含 `SESSION_ID` 字段（注意：字段名为大写）
- 首次调用后必须提取并保存

## 会话生命周期管理

### 主动归档（正常流程）

每个审查阶段完成并与用户确认结果后，主动归档该阶段的 Codex session：

```bash
# 单阶段归档
$SESSION_MANAGER complete $PWD plan-review

# 整个审查周期结束时归档所有阶段
$SESSION_MANAGER complete-all $PWD
```

- `complete` 将 `.session` 文件重命名为 `.archived`（带时间戳），保留历史记录
- 归档后 `read` 返回空值，下次审查自动从头开始
- 在阶段一/二的最后步骤中归档当前阶段；在阶段三（最终验收）完成后调用 `complete-all` 归档所有阶段

### 过期兜底（异常流程）

防止 CC 会话中途崩溃、未走到确认步骤时遗留脏数据：

**检测时机：** 在阶段一/二/三的 Step 1 之前自动执行。

**检测逻辑：**
```bash
$SESSION_MANAGER auto-cleanup $PWD 60
```

- 如果距离上次审查活动超过 60 分钟且仍有未归档的活跃会话，自动重置
- 重置后通知用户："检测到上次审查已结束（上次活动: [时间]），已自动清理旧会话，开始新的审查周期"
- 如果无历史会话或会话仍在活跃期内，静默跳过

**活动时间更新：**
- 每次保存 SESSION_ID 时自动更新活动时间戳（`session-manager.sh save` 内置）
- 无需手动维护

## 自动 Battle 核心逻辑

所有审查阶段共享同一套 battle 循环机制：

**循环流程：**

```
当前轮次 = 1
最大轮次 = 对应阶段配置值

WHILE 当前轮次 <= 最大轮次 AND 未达成一致:

  1. CC 逐条分析 Codex 意见:
     - 明确 bug / 逻辑错误 -> 接受
     - 合理架构建议且符合项目约束 -> 接受
     - 基于错误前提的意见 -> 反驳并提供正确上下文
     - 风格偏好 / 非关键优化 -> 低成本则接受，否则标记"后续优化"

  2. CC 构造回复:
     - 列出已接受的修改及具体调整
     - 列出不同意的观点及详细理由
     - 附上更新后的内容（计划/代码）

  3. 调用 codex MCP 工具（携带 SESSION_ID 继续对话）

  4. 判断是否达成一致:
     - Codex 响应包含 "APPROVE" -> 达成一致，退出循环
     - Codex 响应无 [必须修改] 标记 -> 达成一致，退出循环
     - 否则 -> 当前轮次 + 1，继续 battle

超过最大轮次: 输出分歧摘要，由用户最终裁决
```

**CC 回复 Codex 的格式模板：**

```
## CC 回复（第 N 轮）

### 已接受的修改
1. [意见摘要] -> 已按建议修改：[具体调整说明]
2. ...

### 不同意的观点
1. [意见摘要] -> 不同意，理由：[详细理由和项目上下文]
2. ...

### 标记为后续优化
1. [意见摘要] -> 认可价值，但当前阶段优先级不高，标记后续处理

### 更新后的内容
[更新后的计划文本 或 更新后的代码 diff]

请基于以上回复重新审查，如果所有 [必须修改] 项已解决，请回复 APPROVE。
```

## 阶段一：计划审查 (`/review plan`)

### 前置条件
- CC 已生成实施计划（plan mode 产出或手动编写）

### 执行步骤

**Step 0: 会话新鲜度检测**
```bash
$SESSION_MANAGER auto-cleanup $PWD 60
```

**Step 1: 确定计划文档目录并收集计划内容**
- 先读取 `$PWD/$DATA_DIR/config` 获取 `PLAN_DOC_DIR`，如果不存在则使用默认值 `doc`
- 按以下优先级查找计划文档：
  1. `$PWD/$PLAN_DOC_DIR/` 目录下最近修改的 `.md` 文件（用户可见的计划文档）
  2. 当前对话上下文中已生成的计划内容
  3. `$PWD/.cc-codex/plan.md`（内部缓存）
- 如果 `$PWD/$PLAN_DOC_DIR/` 目录不存在或为空，询问用户指定计划文档目录，保存到 config
- 如果都没有，报错退出并提示用户先生成计划
- 找到后，将计划内容同步缓存到 `$PWD/.cc-codex/plan.md`（供后续阶段引用）

**Step 2: 初始化审查目录**
```bash
mkdir -p $PWD/.cc-codex/sessions
```

**Step 3: 读取项目背景**
- 读取项目的 `.claude/CLAUDE.md` 获取技术栈和架构信息
- 提取关键信息：技术栈、架构模式、编码规范

**Step 4: 构造首轮 Prompt 并调用 Codex**

使用以下模板构造 Prompt，调用 `codex` MCP 工具（不带 session_id）：

```
你是一位资深架构师，正在审查一个实施计划。

## 项目背景
[从 CLAUDE.md 提取的技术栈和架构信息摘要]

## 待审查的实施计划
[计划内容]

## 审查要求
请从以下五个维度进行审查：

1. **架构合理性**: 是否符合项目现有架构模式？是否引入不必要的复杂度？
2. **技术可行性**: 所用技术方案在当前技术栈版本下是否可行？
3. **完整性**: 是否覆盖了所有必要的修改点？是否遗漏了边界情况？
4. **风险点**: 是否存在性能、安全、兼容性等风险？
5. **改进建议**: 有哪些可以优化的地方？

## 输出格式要求
- 每条意见标注优先级：[必须修改] / [建议优化] / [疑问]
- 最终给出结论：APPROVE 或 REQUEST_CHANGES
- 如果 REQUEST_CHANGES，列出所有 [必须修改] 项
```

**Step 5: 提取 SESSION_ID 并保存**
```bash
$SESSION_MANAGER save $PWD plan-review "<从响应中提取的session_id>"
```

**Step 6: 解析 Codex 响应并进入 Battle**
- 解析响应，判断 APPROVE 或 REQUEST_CHANGES
- 如果 APPROVE -> 跳到 Step 7
- 如果 REQUEST_CHANGES -> 按「自动 Battle 核心逻辑」进入循环（最多 5 轮）
- 每轮向用户展示当前轮次和 Codex 的主要意见摘要

**Step 7: 保存共识计划**
- 达成一致后：
  1. 将最终计划缓存到 `$PWD/.cc-codex/plan.md`（内部引用）
  2. 同步更新 `$PWD/$PLAN_DOC_DIR/` 下对应的计划文档（用户可见版本）
     - 如果 Step 1 中计划来源是 `$PLAN_DOC_DIR/` 下的某个文件，则更新该文件
     - 否则，创建 `$PWD/$PLAN_DOC_DIR/<功能名称>-实施计划.md`
  3. 追加审查记录到 `$PWD/.cc-codex/review-log.md`
- 追加审查记录到 `$PWD/.cc-codex/review-log.md`，格式：

```markdown
## 计划审查 - [日期时间]
- 轮次: N
- 结论: APPROVE
- 主要修改: [摘要]
```

- 向用户报告审查完成
- 用户确认结果后，归档该阶段会话：
```bash
$SESSION_MANAGER complete $PWD plan-review
```

## 阶段二：代码审查 (`/review code`)

### 前置条件
- 已存在共识计划（`$PLAN_DOC_DIR/` 或 `.cc-codex/plan.md`）
- CC 已完成一个阶段的代码编写

### 执行步骤

**Step 0: 会话新鲜度检测**
```bash
$SESSION_MANAGER auto-cleanup $PWD 60
```

**Step 1: 检查前置条件并读取计划**
- 先读取 `$PWD/$DATA_DIR/config` 获取 `PLAN_DOC_DIR`，如果不存在则使用默认值 `doc`
- 按以下优先级查找计划：
  1. `$PWD/$PLAN_DOC_DIR/` 下的计划文档（用户可能手动修改过）
  2. `$PWD/.cc-codex/plan.md`（内部缓存）
- 如果都不存在，提示用户先执行 `/review plan`
- 如果 `$PLAN_DOC_DIR/` 版本比 `.cc-codex/plan.md` 更新，同步覆盖缓存

**Step 2: 收集代码变更**
```bash
git diff master...HEAD
```
- 如果 diff 输出超过 8000 行，按文件分批处理
- 分批策略：按目录或模块分组，每批不超过 3000 行

**Step 3: 读取共识计划**
- 读取 `$PWD/.cc-codex/plan.md` 内容

**Step 4: 构造首轮 Prompt 并调用 Codex**

使用以下模板构造 Prompt：

```
你是一位资深代码审查员，正在审查代码变更是否符合既定计划。

## 共识计划
[plan.md 内容]

## 代码变更 (git diff)
[diff 内容]

## 审查维度
1. **计划符合度**: 代码是否按计划实现？是否有遗漏或偏离？
2. **代码质量**: 命名规范、注释完整性、异常处理、边界条件
3. **架构一致性**: 是否符合项目现有架构模式和分层规范？
4. **性能考量**: 是否存在 N+1 查询、缺少索引、不必要的循环等问题？
5. **安全性**: 是否存在注入、越权、敏感信息泄露等风险？
6. **可测试性**: 代码是否便于单元测试？依赖是否可 mock？

## 输出格式要求
- 每条意见标注优先级：[必须修改] / [建议优化] / [疑问]
- 指出具体文件和行号
- 最终给出结论：APPROVE 或 REQUEST_CHANGES
```

**Step 5: 提取 SESSION_ID 并保存**
```bash
$SESSION_MANAGER save $PWD code-review "<从响应中提取的session_id>"
```

**Step 6: 解析响应并进入 Battle**
- 按「自动 Battle 核心逻辑」进入循环（最多 5 轮）
- **代码审查特殊规则**: 如果 CC 接受了代码修改意见，需要：
  1. 先实际修改代码文件
  2. 重新执行 `git diff master...HEAD` 收集最新 diff
  3. 将修改说明 + 最新 diff 一起发给 Codex

**Step 7: 记录审查结果**
- 追加审查记录到 `$PWD/.cc-codex/review-log.md`：

```markdown
## 代码审查 - [日期时间]
- 轮次: N
- 结论: APPROVE
- 审查文件: [文件列表]
- 主要修改: [摘要]
```

- 用户确认结果后，归档该阶段会话：
```bash
$SESSION_MANAGER complete $PWD code-review
```

## 阶段三：最终验收 (`/review final`)

### 前置条件
- 所有代码编写完成
- 建议已完成代码审查（非强制）

### 执行步骤

**Step 0: 会话新鲜度检测**
```bash
$SESSION_MANAGER auto-cleanup $PWD 60
```

**Step 1: 收集完整变更**
```bash
git diff master...HEAD
```

**Step 2: 读取计划和历史审查日志**
- 先读取 `$PWD/$DATA_DIR/config` 获取 `PLAN_DOC_DIR`，如果不存在则使用默认值 `doc`
- 按以下优先级查找计划：
  1. `$PWD/$PLAN_DOC_DIR/` 下的计划文档（用户可能手动修改过，以此为准）
  2. `$PWD/.cc-codex/plan.md`（内部缓存）
- 如果 `$PLAN_DOC_DIR/` 版本比 `.cc-codex/plan.md` 更新，同步覆盖缓存
- 读取 `$PWD/.cc-codex/review-log.md`（如果存在）

**Step 3: 构造验收 Prompt 并调用 Codex**

```
你是一位资深技术负责人，正在对一个功能的完整实现进行最终验收。

## 共识计划
[plan.md 内容]

## 历史审查记录
[review-log.md 内容，如果存在]

## 完整代码变更 (git diff)
[diff 内容]

## 验收维度
1. **计划完整实现**: 计划中的每个点是否都已实现？
2. **代码整体质量**: 整体代码风格一致性、可维护性
3. **集成风险**: 各模块间的集成是否存在风险？
4. **遗留问题**: 是否有未解决的 TODO 或已知问题？
5. **上线准备**: 是否具备上线条件？

## 输出格式要求
- 每条意见标注：[必须修改] / [建议优化] / [已知风险]
- 最终给出：APPROVE 或 REQUEST_CHANGES
- 输出验收报告摘要
```

**Step 4: 提取 SESSION_ID 并保存**
```bash
$SESSION_MANAGER save $PWD final-review "<从响应中提取的session_id>"
```

**Step 5: 进入 Battle 并输出验收报告**
- 按「自动 Battle 核心逻辑」进入循环（最多 3 轮，更严格）
- 达成一致后，生成验收报告并追加到 `$PWD/.cc-codex/review-log.md`：

```markdown
## 最终验收 - [日期时间]
- 轮次: N
- 结论: APPROVE
- 验收摘要: [Codex 的验收报告摘要]
- 遗留事项: [如有]
```

- 用户确认验收结果后，归档所有阶段会话（审查周期结束）：
```bash
$SESSION_MANAGER complete-all $PWD
```

## 异常处理

### Codex 调用失败
- 重试一次，仍失败则向用户报告错误信息
- 展示当前审查进度，询问用户是否手动继续

### SESSION_ID 失效
- 当 Codex 返回 session 相关错误时，重置该阶段会话：
```bash
$SESSION_MANAGER reset $PWD <phase>
```
- 重新开始该阶段审查（CC 端上下文仍在，只丢失 Codex 端历史）

### 响应格式异常
- 如果 Codex 响应中无法识别 APPROVE / REQUEST_CHANGES
- 将原始响应展示给用户，由用户判断是否继续

### diff 过大
- 如果 `git diff` 输出超过 8000 行，自动按模块分批
- 每批独立审查，最后汇总结果

## 用户交互规范

### Battle 过程中的信息展示
每轮 battle 向用户展示：
- 当前轮次 / 最大轮次
- Codex 的主要意见摘要（不展示完整原文，除非用户要求）
- CC 的处理决策（接受/反驳/标记后续）
- 当前状态（继续 battle / 已达成一致 / 需要用户裁决）

### 用户干预点
- Battle 超过最大轮次时，展示分歧摘要，等待用户裁决
- 用户可随时输入 "stop" 中断 battle，手动处理

## 注意事项

### .gitignore 配置
首次运行时，检查项目 `.gitignore` 是否包含 `.cc-codex/`，如果没有则提示用户添加：
```
# CC-Codex 协作审查运行时数据
.cc-codex/
```

### 数据安全
- `.cc-codex/` 目录包含审查过程数据，不应提交到 git
- SESSION_ID 文件仅在本地使用，不包含敏感信息
- 计划和审查日志可能包含业务信息，注意不要泄露

### CodexMCP 依赖
- 本 Skill 依赖 `codex` MCP 工具
- 如果 codex 工具不可用，所有审查命令将报错并提示安装
- 安装命令：`claude mcp add codex -s user --transport stdio -- uvx --from git+https://github.com/GuDaStudio/codexmcp.git codexmcp`
