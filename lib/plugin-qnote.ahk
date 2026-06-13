#Requires AutoHotkey v2.0
; =============================================================================
; QuickNote — modern floating scratchpad
;   Win+Alt+N : show/hide (invoking it brings the window to focus)
;   Esc / X   : hide (contents are never destroyed)
;   Ctrl+L    : clear      Ctrl+D : toggle dark/light theme
;   Ctrl+B / Ctrl+I : wrap selection in **bold** / *italic*
;   Ctrl+Shift+C    : wrap selection in `code`
; Contents + window geometry persist across hide/show AND app restart
; (autosaved under %AppData%\Mello-Workspace). See docs/PRD-QNOTE.md.
; =============================================================================

; ---- module state -----------------------------------------------------------
global qn := { gui: "", sb: "", dark: true, geom: "", animating: false }

global QNOTE_COLS := 110, QNOTE_ROWS := 50
global QNOTE_MIN_W := 360, QNOTE_MIN_H := 220
global QNOTE_ALPHA_FOCUS := 255, QNOTE_ALPHA_BLUR := 204   ; ~80% when unfocused

; palette mirrors the project theme globals in Mello-Workspace.ahk (defined
; locally so this file also works when run standalone)
global QNOTE_BG_DARK := "232a2f", QNOTE_FG_DARK := "f3f3f3"
global QNOTE_BG_LIGHT := "f3f3f3", QNOTE_FG_LIGHT := "1a2023"

global QNOTE_DIR := A_AppData "\Mello-Workspace"
global QNOTE_FILE := QNOTE_DIR "\qnote.txt"
global QNOTE_INI := QNOTE_DIR "\qnote.ini"

; ---- top-level wiring --------------------------------------------------------
OnMessage(0x06, QNote_OnActivate)       ; WM_ACTIVATE
OnMessage(0x24, QNote_OnMinMax)         ; WM_GETMINMAXINFO
OnMessage(0x1A, QNote_OnSettingChange)  ; WM_SETTINGCHANGE
OnExit(QNote_Save)

#!n::QNote_Toggle()

#HotIf QNote_IsActive()
Enter::QNote_Enter()
^l::QNote_Clear()
^d::QNote_ToggleTheme()
^b::QNote_WrapSel("**", "**")
^i::QNote_WrapSel("*", "*")
^+c::QNote_WrapSel("``", "``")           ; backtick = `code`
#HotIf

; ---- show / hide / toggle ----------------------------------------------------
QNote_Toggle() {
    global qn
    if (qn.gui = "")
        QNote_Create()
    if DllCall("IsWindowVisible", "ptr", qn.gui.Hwnd)
        QNote_Hide()
    else
        QNote_Show()
}

QNote_Show() {
    global qn, QNOTE_ALPHA_FOCUS
    g := qn.gui
    qn.animating := true
    dhw := DetectHiddenWindows(true)
    WinSetTransparent(0, "ahk_id " g.Hwnd)     ; start invisible to fade in
    DetectHiddenWindows(dhw)
    g.Show(qn.geom != "" ? qn.geom : "")
    WinActivate("ahk_id " g.Hwnd)
    a := 0
    loop {
        a := Min(a + 40, QNOTE_ALPHA_FOCUS)
        WinSetTransparent(a, "ahk_id " g.Hwnd)
        Sleep 10
    } until a >= QNOTE_ALPHA_FOCUS
    qn.animating := false
    try ControlFocus(g["QNoteText"])
}

QNote_Hide(*) {
    global qn
    g := qn.gui
    if (g = "" || !DllCall("IsWindowVisible", "ptr", g.Hwnd))
        return true
    qn.animating := true
    QNote_Save()
    a := QNOTE_ALPHA_FOCUS
    loop {
        a := Max(a - 40, 0)
        WinSetTransparent(a, "ahk_id " g.Hwnd)
        Sleep 10
    } until a <= 0
    g.Hide()
    qn.animating := false
    return true     ; consume Escape/Close so the GUI is never destroyed
}

; ---- construction ------------------------------------------------------------
QNote_Create() {
    global qn, QNOTE_COLS, QNOTE_ROWS
    pt := QNote_FontSize()
    cw := QNote_CharWidth("Consolas", pt)
    editW := cw * QNOTE_COLS + 28               ; chars + scrollbar/padding

    g := Gui("+AlwaysOnTop +Resize -MaximizeBox -MinimizeBox", "QuickNote")
    g.MarginX := 8, g.MarginY := 8
    g.SetFont("s" pt, "Consolas")
    edit := g.AddEdit("vQNoteText Multi WantReturn WantTab VScroll w" editW " r" QNOTE_ROWS)
    edit.OnEvent("Change", QNote_OnChange)
    sb := g.AddStatusBar()

    qn.gui := g, qn.sb := sb
    g.OnEvent("Escape", QNote_Hide)
    g.OnEvent("Close", QNote_Hide)
    g.OnEvent("Size", QNote_OnSize)

    QNote_DetectTheme()      ; OS default
    QNote_Restore()          ; may override text/geometry/theme from disk
    QNote_ApplyTheme()
    QNote_UpdateCounts()
}

