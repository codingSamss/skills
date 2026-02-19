# AI 新闻简报

抓取、去重、排序 AI 新闻内容，生成每日摘要。

## RSS 源

- **TLDR AI**: `https://bullrich.dev/tldr-rss/ai.rss`
- **The Rundown AI**: `https://rss.beehiiv.com/feeds/2R3C6Bt5wj.xml`

## 工作流

1. **检查缓存**: 查找 `50_资源/Newsletters/YYYY-MM/YYYY-MM-DD-摘要.md`，存在则返回缓存
2. **抓取 RSS**: 用 WebFetch 获取两个源，提取 title, link, pubDate, description
3. **去重**: 标题 80%+ 词重叠的合并，保留较长描述
4. **排序**: AI 相关性 > 生产力相关性 > 时效性 > 新颖性
5. **生成摘要**: 精选推荐 (3-5条，含内容角度) + AI动态 + 生产力工具 + 统计
6. **保存**:
   - `50_资源/Newsletters/YYYY-MM/YYYY-MM-DD-摘要.md`
   - `50_资源/Newsletters/YYYY-MM/原始数据/YYYY-MM-DD_TLDR-AI-Raw.md`
   - `50_资源/Newsletters/YYYY-MM/原始数据/YYYY-MM-DD_Rundown-AI-Raw.md`

## 输出格式

**手动调用**: 显示完整摘要。

**来自 start-my-day**: 返回精简列表:
```
**内容机会 (5):**
- [标题] - [角度]
完整摘要: [[YYYY-MM-DD-摘要]]
```

## 错误处理
- 单源不可用: 继续另一源，在摘要中注明
- 双源不可用: 使用昨日存档并警告
- 空结果: 创建最小摘要注明"今日无新内容"
