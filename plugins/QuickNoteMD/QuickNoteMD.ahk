#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
; =============================================================================
; QuickNote MD — floating Markdown scratchpad with Edit/View modes + image paste
;   Win+Alt+M / Win+Ctrl+M : show/hide (invoking brings the window to focus)
;   Esc / X   : hide window (contents are never destroyed)
;   Alt+V     : toggle Edit mode <-> View mode (rendered, read-only Markdown)
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
global QNMD_DEFAULT_W := 800, QNMD_DEFAULT_H := 600
global QNMD_MIN_W := 320, QNMD_MIN_H := 240

global qnmd := { gui: "", host: "", wvc: "", wv: "", geom: "", dark: true, themeMode: "auto", opacity: 255, ready: false }

if !DirExist(QNMD_DIR)
    DirCreate(QNMD_DIR)

OnMessage(0x1A, QNMD_OnSettingChange)   ; WM_SETTINGCHANGE -> live theme flip
OnMessage(0x0006, QNMD_OnActivate)     ; WM_ACTIVATE -> unfocused 20% opacity reduction / focused restore
OnExit(QNMD_SaveGeometry)

#!m::QNMD_Toggle()   ; Win+Alt+M
^#m::QNMD_Toggle()   ; Win+Ctrl+M

#HotIf (qnmd.gui != "" && WinActive("ahk_id " qnmd.gui.Hwnd))
Esc::QNMD_Hide()
#HotIf

QNMD_IsMouseOver() {
    global qnmd
    if (qnmd.gui = "" || !DllCall("IsWindowVisible", "ptr", qnmd.gui.Hwnd))
        return false
    MouseGetPos(,, &winHwnd)
    if (winHwnd = qnmd.gui.Hwnd)
        return true
    rootHwnd := DllCall("GetAncestor", "ptr", winHwnd, "uint", 2, "ptr")
    return (rootHwnd = qnmd.gui.Hwnd)
}

#HotIf QNMD_IsMouseOver()
!WheelUp::QNMD_AdjustOpacity(25)     ; Alt + Scroll Up = increase opacity
!WheelDown::QNMD_AdjustOpacity(-25)  ; Alt + Scroll Down = decrease opacity
#HotIf

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
    global qnmd, QNMD_DEFAULT_W, QNMD_DEFAULT_H
    g := qnmd.gui
    defaultGeom := "w" QNMD_DEFAULT_W " h" QNMD_DEFAULT_H
    g.Show((qnmd.geom != "" ? qnmd.geom : defaultGeom) (activate ? "" : " NoActivate"))
    if activate {
        if (qnmd.opacity >= 255)
            WinSetTransparent("Off", g.Hwnd)
        else
            WinSetTransparent(qnmd.opacity, g.Hwnd)
        WinActivate("ahk_id " g.Hwnd)
    } else {
        unfocusedAlpha := Min(Round(qnmd.opacity * 0.8), 204)
        WinSetTransparent(unfocusedAlpha, g.Hwnd)
    }
    try qnmd.wvc.IsVisible := true
    try qnmd.wvc.Fill()
    QNMD_SyncTransparency()
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

