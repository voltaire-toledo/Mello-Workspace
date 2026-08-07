#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
; =============================================================================
; QuickNote MD — floating Markdown scratchpad with Edit/View modes + image paste
;   Win+Alt+M : show/hide (invoking brings the window to focus)
;   X         : hide (contents are never destroyed)
;   Esc       : toggle Edit mode <-> View mode (rendered, read-only Markdown)
;   Ctrl+B / Ctrl+I : wrap selection in **bold** / *italic*   Ctrl+Shift+C : `code`
;   (edit mode only; View mode is read-only and reports so in the status bar)
;   Ctrl+V an image on the clipboard to embed it inline as a Markdown image.
; Editing happens inside an embedded WebView2 control (assets/editor.html);
; this script only owns the window, hotkey, persistence and AHK<->page bridge.
; Edit/View mode switching and read-only enforcement live entirely in the page
; (editor.html) — this script never knows or cares which mode is active.
; Standalone: everything this script needs lives under this folder (vendor/, assets/).
; =============================================================================

#Include vendor\WebView2\WebView2.ahk

; A_ScriptDir is always the main script's directory, not this file's — resolve
; this plugin's own folder so its assets load correctly whether run standalone
; or #Include'd from elsewhere (see A_LineFile usage in WebView2.ahk itself).
global QNMD_SELF_DIR := SubStr(A_LineFile, 1, InStr(A_LineFile, "\",, -1) - 1)

global QNMD_DIR := A_AppData "\Mello-Workspace\QuickNoteMD"
global QNMD_NOTE_FILE := QNMD_DIR "\note.md"
global QNMD_INI := QNMD_DIR "\window.ini"
global QNMD_USERDATA_DIR := QNMD_DIR "\webview2-data"
global QNMD_MIN_W := 480, QNMD_MIN_H := 320

global qnmd := { gui: "", host: "", wvc: "", wv: "", geom: "", dark: true, ready: false }

if !DirExist(QNMD_DIR)
    DirCreate(QNMD_DIR)

OnMessage(0x1A, QNMD_OnSettingChange)   ; WM_SETTINGCHANGE -> live theme flip
OnExit(QNMD_SaveGeometry)

#!m::QNMD_Toggle()

; ---- show / hide / toggle ---------------------------------------------------
QNMD_Toggle(*) {
    global qnmd
    if (qnmd.gui = "")
        QNMD_Create()
    if DllCall("IsWindowVisible", "ptr", qnmd.gui.Hwnd)
        QNMD_Hide()
    else
        QNMD_Show()
}

QNMD_Show(activate := true) {
    global qnmd
    g := qnmd.gui
    g.Show((qnmd.geom != "" ? qnmd.geom : "w900 h620") (activate ? "" : " NoActivate"))
    if activate
        WinActivate("ahk_id " g.Hwnd)
    try qnmd.wvc.IsVisible := true
    try qnmd.wvc.Fill()
    if activate
        try qnmd.wv.ExecuteScriptAsync("QN.focus()")
}

QNMD_Hide(*) {
    global qnmd
    g := qnmd.gui
    if (g = "" || !DllCall("IsWindowVisible", "ptr", g.Hwnd))
        return true
    QNMD_SaveGeometry()
    try qnmd.wvc.IsVisible := false
    g.Hide()
    return true     ; consume Close so the GUI is never destroyed
}

; Escape no longer hides the window — editor.html handles it client-side to
; toggle Edit/View mode. This just consumes the key so the native Gui default
; (closing the window) never fires if WebView2 forwards it as an accelerator.
QNMD_SuppressEscape(*) {
    return true
}

; ---- construction ------------------------------------------------------------
QNMD_Create() {
    global qnmd, QNMD_USERDATA_DIR

    g := Gui("+AlwaysOnTop +Resize -MaximizeBox", "QuickNote MD")
    g.MarginX := 0, g.MarginY := 0
    host := g.AddText("x0 y0 w900 h620")

    g.OnEvent("Size", QNMD_OnSize)
    g.OnEvent("Close", QNMD_Hide)
    g.OnEvent("Escape", QNMD_SuppressEscape)

    qnmd.gui := g, qnmd.host := host
    QNMD_DetectTheme()
    QNMD_RestoreGeometry()

    dllDir := QNMD_SELF_DIR "\vendor\WebView2\" (A_PtrSize = 8 ? "64bit" : "32bit")
    loaderDll := dllDir "\WebView2Loader.dll"

    try {
        wvc := WebView2.CreateControllerAsync(host.Hwnd, , QNMD_USERDATA_DIR, , loaderDll).await2()
    } catch as e {
        MsgBox(
            "QuickNote MD couldn't start the Edge WebView2 control.`n`n"
            "Error: " e.Message "`n`n"
            "Make sure the Microsoft Edge WebView2 Runtime is installed`n"
            "(it ships with Windows 10 21H2+ and Windows 11 by default).",
            "QuickNote MD", "Icon!"
        )
        ExitApp()
    }
    wv := wvc.CoreWebView2
    qnmd.wvc := wvc, qnmd.wv := wv

    wv.Settings.AreDefaultContextMenusEnabled := true

    qnmd.nc := wv.NavigationCompleted(QNMD_OnNavCompleted)
    qnmd.wmr := wv.WebMessageReceived(QNMD_OnWebMessage)

    htmlPath := QNMD_SELF_DIR "\assets\editor.html"
    wv.Navigate("file:///" StrReplace(htmlPath, "\", "/"))
}

; ---- window event handlers ---------------------------------------------------
QNMD_OnSize(thisGui, minMax, w, h) {
    global qnmd
    if (minMax = -1 || qnmd.gui = "")   ; ignore minimize
        return
    try qnmd.host.Move(0, 0, w, h)
    try qnmd.wvc.Fill()
}

QNMD_OnSettingChange(wParam, lParam, msg, hwnd) {
    global qnmd
    if (qnmd.gui = "")
        return
    was := qnmd.dark
    QNMD_DetectTheme()
    if (was != qnmd.dark)
        try qnmd.wv.ExecuteScriptAsync("QN.setTheme(" (qnmd.dark ? "true" : "false") ")")
}

; ---- WebView2 <-> AHK bridge --------------------------------------------------
QNMD_OnNavCompleted(sender, args) {
    global qnmd, QNMD_NOTE_FILE
    if !args.IsSuccess
        return
    content := ""
    try content := FileExist(QNMD_NOTE_FILE) ? FileRead(QNMD_NOTE_FILE, "UTF-8") : ""
    try qnmd.wv.ExecuteScriptAsync("QN.setTheme(" (qnmd.dark ? "true" : "false") ")")
    try qnmd.wv.ExecuteScriptAsync("QN.loadNote(" QNMD_JSStr(content) ")")
    qnmd.ready := true
}

QNMD_OnWebMessage(sender, args) {
    global QNMD_NOTE_FILE
    try {
        text := args.TryGetWebMessageAsString()
        f := FileOpen(QNMD_NOTE_FILE, "w", "UTF-8")
        f.Write(text)
        f.Close()
    } catch Any {
        ; saving is best-effort; never interrupt the user
    }
}

; Escape a raw string into a double-quoted JS string literal argument.
QNMD_JSStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r`n", "\n")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\n")
    return '"' s '"'
}

; ---- theming ------------------------------------------------------------------
QNMD_DetectTheme() {
    global qnmd
    try {
        v := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        qnmd.dark := (v = 0)
    } catch Any {
        qnmd.dark := true
    }
}

; ---- persistence ----------------------------------------------------------------
QNMD_SaveGeometry(*) {
    global qnmd, QNMD_INI
    if (qnmd.gui = "")
        return
    try {
        if DllCall("IsWindowVisible", "ptr", qnmd.gui.Hwnd) {
            qnmd.gui.GetPos(&x, &y, &w, &h)
            IniWrite(x, QNMD_INI, "window", "x")
            IniWrite(y, QNMD_INI, "window", "y")
            IniWrite(w, QNMD_INI, "window", "w")
            IniWrite(h, QNMD_INI, "window", "h")
        }
    } catch Any {
    }
}

QNMD_RestoreGeometry() {
    global qnmd, QNMD_INI, QNMD_MIN_W, QNMD_MIN_H
    qnmd.geom := ""
    try {
        x := IniRead(QNMD_INI, "window", "x", "")
        y := IniRead(QNMD_INI, "window", "y", "")
        w := IniRead(QNMD_INI, "window", "w", "")
        h := IniRead(QNMD_INI, "window", "h", "")
        if (x != "" && y != "" && w != "" && h != "") {
            w := Max(w + 0, QNMD_MIN_W), h := Max(h + 0, QNMD_MIN_H)
            x := Min(Max(x + 0, 0), A_ScreenWidth - 100)
            y := Min(Max(y + 0, 0), A_ScreenHeight - 100)
            qnmd.geom := "x" x " y" y " w" w " h" h
        }
    } catch Any {
    }
}

; ---- tray menu ------------------------------------------------------------------
A_TrayMenu.Delete()
A_TrayMenu.Add("Show / Hide QuickNote MD`tWin+Alt+M", QNMD_Toggle)
A_TrayMenu.Add("Open notes folder", (*) => Run(QNMD_DIR))
A_TrayMenu.Add()
A_TrayMenu.Add("Reload script", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show / Hide QuickNote MD`tWin+Alt+M"
TraySetIcon("shell32.dll", 174)
A_IconTip := "QuickNote MD (Win+Alt+M)"
