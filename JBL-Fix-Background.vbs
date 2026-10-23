Set shell = CreateObject("WScript.Shell")
shell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & Replace(WScript.ScriptFullName, "JBL-Fix-Background.vbs", "monitor-tray.ps1") & """", 0, False
