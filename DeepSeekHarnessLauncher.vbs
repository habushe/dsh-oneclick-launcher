' DeepSeek Harness One-Click Launcher v7
' ------------------------------------
' Starts the dsh web server (hidden) if it is not actually healthy, waits for
' readiness (HTTP 200, not just a listening port), then opens the DeepSeek
' Harness PWA in its own standalone window (app mode, NOT a browser tab).
'
' v7 (2026-08-30): HTTP alive-check. A listening port is NOT enough: if the
'     port is occupied but HTTP does not answer (stale/hung process), the
'     launcher kills the stale process and starts a fresh server, so the PWA
'     never opens against a dead backend. Every run writes a line to
'     launcher.log for troubleshooting.
'
' Requirements:
'   - DeepSeek Harness installed via npm (dsh command available)
'   - Google Chrome installed
'   - The DeepSeek Harness PWA installed in Chrome (optional; if APP_ID is
'     empty, the script falls back to opening http://127.0.0.1:3080 in a new
'     Chrome app window)
'
' Edit the constants below to match your environment, or run install.ps1 to
' generate this file automatically.

Option Explicit

Dim shell, fso
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' ============ EDIT THESE ============
Const PORT = 3080                                    ' dsh web listen port
Const DSH_DIR = "C:\Users\10780\AppData\Roaming\npm" ' npm global dir containing dsh
Const NODE = "D:\softinstall\nodejs\node.exe"        ' absolute path to node.exe
Const BIN = "C:\Users\10780\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh\lib\bin.js"  ' dsh bin.js
Const CHROME = "C:\Program Files\Google\Chrome\Application\chrome_proxy.exe"  ' Chrome proxy exe
Const APP_ID = "hgiemfgfjhalibdoboikeiepnnjapnpc"    ' DeepSeek Harness PWA app-id ("" = fallback to URL)
' ====================================

' Temp/log files live next to this script
Dim SCRIPT_DIR, LOGFILE, TMPFILE
SCRIPT_DIR = fso.GetParentFolderName(WScript.ScriptFullName)
LOGFILE = SCRIPT_DIR & "\launcher.log"
TMPFILE = SCRIPT_DIR & "\portcheck.txt"

' --- helper: append one line to the launcher log ---
Sub Log(msg)
    Dim f
    On Error Resume Next
    Set f = fso.OpenTextFile(LOGFILE, 8, True, 0)
    f.WriteLine Now & "  " & msg
    f.Close
    On Error GoTo 0
End Sub

' --- helper: is the dsh server actually alive? (HTTP 200 on our port) ---
Function ServerAlive()
    Dim http
    ServerAlive = False
    On Error Resume Next
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts 3000, 3000, 3000, 5000
    http.Open "GET", "http://127.0.0.1:" & PORT & "/", False
    If Err.Number = 0 Then
        http.Send
        If Err.Number = 0 Then
            If http.Status = 200 Then
                ServerAlive = True
            End If
        End If
    End If
    Set http = Nothing
    On Error GoTo 0
End Function

' --- helper: PID listening on our port, or empty string ---
Function PortPid()
    Dim e, ln, pid, parts
    pid = ""
    shell.Run "cmd /c netstat -ano | findstr "":3080 "" > """ & TMPFILE & """ 2>nul", 0, True
    If fso.FileExists(TMPFILE) Then
        Set e = fso.OpenTextFile(TMPFILE, 1, False, 0)
        Do While Not e.AtEndOfStream
            ln = e.ReadLine()
            If InStr(ln, "LISTENING") > 0 Then
                parts = Split(Trim(ln), " ")
                pid = parts(UBound(parts))
                Exit Do
            End If
        Loop
        e.Close
    End If
    PortPid = pid
End Function

' --- helper: start the dsh web server hidden ---
Sub StartServer()
    ' Working directory matters for dsh web. Set it before launching.
    shell.CurrentDirectory = DSH_DIR
    shell.Run """" & NODE & """ """ & BIN & """ --profile web", 0, False
End Sub

' --- Step 1: health check; restart if stale ---
If ServerAlive() Then
    Log "OK: server healthy on port " & PORT
Else
    Dim stalePid, i, ready
    stalePid = PortPid()
    If stalePid <> "" Then
        Log "Stale process " & stalePid & " holds port " & PORT & " but HTTP is dead; killing it"
        shell.Run "cmd /c taskkill /F /PID " & stalePid & " >nul 2>nul", 0, True
        WScript.Sleep 500
    End If
    StartServer()
    Log "Starting dsh web server, waiting for HTTP ready..."

    ' --- Step 2: wait up to 90 seconds for a healthy server ---
    ready = False
    For i = 1 To 90
        WScript.Sleep 1000
        If ServerAlive() Then
            ready = True
            Exit For
        End If
    Next
    If ready Then
        Log "Server ready after " & i & "s"
    Else
        Log "ERROR: server failed to become healthy within 90 seconds"
        MsgBox "DeepSeek Harness server failed to start within 90 seconds." & vbCrLf & _
               "Manual: cd " & DSH_DIR & " && dsh web", vbExclamation, "DeepSeek Harness"
    End If
End If

' --- Step 3: open the standalone window ---
If APP_ID <> "" Then
    ' PWA app mode: standalone window, own taskbar icon
    shell.Run """" & CHROME & """ --profile-directory=Default --app-id=" & APP_ID, 1, False
Else
    ' Fallback: plain app window pointing at the local URL
    shell.Run """" & CHROME & """ --app=http://127.0.0.1:" & PORT, 1, False
End If
