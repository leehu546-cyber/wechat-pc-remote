---
name: bilibili-music
description: Use when the user asks to play or search for a song via Bilibili. 用户要求放歌、听歌、播放音乐时使用。
---

# B站音乐播放 (Bilibili Music Player)

## 触发词
- 放歌 / 听歌 / 播放 / 放一首 / 搜一首 / 搜索歌曲 / 放个歌

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

4. 收尾回复（固定模板）：`已在浏览器打开：{视频标题}`

## 注意事项
- 搜索关键词格式：`歌手名 歌曲名`（如 `田馥甄 氧气`）
- 使用 `webfetch` 工具调用 API，format 用 `text`
- 失败时：`没做成：{原因}`
