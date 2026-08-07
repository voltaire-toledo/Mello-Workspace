#Requires AutoHotkey v2.0
#Warn All, StdOut

; ╭─────────────────────────────────────────────────────────---··
; │ Mello-Workspace - AutoHotkey Script                          │
; │ Automations leveraging AutoHotkey for enhanced productivity  │
; ╰──────────────────────────────────────────────────────────────╯

#SingleInstance Force
SendMode "Input"    ; Use default Windows response to built-in responses to keyboard shortcutsm, e.g. [Alt/⌥]+[<-]
SetTitleMatchMode 2 ; Default matching behavior for searches using WinTitle, e.g. WinWait
InstallKeybdHook  ; Install the keyboard hook to capture key events

; ╭──────────────────────────────────────────────────────────────╮
; │ GLOBAL SCOPE VARIABLES                                       │
; ╰──────────────────────────────────────────────────────────────╯
global __StartTime := A_TickCount
global __Uptime := 99999 ; Placeholder for uptime, will be updated later
global thisapp_name := "Mello-Workspace"
global thisapp_shortname := "MWS"
global thisapp_version := "0.1.92 (Maintenance Only)"
global process_theme := ""
global media_path := ".\media"
global icons_path := media_path . "\icons\"
global sounds_path := media_path . "\sounds\"
global app_ico := icons_path . thisapp_shortname . ".ico"
global sound_file_startrun := sounds_path . "start_app.wav"
global sound_file_oopsie := sounds_path . "oopsie.wav"
global theme_light_bgcolor := "f3f3f3"
global theme_dark_bgcolor := "232a2f"
global theme_light_fgcolor := "1a2023"
global theme_dark_fgcolor := "f3f3f3"
global IsMacKeyboard := false

; ╭──────────────────────────────────────────────────────────────╮
; │ HANDLERS                                                     │
; ╰──────────────────────────────────────────────────────────────╯
OnExit ExitAppFunction

; ╭──────────────────────────────────────────────────────────────╮
; │ Define Splash Screen and Show                                │
; ╰──────────────────────────────────────────────────────────────╯
global app_splashGUI := Gui("+ToolWindow -Caption", thisapp_name " Splash")
app_splashGUI.BackColor := "232a2f"
app_splashGUI.SetFont("s20 bold cFFFFFF", "Segoe UI")
app_splashGUI.AddPicture("x20 y16 w64 h64 Icon1", app_ico)
; app_splashGUI.SetFont("s16 bold", "Segoe UI")
app_splashGUI.AddText("x96 y15", thisapp_name)
app_splashGUI.SetFont("s14 norm", "Segoe UI")
app_splashGUI.AddText("x96 y50", "Version " thisapp_version)
app_splashGUI.Show("w410 h96 Center")
app_splashGUI.GetPos(,, &w, &h)
WinSetRegion("0-0 w" . w . " h" . h . " r20-20", app_splashGUI.Hwnd)
; --- End Splash Screen ---


; ╭──────────────────────────────────────────────────────────────╮
; │ LIBRARY INCLUDES                                             │
; ╰──────────────────────────────────────────────────────────────╯
#Include "*i %A_ScriptDir%\custom\.mslrc.ahk"
#Include <traymenu>
#Include <help_about>
#Include <app-automate>
#include <winui-mgmt>
#include <arpeggios>
#Include <cursor-mgmt>
#Include <hotkeys-core>
#Include <hotstrings-mgmt>
#Include <app-dyn>
#Include plugins\QuickNoteMD\QuickNoteMD.ahk

; ╭──────────────────────────────────────────────────────────────╮
; │ ** PERSONAL CUSTOMIZATIONS HERE **                           │
; ╰──────────────────────────────────────────────────────────────╯
if !FileExist(".\custom\_custom_functions.ahk") {
  ; FileCreate ".\custom\_custom_functions.ahk"
  FileAppend "
  (
  ; ╭───────────────────────────────────────────────────╮
  ; │ Custom Functions for Mello-Workspace              │
  ; │ Add your personal functions and hotkeys here      │
  ; ╰───────────────────────────────────────────────────╯

  ; Example custom hotkey:
  ; ^!j::MsgBox('Custom hotkey Ctrl+Alt+J triggered!')

  )",
    ".\custom\_custom_functions.ahk"
}
DisplayTrayMenu()
SoundPlay sound_file_startrun
; Fade out the splash now that loading is complete
SetTimer FadeSplashOut, -800

