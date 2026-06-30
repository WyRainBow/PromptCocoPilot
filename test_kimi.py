#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kimi 2.7 接入测试脚本（0x7e.vip 中转，OpenAI 兼容协议）

用法：
    python3 test_kimi.py                  # 默认文本问答
    python3 test_kimi.py "你的问题"       # 自定义问题
    python3 test_kimi.py --image 图片.jpg "这张图里有什么？"   # 多模态图片识别
    python3 test_kimi.py --stream         # 流式输出

依赖：openai, python-dotenv
"""

import sys
import base64
import os

from openai import OpenAI
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))

client = OpenAI(
    api_key=os.getenv("KIMI_API_KEY"),
    base_url=os.getenv("KIMI_BASE_URL"),
)
MODEL = os.getenv("KIMI_MODEL", "kimi-k2.7-code")


def ask(question: str, stream: bool = False):
    """纯文本问答。"""
    if stream:
        print(f"[stream][{MODEL}] ", end="", flush=True)
        for chunk in client.chat.completions.create(
            model=MODEL,
            messages=[{"role": "user", "content": question}],
            stream=True,
        ):
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta.content
            if delta:
                print(delta, end="", flush=True)
        print()
        return

    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": question}],
    )
    print(f"[{MODEL}]\n{resp.choices[0].message.content}")


def ask_image(image_path: str, question: str):
    """多模态：看图回答。"""
    with open(image_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    ext = os.path.splitext(image_path)[1].lstrip(".") or "jpeg"
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": question},
                {"type": "image_url",
                 "image_url": {"url": f"data:image/{ext};base64,{b64}"}},
            ],
        }],
    )
    print(f"[{MODEL}][image:{image_path}]\n{resp.choices[0].message.content}")


def main():
    args = sys.argv[1:]
    stream = "--stream" in args
    if stream:
        args.remove("--stream")

    image_path = None
    if "--image" in args:
        i = args.index("--image")
        image_path = args[i + 1]
        args = args[:i] + args[i + 2:]

    question = " ".join(args).strip() or "你好，请用一句话介绍一下你自己。"

    if image_path:
        ask_image(image_path, question)
    else:
        ask(question, stream=stream)


if __name__ == "__main__":
    main()
