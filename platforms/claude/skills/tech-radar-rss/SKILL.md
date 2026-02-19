---
name: tech-radar-rss
description: "技术前沿资讯检索，通过 RSS/API 多源关键词搜索技术新闻和趋势。Keywords: tech radar, 技术资讯, 技术前沿, AI news, GitHub trending, tech news, 科技新闻, 技术新闻, 前沿动态"
interests:
  - "LLM inference"
  - "AI agents"
  - "MCP"
  - "local models"
---

# 技术前沿资讯

通过 RSS/API 源按关键词检索技术新闻，补充 X/Reddit 覆盖不到的渠道。

## 关键词策略

1. 读取 YAML 头中的 `interests` 列表作为默认关键词
2. 执行时向用户展示当前列表，询问："用这些关键词，还是今天有特别想查的？"
3. 用户可以：直接确认用默认 / 临时替换或追加 / 要求更新持久化列表

## 数据源

所有源均支持关键词检索，将 `{keywords}` 替换为用户关键词（多个关键词用 `+` 或空格连接）。

| 源 | URL 模板 | 返回格式 |
|----|---------|---------|
| GitHub Search | `https://api.github.com/search/repositories?q={keywords}+created:%3E{7d_date}+stars:%3E50&sort=stars&per_page=10` | JSON |
| The Decoder | `https://the-decoder.com/?s={keywords}&feed=rss2` | RSS/XML |
| MarkTechPost | `https://www.marktechpost.com/?s={keywords}&feed=rss2` | RSS/XML |

时间变量：
- `{7d_date}`: 当前日期减 7 天，格式 `YYYY-MM-DD`

注意：The Decoder 和 MarkTechPost 的 WordPress 搜索返回全站历史匹配，抓取后须按 `pubDate` 过滤，仅保留近 7 天内的结果。

## 工作流

1. **确认关键词**：展示 interests 列表，等用户确认或修改
2. **并行抓取**：对每个关键词，并行请求所有源（WebFetch）
3. **提取**：从各源提取标题、URL、描述、互动指标（GitHub stars）
4. **时间过滤**：WordPress RSS 源（The Decoder、MarkTechPost）按 `pubDate` 过滤，仅保留近 7 天
4. **去重**：URL 归一化去重；标题指向同一事件的，由 LLM 在生成摘要时合并
5. **生成摘要**：按信号强度分档输出

## 输出格式

```markdown
## 技术前沿 (YYYY-MM-DD)
关键词: {实际使用的关键词}

### 重要动态
- [标题](URL) - 一句话摘要 [来源] [指标]

### 值得关注
- ...

### 信息碎片
- ...

---
数据源: {实际成功的源列表} | 失败: {静默跳过的源}
```

排序逻辑：
- 跨源出现次数（多源提及 = 高信号）> 互动指标（GitHub stars/1000）> 时效性

## 错误处理

- 任一源失败：静默跳过，不阻塞其他源
- GitHub API 有速率限制（未认证 10 次/分钟），失败时静默降级
- 全部源失败或结果为空：告知用户"当前关键词无相关资讯，建议调整关键词"
- 摘要末尾注明实际使用的源和跳过的源

## 与其他 Skill 的关系

- **并列独立**：不内部调用 bird-twitter / reddit skill，作为 RSS/API 补充渠道
- **X/Twitter 首页**：如需同时获取用户首页，使用 `bird --cookie-source chrome home -n 15 --plain`
- **存储解耦**：本 skill 不涉及 Obsidian 存储。用户需要保存时，由 Claude 读取 `orbit-os` skill 获取 Vault 规范