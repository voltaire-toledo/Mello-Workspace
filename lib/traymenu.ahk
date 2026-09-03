#Requires AutoHotkey v2.0

; ╭════════════════════════════════════════════════════════════════════════════════════════════════════════════════─╮
; ║  _TrayMenu.AHK                                                                                                  ║
; ║    - Manages most things related to the tray menu's appearance and behavior.                                    ║
; ╰═════════════════════════════════════════════════════════════════════════════════════════════════════════════════╯

; ╭───────────╮
; │ VARIABLES │
; ╰───────────╯
; Use A_TrayMenu directly (no need for custom menu object)

; Notification Tray Icons
trayico_default := icons_path . thisapp_shortname . ".ico"
trayico_osxkeybd := icons_path . thisapp_shortname . "-AK.ico"
trayico_rdsh := icons_path . thisapp_shortname . "-RDP.ico"
trayico_rdsh_osxkeybd := icons_path . thisapp_shortname . "-RAK.ico"
trayico_suspend := icons_path . thisapp_shortname . "-paused.ico"

; Menu Items
trayitem_app_ref := "About " . thisapp_name . "`tCTRL + ⊞ + ALT + F1"
trayitem_app_ref_ico := trayico_default
trayitem_reload := "&Reload Script`tCTRL + ⊞ + ALT + R"
trayitem_reload_ico := icons_path . "reload.ico"
trayitem_debug := "AutoHotkey Native Tools"
trayitem_debug_ico := icons_path . "debug.ico"
trayitem_ahkhelp := "AutoHotkey Help`tCTRL + ⊞ + ALT + F2"
trayitem_ahkhelp_ico := icons_path . "help.ico"
trayitem_exit := "E&xit " . thisapp_name
trayitem_exit_ico := icons_path . "stop.ico"
trayitem_edit := "E&dit Script`tCTRL + ⊞ + ALT + E"
trayitem_edit_ico := icons_path . "edit.ico"
trayitem_runatstartup := "Launch at Startup"
trayitem_usingmackeybd := "Using Mac Keyboard Layout"
trayitem_disablestartupsound := "Disable Startup Sound"
trayitem_openappdir := "Open script &folder`tCTRL + ⊞ + ALT + F"
trayitem_openappdir_ico := icons_path . "icons8-code-folder-32.ico"
traymenu_icon_checked := icons_path . "checked.ico"
traymenu_icon_unchecked := icons_path . "unchecked.ico"

try {
  RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", "Mello-Ops")
  trayitem_runatstartup_ico := traymenu_icon_checked
} catch {
  trayitem_runatstartup_ico := traymenu_icon_unchecked
}

trayitem_disablestartupsound_ico := IsStartupSoundDisabled ? traymenu_icon_checked : traymenu_icon_unchecked
trayitem_usingmackeybd_ico := IsMacKeyboard ? traymenu_icon_checked : traymenu_icon_unchecked

; ╭───────────────────────────────────────────────────────────────────╮
; │  Helper: SetMenuIcon                                             │
; ╰───────────────────────────────────────────────────────────────────╯
SetMenuIcon(menuObj, itemName, iconSpec) {
  if !IsObject(menuObj)
    return
  if (iconSpec = "")
    return
  ; If iconSpec is numeric string like "-206" or plain number, use A_AhkPath resource
  if (IsNumber(iconSpec) || RegExMatch(iconSpec, "^\s*-?\d+\s*$")) {
    menuObj.SetIcon(itemName, A_AhkPath, iconSpec + 0)
    return
  }
  ; If iconSpec like "res:<num>"
  if RegExMatch(iconSpec, "^\s*res\s*:\s*(-?\d+)\s*$", &m)
    menuObj.SetIcon(itemName, A_AhkPath, m[1] + 0, 24)
  else
    menuObj.SetIcon(itemName, iconSpec, , 24)
}

; ╭───────────────────────────────────────────────────────────────────╮
; │  Build the Tray menu (using A_TrayMenu directly)                  │
; ╰───────────────────────────────────────────────────────────────────╯

