---
name: bilibili-music
description: Use when the user asks to play or search for a song via Bilibili. 用户要求放歌、听歌、播放音乐时使用。
---

# B站音乐播放 (Bilibili Music Player)

## 触发词
- 放歌 / 听歌 / 播放 / 放一首 / 搜一首 / 搜索歌曲 / 放个歌
- 例如："放一首田馥甄的氧气"、"给我放周杰伦的七里香"

## 实现步骤

1. 用以下 URL 搜索 B 站视频 API（keyword 替换为 歌手+空格+歌曲名）：
   ```
   https://api.bilibili.com/x/web-interface/search/all/v2?keyword=<URL编码后的歌手名+歌曲名>
   ```

2. 从返回 JSON 的 `data.result[].data[]` 中找到第一个视频，提取 `bvid` 字段。

3. 将 `bvid` 传给固定脚本播放：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\bilibili-play.ps1 -bvid "<bvid>"
   ```

4. 告知用户已打开的视频标题。

## 注意事项
- 搜索关键词格式：`歌手名 歌曲名`（如 `田馥甄 氧气`）
- 使用 `webfetch` 工具调用 API，format 用 `text`，URL 用 `https://api.bilibili.com/x/web-interface/search/all/v2?keyword=...`
- 优先选择标题同时包含歌手名和歌曲名的视频
- API 返回可能包含 `\u003cem class=\"keyword\"\u003e` 等 HTML 标签，取 `title` 字段时需忽略标签解读实际内容
- 使用 BVID（如 `BV1KU92ByErb`）拼接视频 URL：`https://www.bilibili.com/video/BV1KU92ByErb`
