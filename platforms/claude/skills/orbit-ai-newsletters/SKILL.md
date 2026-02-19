---
name: orbit-ai-newsletters
description: "AI 新闻简报，多源抓取去重排序生成每日摘要。Keywords: AI新闻, newsletters, AI动态, 新闻简报, TLDR, AI news"
---
执行前先读取 `orbit-os/SKILL.md` 获取 Vault 结构和排版规范。

# AI 新闻简报

抓取、去重、排序 AI 新闻内容，生成每日摘要。

## 数据源

### RSS（主源）
- **TLDR AI**: `https://bullrich.dev/tldr-rss/ai.rss`
- **The Rundown AI**: `https://rss.beehiiv.com/feeds/2R3C6Bt5wj.xml`

### 扩展源（通过已有 Skill 获取）

执行前询问用户今日关注的关键词或话题，用户无输入则使用默认值。

| 源 | 获取方式（将 `{keywords}` 替换为用户关键词，默认 `"AI OR LLM OR Claude"`） | 用途 |
|----|---------|------|
| X/Twitter | `bird --cookie-source chrome search "{keywords}" -n 10 --plain` | 英文AI热点讨论 |
| Reddit | Composio MCP `REDDIT_SEARCH_ACROSS_SUBREDDITS` 搜索 `{keywords}`（默认 `"AI"`） | r/MachineLearning 等社区深度讨论 |
| LINUX DO | `python3 "$HOME/.claude/skills/linuxdo/scripts/linuxdo.py" search "{keywords}" --limit 10`（默认 `"AI"`） | 中文AI社区视角 |

## 工作流

1. **检查缓存**: 查找 `05_资源/Newsletters/YYYY-MM/YYYY-MM-DD-摘要.md`，存在则返回缓存
2. **抓取多源数据**:
   - WebFetch 获取 RSS 源，提取 title, link, pubDate, description
   - 并行调用扩展源（任一失败则静默跳过，不阻塞流程）
3. **去重**: 标题 80%+ 词重叠的合并，保留较长描述（跨源去重）
4. **排序**: AI 相关性 > 生产力相关性 > 时效性 > 新颖性
5. **生成摘要**: 精选推荐 (3-5条) + AI动态 + 社区热议 + 生产力工具 + 统计
6. **保存**:
   - `05_资源/Newsletters/YYYY-MM/YYYY-MM-DD-摘要.md`
   - `05_资源/Newsletters/YYYY-MM/原始数据/YYYY-MM-DD_TLDR-AI-Raw.md`
   - `05_资源/Newsletters/YYYY-MM/原始数据/YYYY-MM-DD_Rundown-AI-Raw.md`

## 输出格式

**手动调用**: 显示完整摘要。

**来自其他 skill**: 返回精简列表:
```
**内容机会 (5):**
- [标题] - [角度]
完整摘要: [[YYYY-MM-DD-摘要]]
```

## 错误处理
- 单个 RSS 源不可用: 继续其他源，在摘要中注明
- 全部 RSS 不可用: 使用昨日存档并警告
- 扩展源失败（认证过期、网络问题）: 静默跳过，仅用 RSS 源，摘要末尾注明
- 空结果: 创建最小摘要注明"今日无新内容"