BuildTrayMenu() {
  ; First, delete all default items
  A_TrayMenu.Delete()

  ; Main items
  A_TrayMenu.Add(trayitem_app_ref, ShowHelpAbout)
  SetMenuIcon(A_TrayMenu, trayitem_app_ref, trayitem_app_ref_ico)

  A_TrayMenu.Add() ; separator

  A_TrayMenu.Add(trayitem_runatstartup, ToggleRunAtStartup)
  SetMenuIcon(A_TrayMenu, trayitem_runatstartup, trayitem_runatstartup_ico)

  A_TrayMenu.Add(trayitem_usingmackeybd, ToggleMacKeyboard)
  SetMenuIcon(A_TrayMenu, trayitem_usingmackeybd, trayitem_usingmackeybd_ico)

  A_TrayMenu.Add(trayitem_disablestartupsound, ToggleDisableStartupSound)
  SetMenuIcon(A_TrayMenu, trayitem_disablestartupsound, trayitem_disablestartupsound_ico)

  A_TrayMenu.Add() ; separator


  ; Options submenu
  OptionsMenu := Menu()
  A_TrayMenu.Add("Options", OptionsMenu)

  ; MouseMenu := Menu()
  ; OptionsMenu.Add("Mouse Cursor Actions", MouseMenu)
  ; MouseMenu.Add("Increase Mouse Cursor Size`t CTRL + ⊞ + ]", IncCursorSize)
  ; MouseMenu.Add("Decrease Mouse Cursor Size`t CTRL + ⊞ + [", DecCursorSize)
  ; MouseMenu.Add("Increase Mouse Cursor Speed", IncMouseSpeed)
  ; MouseMenu.Disable("Increase Mouse Cursor Speed")
  ; MouseMenu.Add("Decrease Mouse Cursor Speed", DecMouseSpeed)
  ; MouseMenu.Disable("Decrease Mouse Cursor Speed")
  OptionsMenu.Add("Increase Mouse Cursor Size`t CTRL + ⊞ + ]", IncCursorSize)
  OptionsMenu.Add("Decrease Mouse Cursor Size`t CTRL + ⊞ + [", DecCursorSize)
  OptionsMenu.Add("Increase Mouse Cursor Speed", IncMouseSpeed)
  OptionsMenu.Disable("Increase Mouse Cursor Speed")
  OptionsMenu.Add("Decrease Mouse Cursor Speed", DecMouseSpeed)
  OptionsMenu.Disable("Decrease Mouse Cursor Speed")

  OptionsMenu.Add("Toggle Light/Dark Theme", ToggleTheme)
  OptionsMenu.Disable("Toggle Light/Dark Theme")
  OptionsMenu.Add("Toggle Show/Auto-Hide Taskbar", ToggleTaskbar)
  OptionsMenu.Disable("Toggle Show/Auto-Hide Taskbar")
  OptionsMenu.Add("Toggle Show/Hide Desktop Icons", ToggleDesktopIcons)
  OptionsMenu.Disable("Toggle Show/Hide Desktop Icons")

  A_TrayMenu.Add() ; separator

  ; Custom Tools submenu
  ; CustomMenu := Menu()
  ; A_TrayMenu.Add("Custom Tools", CustomMenu)
  ; CustomMenu.Add("Custom Notes", ShowCustomNotes)
  ; CustomMenu.Disable("Custom Notes")
  ; CustomMenu.Add("Focus Window Highlighter", ToggleWindowHighlighter)
  ; CustomMenu.Disable("Focus Window Highlighter")
  ; CustomMenu.Add("OverFlow Notifier", ToggleOverflowNotifier)
  ; CustomMenu.Disable("OverFlow Notifier")
  ; CustomMenu.Add("Chime", ToggleChime)
  ; CustomMenu.Disable("Chime")

  ; Mello-Workspace Script-Related Actions submenu
  AHKActionsMenu := Menu()
  A_TrayMenu.Add("Mello-Workspace Script-Related Actions", AHKActionsMenu)
  AHKActionsMenu.Add(trayitem_reload, ReloadAndReturn)
  SetMenuIcon(AHKActionsMenu, trayitem_reload, trayitem_reload_ico)
  AHKActionsMenu.Add(trayitem_openappdir, OpenScriptDir)
  SetMenuIcon(AHKActionsMenu, trayitem_openappdir, trayitem_openappdir_ico)
  AHKActionsMenu.Add(trayitem_edit, EditAndReturn)
  SetMenuIcon(AHKActionsMenu, trayitem_edit, trayitem_edit_ico)

  ; AutoHotkey Native Tools submenu
  AhkNativeMenu := Menu()
  A_TrayMenu.Add(trayitem_debug, AhkNativeMenu)
  AhkNativeMenu.Add("AutoHotkey WindowSpy`tCTRL + ⊞ + ALT + F3", ShowAHKSpy)
  AhkNativeMenu.Add(trayitem_ahkhelp, ShowHelp)
  SetMenuIcon(AhkNativeMenu, trayitem_ahkhelp, trayitem_ahkhelp_ico)
  AhkNativeMenu.Add("Key & Mouse Button History", ShowListLines)
  AhkNativeMenu.Add("ListHotKeys", ListSimpleHotkeys)
  A_TrayMenu.Add() ; separator

  A_TrayMenu.Add(trayitem_exit, EndScript)
  SetMenuIcon(A_TrayMenu, trayitem_exit, trayitem_exit_ico)

  ; Set default action (double-click) to show help
  A_TrayMenu.Default := trayitem_app_ref
}

