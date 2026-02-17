# image-gen

## 作用
通用图片生成技能，支持自由生图和结构化图表生成（架构图、流程图、时序图、泳道图）。通过可配置的 API Provider 调用图片生成模型（默认 Nano Banana Pro / Gemini 3 Pro Image）。

## 平台支持
- Claude Code（本实现）

## 工作原理
单文件 Python 脚本 `image-gen.py`，零 pip 依赖（仅标准库 urllib、json、base64、argparse）：
1. 读取 `~/.claude/skills/image-gen/providers.json` 获取当前 active provider 配置
2. 根据 provider 的 `format` 字段选择请求协议（OpenAI 兼容 或 Google Gemini 原生）
3. diagram 模式时根据图表类型自动包装专业 prompt 模板
4. 发送请求，解析响应，保存图片到本地

支持的 API 格式：
- `openai`：POST `{base_url}/chat/completions`，从 content 提取图片 URL 或 base64
- `gemini`：POST `{base_url}/models/{model}:generateContent`，从 inline_data 提取 base64

## 配置命令

```bash
./setup.sh image-gen
```

## 配置脚本行为

- 退出码：`0` 自动完成，`2` 需手动补齐，`1` 执行失败
- 自动检查项：
  - Python3 是否可用（缺失时尝试 `brew install python3`）
  - scripts/ 同步到 `~/.claude/skills/image-gen/scripts/`
  - providers.json 模板复制（仅首次，不覆盖已有配置）
  - active provider 的 api_key 是否已填写

## 验证命令

```bash
# 查看当前配置
python3 ~/.claude/skills/image-gen/scripts/image-gen.py config

# 切换 provider
python3 ~/.claude/skills/image-gen/scripts/image-gen.py config --switch undying

# 自由生图
python3 ~/.claude/skills/image-gen/scripts/image-gen.py generate "一个简单的系统架构图"

# 架构图
python3 ~/.claude/skills/image-gen/scripts/image-gen.py diagram --type architecture --input "Client -> Gateway -> Service -> DB"

# 流程图
python3 ~/.claude/skills/image-gen/scripts/image-gen.py diagram --type flowchart --input "输入->处理->输出"

# 时序图
python3 ~/.claude/skills/image-gen/scripts/image-gen.py diagram --type sequence --input "A->B: req; B->A: resp"

# 泳道图
python3 ~/.claude/skills/image-gen/scripts/image-gen.py diagram --type swimlane --input "前端: 请求; 后端: 处理; DB: 存储"
```

## 使用方式
- 触发词：`生成图片`、`画架构图`、`画流程图`、`画时序图`、`画泳道图`、`generate image`、`diagram`
- 详细命令与触发规则见：`platforms/claude/skills/image-gen/SKILL.md`

## 依赖
- Python3（标准库即可，零 pip 依赖）
- API Provider 的 api_key（需手动配置）