QNote_FontSize() {
    h := A_ScreenHeight
    return h < 900 ? 9 : (h < 1080 ? 10 : 11)   ; resolution-aware, hard cap 11pt
}

QNote_CharWidth(font, pt) {
    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    height := -Round(pt * A_ScreenDPI / 72)
    hFont := DllCall("CreateFontW"
        , "int", height, "int", 0, "int", 0, "int", 0
        , "int", 400, "uint", 0, "uint", 0, "uint", 0
        , "uint", 0, "uint", 0, "uint", 0, "uint", 0, "uint", 0
        , "wstr", font, "ptr")
    old := DllCall("SelectObject", "ptr", hdc, "ptr", hFont, "ptr")
    sz := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "ptr", hdc, "wstr", "M", "int", 1, "ptr", sz)
    w := NumGet(sz, 0, "int")
    DllCall("SelectObject", "ptr", hdc, "ptr", old)
    DllCall("DeleteObject", "ptr", hFont)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
    return w > 0 ? w : Round(pt * 0.62)
}

; ---- theming -----------------------------------------------------------------
QNote_DetectTheme() {
    global qn
    try {
        v := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        qn.dark := (v = 0)
    } catch Any {
        qn.dark := true
    }
}

QNote_ApplyTheme() {
    global qn, QNOTE_BG_DARK, QNOTE_FG_DARK, QNOTE_BG_LIGHT, QNOTE_FG_LIGHT
    g := qn.gui
    bg := qn.dark ? QNOTE_BG_DARK : QNOTE_BG_LIGHT
    fg := qn.dark ? QNOTE_FG_DARK : QNOTE_FG_LIGHT
    g.BackColor := bg
    edit := g["QNoteText"]
    edit.Opt("Background" bg)
    edit.SetFont("c" fg)
    ; dark title bar (DWMWA_USE_IMMERSIVE_DARK_MODE = 20) — see lib/help_about.ahk
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 20, "int*", qn.dark ? 1 : 0, "uint", 4)
}

QNote_ToggleTheme() {
    global qn
    qn.dark := !qn.dark
    QNote_ApplyTheme()
    QNote_Save()
}

; ---- window event handlers ---------------------------------------------------
QNote_OnSize(thisGui, minMax, w, h) {
    global qn
    if (minMax = -1 || qn.gui = "")        ; ignore minimize
        return
    sbH := 24
    try {
        qn.sb.GetPos(&sx, &sy, &sw, &sh)
        sbH := sh
    }
    m := 8
    try qn.gui["QNoteText"].Move(m, m, w - 2 * m, h - sbH - 2 * m)
}

QNote_OnMinMax(wParam, lParam, msg, hwnd) {
    global qn, QNOTE_MIN_W, QNOTE_MIN_H
    if (qn.gui = "" || hwnd != qn.gui.Hwnd)
        return
    NumPut("int", QNOTE_MIN_W, lParam, 24)   ; MINMAXINFO.ptMinTrackSize.x
    NumPut("int", QNOTE_MIN_H, lParam, 28)   ; MINMAXINFO.ptMinTrackSize.y
    return 0
}

QNote_OnActivate(wParam, lParam, msg, hwnd) {
    global qn, QNOTE_ALPHA_FOCUS, QNOTE_ALPHA_BLUR
    if (qn.gui = "" || hwnd != qn.gui.Hwnd || qn.animating)
        return
    if !DllCall("IsWindowVisible", "ptr", hwnd)
        return
    active := (wParam & 0xFFFF) != 0         ; WA_INACTIVE = 0
    WinSetTransparent(active ? QNOTE_ALPHA_FOCUS : QNOTE_ALPHA_BLUR, "ahk_id " hwnd)
}

QNote_OnSettingChange(wParam, lParam, msg, hwnd) {
    global qn
    if (qn.gui = "")
        return
    QNote_DetectTheme()
    QNote_ApplyTheme()
}

; ---- status bar counts -------------------------------------------------------
QNote_OnChange(*) {
    QNote_UpdateCounts()
    SetTimer(QNote_Save, 0)        ; debounce: drop pending, reschedule
    SetTimer(QNote_Save, -1500)
}

QNote_UpdateCounts() {
    global qn
    txt := qn.gui["QNoteText"].Value
    chars := StrLen(txt)
    t := Trim(txt)
    words := (t = "") ? 0 : StrSplit(RegExReplace(t, "\s+", " "), " ").Length
    hints := "Win+Alt+N hide/show   Ctrl+L clear   Ctrl+D theme   Ctrl+B/I emphasis"
    qn.sb.SetText(hints "      " words " words, " chars " chars")
}

; ---- markdown-friendly editing ----------------------------------------------
QNote_IsActive() {
    global qn
    return qn.gui != "" && WinActive("ahk_id " qn.gui.Hwnd)
}