; --- Existing helper functions kept intact ---
ToggleRunAtStartup(*) {
  global trayitem_runatstartup_ico
  regKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
  regVal := "Mello-Ops"
  isRegistered := false
  try {
    RegRead(regKey, regVal)
    isRegistered := true
  } catch {
    isRegistered := false
  }

  if isRegistered {
    RegDelete(regKey, regVal)
    trayitem_runatstartup_ico := traymenu_icon_unchecked
  } else {
    ; Use Mello-Workspace.exe if it exists, otherwise fall back to the currently running executable
    mwsExePath := A_ScriptDir . "\Mello-Workspace.exe"
    exePath := FileExist(mwsExePath) ? mwsExePath : A_AhkPath
    RegWrite('"' . exePath . '" "' . A_ScriptFullPath . '"', "REG_SZ", regKey, regVal)
    trayitem_runatstartup_ico := traymenu_icon_checked
  }
  SetMenuIcon(A_TrayMenu, trayitem_runatstartup, trayitem_runatstartup_ico)
}

ToggleMacKeyboard(*) {
  global IsMacKeyboard, trayitem_usingmackeybd_ico
  IsMacKeyboard := !IsMacKeyboard
  trayitem_usingmackeybd_ico := IsMacKeyboard ? traymenu_icon_checked : traymenu_icon_unchecked
  SetMenuIcon(A_TrayMenu, trayitem_usingmackeybd, trayitem_usingmackeybd_ico)
  SetNotificationIcon(IsRemoteSession(), IsMacKeyboard)
}

ToggleDisableStartupSound(*) {
  global IsStartupSoundDisabled, trayitem_disablestartupsound_ico
  regKey := "HKCU\Software\Mello-Workspace"
  regVal := "DisableStartupSound"
  IsStartupSoundDisabled := !IsStartupSoundDisabled
  try {
    RegWrite(IsStartupSoundDisabled ? 1 : 0, "REG_DWORD", regKey, regVal)
  } catch {
    ; Fallback if registry write fails
  }
  trayitem_disablestartupsound_ico := IsStartupSoundDisabled ? traymenu_icon_checked : traymenu_icon_unchecked
  SetMenuIcon(A_TrayMenu, trayitem_disablestartupsound, trayitem_disablestartupsound_ico)
}

ShowListLines(*) {
  ListLines
}
ListSimpleHotkeys(*) {
  ListHotkeys
}
OpenScriptDir(*) {
  Run A_ScriptDir
}

