# Personal Claude Code Skills

个人 Claude Code 技能集合，以 CC 插件格式打包，支持一步安装。

## 包含的 Skills

| Skill | 功能 | 外部依赖 |
|-------|------|---------|
| bird-twitter | 通过 Bird CLI 阅读 X/Twitter 内容 | Bird CLI |
| cc-codex-review | CC-Codex 协作讨论 | Codex MCP |
| peekaboo | macOS 截图与视觉分析 | Peekaboo |
| plugin-manager | Claude Code 插件管理 | - |
| ui-ux-pro-max | UI/UX 设计智能助手 | Python 3 |

## 其他组件

- **hooks/notify.sh** - 任务完成通知 hook
- **agents/** - 自定义 agent 配置（codex-battle-agent, tech-research-advisor）

## 安装

### 方式一：插件安装（推荐）

```bash
# 1. 添加 marketplace 并安装插件
claude plugin marketplace add codingSamss-skills --github codingSamss/skills
claude plugin install personal-skills@codingSamss-skills

# 2. 运行 setup 脚本安装外部依赖并创建符号链接
./setup.sh

# 3. 重启 Claude Code 验证
claude
```

### 方式二：手动安装

```bash
# 1. 克隆仓库
git clone https://github.com/codingSamss/skills.git
cd skills

# 2. 运行 setup 脚本
./setup.sh
```

## 新机器完整迁移流程

1. 安装 [Claude Code](https://claude.ai/code)
2. 克隆本仓库或通过插件系统安装
3. 运行 `./setup.sh` 安装外部依赖（Homebrew 工具）并创建符号链接
4. 启动 Claude Code，测试各 skill（如 `/bird-twitter`、`/cc-codex-review`）

## 外部依赖

| 依赖 | 安装方式 | 被谁使用 |
|------|---------|---------|
| Bird CLI | `brew install steipete/tap/bird` | bird-twitter |
| Peekaboo | `brew install steipete/tap/peekaboo` | peekaboo |
| Python 3 | `brew install python3` | ui-ux-pro-max |
| jq | `brew install jq` | hooks/notify.sh |
| Codex MCP | 通过 .mcp.json 自动配置 | cc-codex-review |

## 仓库结构

```
skills/
├── marketplace.json          # Marketplace 注册文件
├── setup.sh                  # 外部依赖安装脚本
├── .gitignore
├── README.md
├── CLAUDE.md
└── personal-skills/          # 插件目录
    ├── .claude-plugin/
    │   └── plugin.json       # 插件清单
    ├── .mcp.json             # MCP 服务器声明
    ├── skills/               # 所有 skills
    ├── scripts/              # 外部脚本
    ├── hooks/                # Hook 脚本
    └── agents/               # Agent 配置
```