; End of the auto-execute section. The script is now persistent and will wait for hotkeys.
FadeSplashOut() {
  static alpha := 255
  global app_splashGUI
  alpha -= 18
  if (alpha <= 0) {
    try app_splashGUI.Destroy()
    return
  }
  try WinSetTransparent(alpha, app_splashGUI.Hwnd)
  SetTimer FadeSplashOut, -25
}

; ╭──────────────────────────────────────────────────────────────╮
; │ FUNCTIONS                                                    │
; ╰──────────────────────────────────────────────────────────────╯
IsRemoteSession() {
  ; Returns non-zero if running in an RDP/remote session
  return DllCall("user32.dll\GetSystemMetrics", "Int", 0x1000)
}

ReloadAndReturn(*) {
  Reload  ; INFO: Reload creates a new PID
}

EditAndReturn(*) {
  Edit
  return
}

EndScript(*) {
  ExitApp
}

AppsUseLightTheme() {
  keyName := "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
  valueName := "AppsUseLightTheme"
  return RegRead(keyName, valueName)
}

SetPreferredAppMode(option := "") {
  static options := Map()
  if !options.Count {
    options.CaseSense := false
    options.Set("Default", 0, "AllowDark", 1, "ForceDark", 2, "ForceLight", 3, "Max", 4)
    options.Default := !AppsUseLightTheme()
  }
  hModule := DllCall("kernel32.dll\GetModuleHandle", "str", "uxtheme.dll", "ptr")
  SetPreferredAppMode := DllCall("kernel32.dll\GetProcAddress", "ptr", hModule, "ptr", 135, "ptr")
  DllCall(SetPreferredAppMode, "int", options.Get(option))
  DllCall("kernel32.dll\FreeLibrary", "ptr", hModule)
}

FlushMenuThemes() {
  hModule := DllCall("kernel32.dll\GetModuleHandle", "str", "uxtheme.dll", "ptr")
  FlushMenuThemes := DllCall("kernel32.dll\GetProcAddress", "ptr", hModule, "ptr", 136, "ptr")
  DllCall(FlushMenuThemes)
  DllCall("kernel32.dll\FreeLibrary", "ptr", hModule)
}

ExitAppFunction(ExitReason, ExitCode)
{
  ; Cleanup or undo any systems settings set by Mello-Workspace

  ; Example 1: Reset mouse cursor size
  ; DllCall("SystemParametersInfo", "UInt", SPI_SETCURSORS, "UInt", 0, "Ptr", origCursorSize, "UInt", SPIF_UPDATEINIFILE | SPIF_SENDCHANGE) ; Update the cursor to apply changes , "Ptr", 0, "UInt", SPIF_UPDATEINIFILE | SPIF_SENDCHANGE) ; Update the cursor to apply changes

  Switch ExitReason, false
  {
    Case "Logoff":  ; User logged off
      ; Result := MsgBox("Are you sure you want to exit?", , 4)
      ; if Result = "No" {
      ;   return 1  ; Callbacks must return non-zero to avoid exit.
      ; }
    Case "Shutdown":  ; Computer is shutting down
      ; Result := MsgBox("Are you sure you want to exit?", , 4)
      ; if Result = "No" {
      ;   return 1  ; Callbacks must return non-zero to avoid exit.
      ; }
    Case "Close":     ; Received WM_CLOSE or WM_QUIT message
    Case "Error":     ; Runtime error
    Case "Menu":      ; Standard tray menu exit
    Case "Exit":      ; User-initiated exit (Exit or ExitApp)
    Case "Reload":    ; Only applies when the Reload function is called within the script
    Case "Single":    ; User tried to start another instance; Only applies when the SingleInstance function; doesn't apply on its own Reload()
      ; Result := MsgBox("Loading a new instance?", , 4)
      ; if Result = "No" {
      ;   return 1  ; Callbacks must return non-zero to avoid exit.
      ; }
    Default:          ; Only if it was able to catch an exception
  }
}