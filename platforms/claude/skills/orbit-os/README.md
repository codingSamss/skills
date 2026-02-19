# orbit-os

## 作用
基于 Obsidian 的 AI 驱动个人知识管理与日常规划系统。通过子命令管理日记、项目、研究、知识库等。

## 平台支持
- Claude Code

## 依赖
- Obsidian（库路径: `~/Documents/Obsidian Vault`）

## 子命令
| 命令 | 说明 |
|------|------|
| `/orbit-os start-my-day` | 晨间规划，回顾昨日、规划今日 |
| `/orbit-os kickoff <想法>` | 将想法/收件箱条目转为项目 |
| `/orbit-os research <主题>` | 深度研究，生成研究笔记+知识库条目 |
| `/orbit-os ask <问题>` | 快速问答，可选存入知识库 |
| `/orbit-os brainstorm <话题>` | 交互式头脑风暴 |
| `/orbit-os parse-knowledge <文本>` | 非结构化文本整理入库 |
| `/orbit-os archive` | 归档已完成项目和已处理收件箱 |
| `/orbit-os ai-newsletters` | AI 新闻简报摘要 |
| `/orbit-os ai-products` | AI 产品发布追踪 |

## 配置
```bash
./setup.sh
```

## 验证
确认 `~/Documents/Obsidian Vault` 下存在 `00_收件箱`、`10_日记`、`20_项目` 等目录。

## 使用方式
```
/orbit-os start-my-day
/orbit-os kickoff 做一个习惯追踪App
/orbit-os research React Server Components
/orbit-os ask 什么是 CAP 定理
```
