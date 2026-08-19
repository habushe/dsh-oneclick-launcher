' DeepSeek Harness One-Click Launcher
' ------------------------------------
' Starts the dsh web server (hidden) if port 3080 is not listening, waits for
' readiness, then opens the DeepSeek Harness PWA in its own standalone window
' (app mode, NOT a browser tab).
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

Dim shell, fso, i, portUp, ready
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' ============ EDIT THESE ============
Const PORT = 3080                                    ' dsh web listen port
Const DSH_DIR = "C:\Users\10780\AppData\Roaming\npm" ' npm global dir containing dsh
Const NODE = "D:\softinstall\nodejs\node.exe"        ' absolute path to node.exe
Const BIN = "C:\Users\10780\AppData\Roaming\npm\node_modules\@deepseek-ai\dsh\lib\bin.js"  ' dsh bin.js
Const CHROME = "C:\Program Files\Google\Chrome\Application\chrome_proxy.exe"  ' Chrome proxy exe
Const APP_ID = "hgiemfgfjhalibdoboikeiepnnjapnpc"    ' DeepSeek Harness PWA app-id ("" = fallback to URL)
Const URL = "http://127.0.0.1:" & PORT              ' fallback URL
' ====================================

' Temp/log files live next to this script
Dim SCRIPT_DIR
SCRIPT_DIR = fso.GetParentFolderName(WScript.ScriptFullName)
Const LOGFILE = SCRIPT_DIR & "\launcher.log"
Const TMPFILE = SCRIPT_DIR & "\portcheck.txt"

' --- helper: is port listening? (temp file avoids shell.Exec pipe deadlock) ---
Function PortListening()
    Dim e, ln, up
    up = False
    shell.Run "cmd /c netstat -ano | findstr :" & PORT & " > """ & TMPFILE & """ 2>nul", 0, True
    If fso.FileExists(TMPFILE) Then
        Set e = fso.OpenTextFile(TMPFILE, 1, False, 0)
        Do While Not e.AtEndOfStream
            ln = e.ReadLine()
            If InStr(ln, "LISTENING") > 0 Then
                up = True
                Exit Do
            End If
        Loop
        e.Close
    End If
    PortListening = up
End Function

' --- Step 1: check if port is already listening ---
portUp = PortListening()

' --- Step 2: start dsh web hidden if needed ---
If Not portUp Then
    ' Working directory matters for dsh web. Set it before launching.
    shell.CurrentDirectory = DSH_DIR
    shell.Run """" & NODE & """ """ & BIN & """ --profile web", 0, False

    ' --- Step 3: wait up to 90 seconds for the server ---
    ready = False
    For i = 1 To 90
        WScript.Sleep 1000
        If PortListening() Then
            ready = True
            Exit For
        End If
    Next
    If Not ready Then
        MsgBox "DeepSeek Harness server failed to start within 90 seconds." & vbCrLf & _
               "Manual: cd " & DSH_DIR & " && dsh web", vbExclamation, "DeepSeek Harness"
    End If
End If

' --- Step 4: open the standalone window ---
If APP_ID <> "" Then
    ' PWA app mode: standalone window, own taskbar icon
    shell.Run """" & CHROME & """ --profile-directory=Default --app-id=" & APP_ID, 1, False
Else
    ' Fallback: plain app window pointing at the local URL
    shell.Run """" & CHROME & """ --app=" & URL, 1, False
End If
