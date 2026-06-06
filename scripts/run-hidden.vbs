' Run a command with no visible window (style 0). No flash on scheduled-task launch.
' Usage: wscript.exe //B run-hidden.vbs "<full command line>"
If WScript.Arguments.Count < 1 Then WScript.Quit 1
CreateObject("Wscript.Shell").Run WScript.Arguments(0), 0, False
