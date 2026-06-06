"""Wake monitor from off / screensaver (called by wake-screen.ps1)."""
import ctypes
import sys

ctypes.windll.user32.SendMessageW(0xFFFF, 0x0112, 0xF170, -1)
ctypes.windll.user32.mouse_event(1, 1, 0, 0, 0)
print("WECHAT_OK: 已唤醒显示器")