ShowHelp(*) {
  chmPath := A_AhkPath . "\..\ahkbin\AutoHotkey.chm"
  if FileExist(chmPath) {
    Run chmPath
    return
  }

  if FileExist(A_ProgramFiles "\AutoHotkey\AutoHotkey.chm")
    chmPath := A_ProgramFiles "\AutoHotkey\AutoHotkey.chm"
  else {
    MsgBox "Could not find the AutoHotkey folder."
    return
  }
}

ShowAHKSpy(*) {
  ; Search for WindowSpy.ahk in the current directory or the ahkbin subfolder
  spyScriptName := "\WindowSpy.ahk"

  ; spyPath is an array of potential paths to check for WindowSpy.ahk
  spyPath := [
    A_AhkPath "\..\ahkbin" spyScriptName,
    A_ScriptDir "\..\ahkbin" spyScriptName,
    A_AhkPath "\.." spyScriptName,
    A_ScriptDir spyScriptName
  ]
  for path in spyPath {
    if FileExist(path) {
      Run spyPath[A_Index]
      break
    }
  }

}

SetNotificationIcon(isRDSH := false, isOSXKeybd := false)
{
  ; ╭───────────────────────────────────────────────────────────────────────────────╮
  ; │ SetNotificationIcon(isRDSH, isOSXKeybd)                                       │
  ; │   - isRDSH [opt, bool, default=false]: Is running in RDP/Remote Session       │
  ; │   - isOSXKeybd [opt, bool, default=false]: Using Mac keybd to control Windows │
  ; ├───────────────────────────────────────────────────────────────────────────────┤
  ; │ Return Value:  Path to current ICO file                                       │
  ; ╰───────────────────────────────────────────────────────────────────────────────╯
  if (isRDSH && isOSXKeybd) {
    current_tray_icon := trayico_rdsh_osxkeybd
  } else if (isRDSH && !isOSXKeybd) {
    current_tray_icon := trayico_rdsh
  } else if (!isRDSH && isOSXKeybd) {
    current_tray_icon := trayico_osxkeybd
  } else {
    current_tray_icon := trayico_default
  }
  TraySetIcon(current_tray_icon)
  TraySetIcon , , true
  return current_tray_icon
}

; Placeholder functions
IncCursorSize(*)
{
  SetCursorSize(+1)
}
DecCursorSize(*)
{
  SetCursorSize(-1)
}
IncMouseSpeed(*)
{

}
DecMouseSpeed(*)
{

}
ToggleTheme(*)
{

}
ToggleTaskbar(*)
{

}
ToggleDesktopIcons(*)
{

}
ShowCustomNotes(*)
{

}
ToggleWindowHighlighter(*)
{

}
ToggleOverflowNotifier(*)
{

}
ToggleChime(*)
{

}

; Apply theme helpers
SetPreferredAppMode()
FlushMenuThemes()

; ╭───────────────────────────────────────────────────────────────────╮
; │  DisplayTrayMenu - Initialize tray menu system                   │
; ╰───────────────────────────────────────────────────────────────────╯
DisplayTrayMenu() {
  ; Set the Tray icon
  SetNotificationIcon(IsRemoteSession(), IsMacKeyboard)

  ; Remove default tray items
  A_TrayMenu.Delete()

  ; Set tooltip
  __LoadDuration := A_TickCount - __StartTime
  __LoadDuration := Round(__LoadDuration / 1000, 2)
  A_IconTip := "Mello-Workspace Shortcuts`nStartup Duration: " __LoadDuration " s`nScript: " A_ScriptFullPath

  ; Set tooltip
  __LoadDuration := A_TickCount - __StartTime
  __LoadDuration := Round(__LoadDuration / 1000, 2)
  A_IconTip := "Mello-Workspace Shortcuts`nStartup Duration: " __LoadDuration " s`nScript: " A_ScriptFullPath

  ; Build the menu (replaces default items)
  BuildTrayMenu()
}