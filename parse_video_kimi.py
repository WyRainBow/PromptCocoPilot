#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用 Kimi 2.7 理解视频交互：按时间顺序抽帧 -> 逐帧带时间戳喂给 Kimi -> 输出交互流程。

用法：
    python3 parse_video_kimi.py <视频路径> [提问]
    python3 parse_video_kimi.py 20260630200004_rec_.mp4
    python3 parse_video_kimi.py 20260630200004_rec_.mp4 "这个按钮点击后发生了什么？"

依赖：openai, python-dotenv, ffmpeg（系统命令）
"""

import os
import sys
import base64
import subprocess
import glob
import re

from openai import OpenAI
from dotenv import load_dotenv

ROOT = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(ROOT, ".env"))

client = OpenAI(
    api_key=os.getenv("KIMI_API_KEY"),
    base_url=os.getenv("KIMI_BASE_URL"),
)
MODEL = os.getenv("KIMI_MODEL", "kimi-k2.7-code")


def probe_duration(video_path: str) -> float:
    out = subprocess.run(
        ["ffmpeg", "-i", video_path], capture_output=True, text=True
    ).stderr
    m = re.search(r"Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", out)
    if not m:
        return 0.0
    h, mi, s = m.groups()
    return int(h) * 3600 + int(mi) * 60 + float(s)


def extract_frames(video_path: str, out_dir: str, fps: int = 1,
                   width: int = 512, quality: int = 3) -> list[str]:
    """抽帧，返回按时间排序的帧路径列表。quality 越小体积越小（ffmpeg 2-31）。"""
    os.makedirs(out_dir, exist_ok=True)
    for f in glob.glob(os.path.join(out_dir, "frame_*.jpg")):
        os.remove(f)
    subprocess.run(
        ["ffmpeg", "-y", "-i", video_path,
         "-vf", f"fps={fps},scale={width}:-1",
         "-q:v", str(quality),
         os.path.join(out_dir, "frame_%02d.jpg")],
        check=True, capture_output=True,
    )
    return sorted(glob.glob(os.path.join(out_dir, "frame_*.jpg")))


def b64_image(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def understand(video_path: str, question: str, fps: int = 1,
               max_retries: int = 3) -> str:
    duration = probe_duration(video_path)
    out_dir = os.path.join(ROOT, "test-output", "kimi_frames")
    frames = extract_frames(video_path, out_dir, fps=fps, width=512, quality=3)
    total_kb = sum(os.path.getsize(f) for f in frames) / 1024
    print(f"抽帧完成：{len(frames)} 帧（{duration:.1f}s，约 {total_kb:.0f}KB），正在调用 Kimi 理解...\n")

    content = [{
        "type": "text",
        "text": (
            f"下面是一段操作录屏的关键帧，按时间顺序排列，每帧间隔约 {1/fps:.1f} 秒。\n\n"
            f"请仔细理解这个视频，{question}\n\n"
            "要求：\n"
            "1. 按时间线梳理完整的交互流程（用户做了什么操作 -> 界面如何响应）\n"
            "2. 指出关键的 UI 元素、状态变化\n"
            "3. 语言简洁，用分点/编号呈现"
        ),
    }]
    for idx, fp in enumerate(frames, 1):
        ts = round((idx - 1) / fps, 1)
        content.append({"type": "text", "text": f"[第 {idx} 帧 / {ts}s]"})
        content.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{b64_image(fp)}"},
        })

    import time
    last_err = None
    for attempt in range(1, max_retries + 1):
        try:
            resp = client.chat.completions.create(
                model=MODEL,
                messages=[{"role": "user", "content": content}],
                timeout=120,
            )
            return resp.choices[0].message.content
        except Exception as e:
            last_err = e
            print(f"  [调用失败 第{attempt}次] {type(e).__name__}: {str(e)[:120]}")
            if attempt < max_retries:
                time.sleep(3 * attempt)
    raise last_err


def main():
    if len(sys.argv) < 2:
        print("用法: python3 parse_video_kimi.py <视频路径> [提问]")
        sys.exit(1)
    video = sys.argv[1]
    question = " ".join(sys.argv[2:]).strip() or (
        "请详细描述这个视频里的交互流程和界面变化。"
    )
    print(understand(video, question))


if __name__ == "__main__":
    main()