QNote_Clear(*) {
    global qn
    qn.gui["QNoteText"].Value := ""
    QNote_UpdateCounts()
    QNote_Save()
}

; Continue list prefixes (-, *, "1.") onto the next line.
QNote_Enter() {
    global qn
    try {
        edit := qn.gui["QNoteText"]
        hwnd := edit.Hwnd
        selStart := Buffer(4, 0)
        SendMessage(0x00B0, selStart.Ptr, 0, hwnd)          ; EM_GETSEL -> caret
        caret := NumGet(selStart, 0, "UInt")
        lineNo := SendMessage(0x00C9, caret, 0, hwnd)        ; EM_LINEFROMCHAR
        buf := Buffer(2048, 0)
        NumPut("UShort", 1000, buf, 0)                       ; max chars to copy
        len := SendMessage(0x00C4, lineNo, buf.Ptr, hwnd)    ; EM_GETLINE
        line := StrGet(buf, len, "UTF-16")
        prefix := ""
        if RegExMatch(line, "^\s*(?:[-*]|\d+\.)\s+", &m) && Trim(line) != RTrim(m[0])
            prefix := m[0]
        QNote_ReplaceSel("`r`n" prefix)
    } catch Any {
        Send "{Enter}"
    }
}

; Wrap the current selection (or insert markers at the caret) with pre/post.
QNote_WrapSel(pre, post) {
    global qn
    try {
        edit := qn.gui["QNoteText"]
        hwnd := edit.Hwnd
        s := Buffer(4, 0), e := Buffer(4, 0)
        SendMessage(0x00B0, s.Ptr, e.Ptr, hwnd)             ; EM_GETSEL
        st := NumGet(s, 0, "UInt"), en := NumGet(e, 0, "UInt")
        sel := ""
        if (en > st) {
            n := SendMessage(0x000E, 0, 0, hwnd)            ; WM_GETTEXTLENGTH
            tb := Buffer((n + 1) * 2, 0)
            SendMessage(0x000D, n + 1, tb.Ptr, hwnd)        ; WM_GETTEXT (CRLF-aligned)
            full := StrGet(tb, "UTF-16")
            sel := SubStr(full, st + 1, en - st)
        }
        QNote_ReplaceSel(pre sel post)
        if (sel = "") {                                     ; park caret between markers
            caret := st + StrLen(pre)
            SendMessage(0x00B1, caret, caret, hwnd)         ; EM_SETSEL
        }
    } catch Any {
        return
    }
}

QNote_ReplaceSel(str) {
    global qn
    edit := qn.gui["QNoteText"]
    b := Buffer(StrPut(str, "UTF-16"))
    StrPut(str, b, "UTF-16")
    SendMessage(0x00C2, 1, b.Ptr, edit.Hwnd)                ; EM_REPLACESEL (undoable)
}

; ---- persistence --------------------------------------a-----------------------
QNote_Save(*) {
    global qn, QNOTE_DIR, QNOTE_FILE, QNOTE_INI
    if (qn.gui = "")
        return
    try {
        if !DirExist(QNOTE_DIR)
            DirCreate(QNOTE_DIR)
        f := FileOpen(QNOTE_FILE, "w", "UTF-8")
        f.Write(qn.gui["QNoteText"].Value)
        f.Close()
        if DllCall("IsWindowVisible", "ptr", qn.gui.Hwnd) {
            qn.gui.GetPos(&x, &y, &w, &h)
            IniWrite(x, QNOTE_INI, "window", "x")
            IniWrite(y, QNOTE_INI, "window", "y")
            IniWrite(w, QNOTE_INI, "window", "w")
            IniWrite(h, QNOTE_INI, "window", "h")
        }
        IniWrite(qn.dark ? 1 : 0, QNOTE_INI, "window", "dark")
    } catch Any {
        ; saving is best-effort; never interrupt the user
    }
}

QNote_Restore() {
    global qn, QNOTE_FILE, QNOTE_INI, QNOTE_MIN_W, QNOTE_MIN_H
    try {
        if FileExist(QNOTE_FILE)
            qn.gui["QNoteText"].Value := FileRead(QNOTE_FILE, "UTF-8")
    } catch Any {
    }
    qn.geom := ""
    try {
        x := IniRead(QNOTE_INI, "window", "x", "")
        y := IniRead(QNOTE_INI, "window", "y", "")
        w := IniRead(QNOTE_INI, "window", "w", "")
        h := IniRead(QNOTE_INI, "window", "h", "")
        if (x != "" && y != "" && w != "" && h != "") {
            w := Max(w + 0, QNOTE_MIN_W), h := Max(h + 0, QNOTE_MIN_H)
            x := Min(Max(x + 0, 0), A_ScreenWidth - 100)
            y := Min(Max(y + 0, 0), A_ScreenHeight - 100)
            qn.geom := "x" x " y" y " w" w " h" h
        }
        d := IniRead(QNOTE_INI, "window", "dark", "")
        if (d != "")
            qn.dark := (d = 1)
    } catch Any {
    }
}
