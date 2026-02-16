---
name: video-transcribe
description: "Video/audio transcription and summary. Download video from any URL (Twitter, YouTube, Bilibili, etc.), transcribe speech to text, and summarize content. Keywords: video, transcribe, 转录, 视频, 音频, audio, subtitle, 字幕, summary, 总结, 视频内容, whisper, yt-dlp"
---

# Video Transcribe Skill

从任意视频/音频链接提取语音内容，转录为文本并总结。支持 Twitter/X、YouTube、Bilibili 等 1000+ 站点。

## 触发条件

当用户提到以下内容时触发：
- "这个视频说了什么"、"帮我看看这个视频"、"视频内容"、"转录"
- "transcribe this video"、"what does this video say"
- 分享了包含视频的链接并希望了解内容
- "总结这个视频"、"视频摘要"
- "提取字幕"、"语音转文字"

## 前置条件

1. **yt-dlp** 已安装: `brew install yt-dlp`
2. **ffmpeg** 已安装: `brew install ffmpeg`
3. **whisper-cpp** 已安装: `brew install whisper-cpp`
4. **Whisper 模型** 已下载到 `~/.cache/whisper-cpp/`
   - 推荐 small 模型（465MB，精度与速度平衡好）
   - 如未下载，执行 setup.sh 自动处理

## 工作目录

所有临时文件保存到: `/tmp/video-transcribe/`

处理完成后自动清理中间文件（WAV），仅保留最终转录文本。

## 执行流程

收到视频链接后，按以下步骤执行：

### Step 1: 下载音频

从视频 URL 提取音频，使用 Chrome cookies 处理需要登录的站点：

```bash
mkdir -p /tmp/video-transcribe
yt-dlp --cookies-from-browser chrome \
  -x --audio-format mp3 --audio-quality 5 \
  -o '/tmp/video-transcribe/%(title)s.%(ext)s' \
  '$URL'
```

**参数说明：**
- `-x --audio-format mp3` - 只提取音频转 MP3
- `--audio-quality 5` - 中等质量（语音转录足够，减小体积）
- `--cookies-from-browser chrome` - 使用 Chrome cookies（处理 Twitter 等需登录站点）

**错误处理：**
- 如果 cookies 失败，尝试去掉 `--cookies-from-browser chrome`
- 如果站点不支持，告知用户 yt-dlp 不支持该站点
- 如果 YouTube 报 `No video formats found` / `SABR` 错误，提示用户更新 yt-dlp: `brew upgrade yt-dlp`
- 如果下载超时或文件过大，可加 `--max-filesize 500M` 限制

### Step 2: 转码为 WAV

whisper-cpp 需要 16kHz 单声道 WAV：

```bash
ffmpeg -i '/tmp/video-transcribe/INPUT.mp3' \
  -ar 16000 -ac 1 -c:a pcm_s16le \
  '/tmp/video-transcribe/audio.wav' -y
```

### Step 3: 转录

使用 whisper-cpp 本地转录：

```bash
whisper-cli \
  -m ~/.cache/whisper-cpp/ggml-small.bin \
  -f '/tmp/video-transcribe/audio.wav' \
  -l auto \
  --no-timestamps \
  -otxt \
  -of '/tmp/video-transcribe/transcript'
```

**参数说明：**
- `-l auto` - 自动检测语言（支持中英日韩等 99 种语言）
- `--no-timestamps` - 输出纯文本（不含时间戳）
- `-otxt` - 输出为 txt 文件

**长音频处理（超过 30 分钟）：**
- whisper-cpp 可以直接处理长音频，无需手动切分
- M3 Max 上约 1 分钟处理 60 分钟音频

### Step 4: 读取并总结

```bash
cat /tmp/video-transcribe/transcript.txt
```

读取转录文本后：
1. 先向用户展示视频基本信息（标题、时长、语言）
2. 提供结构化总结：
   - **核心主题** - 一句话概括
   - **关键要点** - 3-5 个要点
   - **详细内容** - 按话题/章节组织的详细摘要
   - **值得关注** - 有价值的观点、数据、资源链接等

### Step 5: 清理临时文件

转录和总结完成后，清理中间文件：

```bash
# 保留转录文本，删除音频文件
rm -f /tmp/video-transcribe/*.mp3 /tmp/video-transcribe/*.wav
```

如果用户不再需要转录文本：
```bash
rm -rf /tmp/video-transcribe/
```

## 模型选择指南

| 模型 | 大小 | 速度（M3 Max） | 适用场景 |
|---|---|---|---|
| tiny | 75MB | 极快 | 快速预览、语言检测 |
| base | 142MB | 很快 | 短音频、对精度要求不高 |
| small | 465MB | 快（60x 实时） | **推荐默认**，精度与速度平衡 |
| medium | 1.5GB | 中等 | 高精度需求 |
| large-v3 | 3GB | 较慢 | 最高精度、专业场景 |

默认使用 small 模型。如果用户对转录质量不满意，建议升级到 medium 或 large-v3。

模型下载地址格式：
```
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{MODEL}.bin
```

## 支持的站点（部分）

yt-dlp 支持 1000+ 站点，常用的包括：
- Twitter/X
- YouTube
- Bilibili（哔哩哔哩）
- Vimeo
- TikTok / 抖音
- 微博视频
- 播客平台（Apple Podcasts、Spotify 等）

完整列表: `yt-dlp --list-extractors`

## 注意事项

- 转录为本地处理，不上传任何数据到外部服务，隐私安全
- 首次使用需下载 Whisper 模型（约 465MB），之后无需重复下载
- 音频质量直接影响转录精度，背景噪音较大时精度会下降
- 非语音内容（纯音乐、音效）无法转录
- 多语言混合内容可能需要指定主要语言（`-l zh` 或 `-l en`）
