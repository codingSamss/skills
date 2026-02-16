#!/bin/bash
set -euo pipefail

NEED_MANUAL=0
MODEL_DIR="$HOME/.cache/whisper-cpp"
MODEL_FILE="$MODEL_DIR/ggml-small.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"

echo "[video-transcribe] 检查依赖..."

# 1. yt-dlp
if command -v yt-dlp >/dev/null 2>&1; then
  echo "[video-transcribe] yt-dlp 已安装: $(yt-dlp --version)"
else
  if command -v brew >/dev/null 2>&1; then
    echo "[video-transcribe] 安装 yt-dlp..."
    brew install yt-dlp
  else
    echo "[video-transcribe] 未检测到 Homebrew，请手动安装: brew install yt-dlp"
    NEED_MANUAL=1
  fi
fi

# 2. ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
  echo "[video-transcribe] ffmpeg 已安装"
else
  if command -v brew >/dev/null 2>&1; then
    echo "[video-transcribe] 安装 ffmpeg..."
    brew install ffmpeg
  else
    echo "[video-transcribe] 未检测到 Homebrew，请手动安装: brew install ffmpeg"
    NEED_MANUAL=1
  fi
fi

# 3. whisper-cpp
if command -v whisper-cli >/dev/null 2>&1; then
  echo "[video-transcribe] whisper-cpp 已安装"
else
  if command -v brew >/dev/null 2>&1; then
    echo "[video-transcribe] 安装 whisper-cpp..."
    brew install whisper-cpp
  else
    echo "[video-transcribe] 未检测到 Homebrew，请手动安装: brew install whisper-cpp"
    NEED_MANUAL=1
  fi
fi

# 4. Whisper 模型
if [ -f "$MODEL_FILE" ]; then
  MODEL_SIZE=$(du -h "$MODEL_FILE" | cut -f1)
  echo "[video-transcribe] Whisper small 模型已就绪 ($MODEL_SIZE)"
else
  echo "[video-transcribe] 下载 Whisper small 模型 (~465MB)..."
  mkdir -p "$MODEL_DIR"
  if curl -L "$MODEL_URL" -o "$MODEL_FILE" --progress-bar; then
    echo "[video-transcribe] 模型下载完成"
  else
    echo "[video-transcribe] 模型下载失败，请手动下载:"
    echo "  curl -L $MODEL_URL -o $MODEL_FILE"
    NEED_MANUAL=1
  fi
fi

# 5. 创建工作目录
mkdir -p /tmp/video-transcribe

echo ""
if [ "$NEED_MANUAL" -eq 1 ]; then
  echo "[video-transcribe] 部分依赖需要手动安装，请查看上方提示"
  exit 2
else
  echo "[video-transcribe] 所有依赖已就绪"
fi