; ---- construction ------------------------------------------------------------
QNMD_Create() {
    global qnmd, QNMD_USERDATA_DIR, QNMD_MIN_W, QNMD_MIN_H, QNMD_DEFAULT_W, QNMD_DEFAULT_H

    g := Gui("+AlwaysOnTop +Resize -MaximizeBox +MinSize" QNMD_MIN_W "x" QNMD_MIN_H, "QuickNote MD")
    g.MarginX := 0, g.MarginY := 0
    host := g.AddText("x0 y0 w" QNMD_DEFAULT_W " h" QNMD_DEFAULT_H)

    g.OnEvent("Size", QNMD_OnSize)
    g.OnEvent("Close", QNMD_Hide)
    g.OnEvent("Escape", QNMD_Hide)

    iconPath := QNMD_SELF_DIR "\assets\markdown.ico"
    if FileExist(iconPath) {
        try {
            hIconSmall := LoadPicture(iconPath, "Icon1 Small", &imgType1)
            hIconBig := LoadPicture(iconPath, "Icon1", &imgType2)
            SendMessage(0x0080, 0, hIconSmall, g.Hwnd)   ; WM_SETICON, ICON_SMALL (titlebar)
            SendMessage(0x0080, 1, hIconBig, g.Hwnd)     ; WM_SETICON, ICON_BIG (taskbar / alt-tab)
        }
    }

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
QNMD_OnSize(thisGui, minMax, winW, winH) {
    global qnmd
    if (minMax = -1 || qnmd.gui = "")   ; ignore minimize
        return
    try qnmd.host.Move(0, 0, winW, winH)
    try qnmd.wvc.Fill()
}

QNMD_OnSettingChange(wParam, lParam, msg, hwnd) {
    global qnmd
    if (qnmd.gui = "")
        return
    if (qnmd.themeMode != "auto")
        return
    was := qnmd.dark
    QNMD_DetectTheme()
    if (was != qnmd.dark)
        try qnmd.wv.ExecuteScriptAsync("QN.setTheme(" (qnmd.dark ? "true" : "false") ")")
}

QNMD_OnActivate(wParam, lParam, msg, hwnd) {
    global qnmd
    if (qnmd.gui = "" || hwnd != qnmd.gui.Hwnd)
        return
    if !DllCall("IsWindowVisible", "ptr", qnmd.gui.Hwnd)
        return

    state := wParam & 0xFFFF
    if (state = 0) {
        ; Window deactivated (lost focus) -> reduce opacity by 20%, capped below max (255)
        unfocusedAlpha := Min(Round(qnmd.opacity * 0.8), 204)
        WinSetTransparent(unfocusedAlpha, qnmd.gui.Hwnd)
    } else {
        ; Window activated (in focus) -> restore original configured opacity
        if (qnmd.opacity >= 255)
            WinSetTransparent("Off", qnmd.gui.Hwnd)
        else
            WinSetTransparent(qnmd.opacity, qnmd.gui.Hwnd)
    }
}

; ---- WebView2 <-> AHK bridge --------------------------------------------------
QNMD_OnNavCompleted(sender, args) {
    global qnmd, QNMD_NOTE_FILE
    if !args.IsSuccess
        return
    content := ""
    try content := FileExist(QNMD_NOTE_FILE) ? FileRead(QNMD_NOTE_FILE, "UTF-8") : ""
    try qnmd.wv.ExecuteScriptAsync("QN.setTheme(" (qnmd.dark ? "true" : "false") ")")
    QNMD_SyncTransparency()
    try qnmd.wv.ExecuteScriptAsync("QN.loadNote(" QNMD_JSStr(content) ")")
    qnmd.ready := true
}

QNMD_SyncTransparency() {
    global qnmd
    if (qnmd.wv = "")
        return
    pct := Round((qnmd.opacity / 255) * 100)
    try qnmd.wv.ExecuteScriptAsync("QN.setTransparency(" pct ")")
}

QNMD_OnWebMessage(sender, args) {
    global QNMD_NOTE_FILE
    try {
        text := args.TryGetWebMessageAsString()
        if (text = "__QNMD_HIDE__") {
            QNMD_Hide()
            return
        }
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
    global qnmd, QNMD_INI
    try {
        savedMode := IniRead(QNMD_INI, "theme", "mode", "auto")
        qnmd.themeMode := savedMode
    } catch Any {
        qnmd.themeMode := "auto"
    }

    if (qnmd.themeMode = "dark") {
        qnmd.dark := true
    } else if (qnmd.themeMode = "light") {
        qnmd.dark := false
    } else {
        qnmd.themeMode := "auto"
        try {
            v := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
            qnmd.dark := (v = 0)
        } catch Any {
            qnmd.dark := true
        }
    }
}

QNMD_SetThemeMode(mode) {
    global qnmd, QNMD_INI
    qnmd.themeMode := mode
    if (mode = "dark") {
        qnmd.dark := true
    } else if (mode = "light") {
        qnmd.dark := false
    } else {
        qnmd.themeMode := "auto"
        try {
            v := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
            qnmd.dark := (v = 0)
        } catch Any {
            qnmd.dark := true
        }
    }

    try IniWrite(qnmd.themeMode, QNMD_INI, "theme", "mode")
    if (qnmd.wv != "")
        try qnmd.wv.ExecuteScriptAsync("QN.setTheme(" (qnmd.dark ? "true" : "false") ")")
}

QNMD_ToggleTheme(*) {
    global qnmd
    nextMode := qnmd.dark ? "light" : "dark"
    QNMD_SetThemeMode(nextMode)
}

; ---- opacity / transparency --------------------------------------------------
QNMD_AdjustOpacity(delta) {
    global qnmd, QNMD_INI
    if (qnmd.gui = "" || !DllCall("IsWindowVisible", "ptr", qnmd.gui.Hwnd))
        return

    newAlpha := Min(Max(qnmd.opacity + delta, 64), 255)
    if (newAlpha = qnmd.opacity)
        return

    qnmd.opacity := newAlpha
    if WinActive("ahk_id " qnmd.gui.Hwnd) {
        if (qnmd.opacity >= 255)
            WinSetTransparent("Off", qnmd.gui.Hwnd)
        else
            WinSetTransparent(qnmd.opacity, qnmd.gui.Hwnd)
    } else {
        unfocusedAlpha := Min(Round(qnmd.opacity * 0.8), 204)
        WinSetTransparent(unfocusedAlpha, qnmd.gui.Hwnd)
    }

    try IniWrite(qnmd.opacity, QNMD_INI, "window", "opacity")
    QNMD_SyncTransparency()
}

; ---- persistence ----------------------------------------------------------------
QNMD_SaveGeometry(*) {
    global qnmd, QNMD_INI, QNMD_MIN_W, QNMD_MIN_H
    if (qnmd.gui = "")
        return
    try {
        if DllCall("IsWindowVisible", "ptr", qnmd.gui.Hwnd) {
            qnmd.gui.GetPos(&winX, &winY, &winW, &winH)
            winW := Max(winW, QNMD_MIN_W), winH := Max(winH, QNMD_MIN_H)
            winX := Min(Max(winX, 0), A_ScreenWidth - 100)
            winY := Min(Max(winY, 0), A_ScreenHeight - 100)
            qnmd.geom := "x" winX " y" winY " w" winW " h" winH
            IniWrite(winX, QNMD_INI, "window", "x")
            IniWrite(winY, QNMD_INI, "window", "y")
            IniWrite(winW, QNMD_INI, "window", "w")
            IniWrite(winH, QNMD_INI, "window", "h")
        }
    } catch Any {
    }
}

QNMD_RestoreGeometry() {
    global qnmd, QNMD_INI, QNMD_MIN_W, QNMD_MIN_H
    qnmd.geom := ""
    try {
        winX := IniRead(QNMD_INI, "window", "x", "")
        winY := IniRead(QNMD_INI, "window", "y", "")
        winW := IniRead(QNMD_INI, "window", "w", "")
        winH := IniRead(QNMD_INI, "window", "h", "")
        if (winX != "" && winY != "" && winW != "" && winH != "") {
            winW := Max(winW + 0, QNMD_MIN_W), winH := Max(winH + 0, QNMD_MIN_H)
            winX := Min(Max(winX + 0, 0), A_ScreenWidth - 100)
            winY := Min(Max(winY + 0, 0), A_ScreenHeight - 100)
            qnmd.geom := "x" winX " y" winY " w" winW " h" winH
        }
    } catch Any {
    }

    try {
        op := IniRead(QNMD_INI, "window", "opacity", "255")
        if (op != "")
            qnmd.opacity := Min(Max(op + 0, 64), 255)
    } catch Any {
        qnmd.opacity := 255
    }
}

; ---- tray menu ------------------------------------------------------------------
ThemeMenu := Menu()
ThemeMenu.Add("Auto (Follow System)", (*) => QNMD_SetThemeMode("auto"))
ThemeMenu.Add("Light Theme", (*) => QNMD_SetThemeMode("light"))
ThemeMenu.Add("Dark Theme", (*) => QNMD_SetThemeMode("dark"))

A_TrayMenu.Delete()
A_TrayMenu.Add("Show / Hide QuickNote MD`tWin+Alt+M", QNMD_Toggle)
A_TrayMenu.Add("Toggle Light/Dark Theme", QNMD_ToggleTheme)
A_TrayMenu.Add("Theme Mode", ThemeMenu)
A_TrayMenu.Add("Open notes folder", (*) => Run(QNMD_DIR))
A_TrayMenu.Add()
A_TrayMenu.Add("Reload script", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show / Hide QuickNote MD`tWin+Alt+M"
if FileExist(QNMD_SELF_DIR "\assets\markdown.ico")
    TraySetIcon(QNMD_SELF_DIR "\assets\markdown.ico")
else
    TraySetIcon("shell32.dll", 174)
A_IconTip := "QuickNote MD (Win+Alt+M)"
