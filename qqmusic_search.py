import win32gui, win32process, win32con, win32api, win32com.client
import time

pid = 4396

hwnds = []
def enum_cb(hwnd, _):
    try:
        _, p = win32process.GetWindowThreadProcessId(hwnd)
        if p == pid:
            title = win32gui.GetWindowText(hwnd)
            if title and win32gui.IsWindowVisible(hwnd):
                hwnds.append(hwnd)
    except:
        pass
    return True

win32gui.EnumWindows(enum_cb, None)

if hwnds:
    hwnd = hwnds[0]
    placement = win32gui.GetWindowPlacement(hwnd)
    print(f'showCmd: {placement[3]}')
    
    # Try to restore the window with SW_SHOWNORMAL (1) or SW_RESTORE (9)
    win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
    time.sleep(0.5)
    
    rect = win32gui.GetWindowRect(hwnd)
    print(f'After restore rect: {rect}')
    
    # If still off-screen, force a position
    if rect[0] < -1000:
        win32gui.SetWindowPos(hwnd, 0, 100, 50, 1100, 700, win32con.SWP_SHOWWINDOW)
        time.sleep(0.5)
        rect = win32gui.GetWindowRect(hwnd)
        print(f'After SetWindowPos rect: {rect}')
    
    win32gui.SetForegroundWindow(hwnd)
    win32gui.BringWindowToTop(hwnd)
    time.sleep(1)
    
    # Click search bar area (relative to window position)
    search_x = rect[0] + 400
    search_y = rect[1] + 60
    
    win32api.SetCursorPos((search_x, search_y))
    time.sleep(0.2)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.05)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.5)
    
    shell = win32com.client.Dispatch('WScript.Shell')
    shell.SendKeys('氧气')
    time.sleep(0.5)
    shell.SendKeys('{ENTER}')
    time.sleep(3)
    shell.SendKeys('{ENTER}')
    print('Done')
