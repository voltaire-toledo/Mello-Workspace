#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

; ╭──────────────────────────────────────────────────────────────╮
; │ SoundSwap — audio device switcher plugin                     │
; │ Standalone-capable: #Include'd into Mello-Workspace.ahk, or  │
; │ run directly as plugins\SoundSwap\SoundSwap.ahk.             │
; ╰──────────────────────────────────────────────────────────────╯

global SWAP_SELF_DIR := SubStr(A_LineFile, 1, InStr(A_LineFile, "\",, -1) - 1)
global SWAP_DIR := A_AppData . "\Mello-Workspace\SoundSwap"
global SWAP_INI := SWAP_DIR . "\config.ini"
global SWAP_MUTEX_NAME := "Local\MelloWorkspace_SoundSwap_Mutex"

#Include "%A_LineFile%\..\lib\SoundSwap-Com.ahk"
#Include "%A_LineFile%\..\lib\SoundSwap-Gui.ahk"

global SWAP_IsStandalone := !InStr(A_ScriptFullPath, "SoundSwap.ahk") ? false : (A_ScriptFullPath = SWAP_SELF_DIR . "\SoundSwap.ahk")
global SWAP_HasMutex := false
global SWAP_Config := Map()

SWAP_Init()

; ── Init ──────────────────────────────────────────────────────────
SWAP_Init() {
  global SWAP_DIR, SWAP_Config, SWAP_IsStandalone, SWAP_HasMutex, SWAP_MUTEX_NAME

  if !DirExist(SWAP_DIR)
    DirCreate(SWAP_DIR)

  ; ADR-0004: guard against standalone + #Include'd running simultaneously.
  hMutex := DllCall("CreateMutex", "ptr", 0, "int", true, "str", SWAP_MUTEX_NAME, "ptr")
  alreadyRunning := (A_LastError = 183) ; ERROR_ALREADY_EXISTS
  if alreadyRunning {
    if SWAP_IsStandalone {
      SWAP_ShowStatusOsd("SoundSwap is already active via Mello-Workspace.")
      return ; skip hotkey registration entirely in this process
    }
  } else {
    SWAP_HasMutex := true
  }

  SWAP_Config := SWAP_LoadConfig()
  if SWAP_Config["Enabled"]
    SWAP_RegisterHotkeys()

  ; Refresh the tray immediately before AutoHotkey displays its context menu.
  OnMessage(0x404, SWAP_OnTrayClick, -1)

  if SWAP_IsStandalone
    SWAP_BuildStandaloneTray()
}

; ── Config persistence ───────────────────────────────────────────
SWAP_DefaultConfig() {
  cfg := Map()
  cfg["Enabled"] := true
  cfg["HotkeyOutput"] := "^!F12"
  cfg["HotkeyInput"] := "^!F11"
  cfg["OutputMode"] := "Block"
  cfg["OutputList"] := []
  cfg["InputMode"] := "Block"
  cfg["InputList"] := []
  cfg["LastOutputId"] := ""
  cfg["LastInputId"] := ""
  return cfg
}

; Missing/corrupt ini -> regenerate defaults, never crash.
SWAP_LoadConfig() {
  global SWAP_INI
  cfg := SWAP_DefaultConfig()
  if !FileExist(SWAP_INI) {
    SWAP_SaveConfig(cfg)
    return cfg
  }
  try {
    cfg["Enabled"] := !!IniRead(SWAP_INI, "General", "Enabled", cfg["Enabled"] ? 1 : 0)
    cfg["HotkeyOutput"] := IniRead(SWAP_INI, "Hotkeys", "CycleOutput", cfg["HotkeyOutput"])
    cfg["HotkeyInput"] := IniRead(SWAP_INI, "Hotkeys", "CycleInput", cfg["HotkeyInput"])
    cfg["OutputMode"] := IniRead(SWAP_INI, "Output", "Mode", cfg["OutputMode"])
    cfg["OutputList"] := SWAP_SplitList(IniRead(SWAP_INI, "Output", "List", ""))
    cfg["InputMode"] := IniRead(SWAP_INI, "Input", "Mode", cfg["InputMode"])
    cfg["InputList"] := SWAP_SplitList(IniRead(SWAP_INI, "Input", "List", ""))
    cfg["LastOutputId"] := IniRead(SWAP_INI, "State", "LastOutputId", "")
    cfg["LastInputId"] := IniRead(SWAP_INI, "State", "LastInputId", "")
  } catch {
    cfg := SWAP_DefaultConfig()
    SWAP_SaveConfig(cfg)
  }
  return cfg
}

SWAP_SaveConfig(cfg) {
  global SWAP_INI
  try {
    IniWrite(cfg["Enabled"] ? 1 : 0, SWAP_INI, "General", "Enabled")
    IniWrite(cfg["HotkeyOutput"], SWAP_INI, "Hotkeys", "CycleOutput")
    IniWrite(cfg["HotkeyInput"], SWAP_INI, "Hotkeys", "CycleInput")
    IniWrite(cfg["OutputMode"], SWAP_INI, "Output", "Mode")
    IniWrite(SWAP_JoinList(cfg["OutputList"]), SWAP_INI, "Output", "List")
    IniWrite(cfg["InputMode"], SWAP_INI, "Input", "Mode")
    IniWrite(SWAP_JoinList(cfg["InputList"]), SWAP_INI, "Input", "List")
    IniWrite(cfg["LastOutputId"], SWAP_INI, "State", "LastOutputId")
    IniWrite(cfg["LastInputId"], SWAP_INI, "State", "LastInputId")
  }
}

SWAP_SplitList(s) {
  arr := []
  if (s = "")
    return arr
  for id in StrSplit(s, ",")
    if (id != "")
      arr.Push(id)
  return arr
}

SWAP_JoinList(arr) {
  s := ""
  for id in arr
    s .= (s = "" ? "" : ",") . id
  return s
}

; ── Filtering / eligibility ──────────────────────────────────────
; A device is eligible for cycling based on the kind's Mode + List (allow/block, Q-doc), keyed
; by device ID never friendly name.
SWAP_EligibleDevices(kind) {
  global SWAP_Config
  all := SWAP_EnumDevices(kind)
  mode := (kind = "Output") ? SWAP_Config["OutputMode"] : SWAP_Config["InputMode"]
  list := (kind = "Output") ? SWAP_Config["OutputList"] : SWAP_Config["InputList"]
  listSet := Map()
  for id in list
    listSet[id] := true

  eligible := []
  for dev in all {
    inList := listSet.Has(dev.id)
    if (mode = "Allow") {
      if inList
        eligible.Push(dev)
    } else { ; Block (default)
      if !inList
        eligible.Push(dev)
    }
  }
  ; If filtering blocked everything, fallback to all active devices to avoid hard lock
  if !eligible.Length && all.Length
    return all
  return eligible
}

; ── Hotkeys ───────────────────────────────────────────────────────
SWAP_RegisterHotkeys() {
  global SWAP_Config
  HotIf()
  try Hotkey(SWAP_Config["HotkeyOutput"], (*) => SWAP_Cycle("Output"))
  try Hotkey(SWAP_Config["HotkeyInput"], (*) => SWAP_Cycle("Input"))
}

SWAP_ReregisterHotkeys(newOutputCombo, newInputCombo) {
  global SWAP_Config
  HotIf()
  try Hotkey(SWAP_Config["HotkeyOutput"], "Off")
  try Hotkey(SWAP_Config["HotkeyInput"], "Off")
  SWAP_Config["HotkeyOutput"] := newOutputCombo
  SWAP_Config["HotkeyInput"] := newInputCombo
  if SWAP_Config["Enabled"]
    SWAP_RegisterHotkeys()
}

; Toggles the plugin hotkeys on/off at runtime (About dialog "Enabled" checkbox).
SWAP_SetEnabled(enabled) {
  global SWAP_Config
  SWAP_Config["Enabled"] := enabled
  SWAP_SaveConfig(SWAP_Config)
  if enabled {
    SWAP_RegisterHotkeys()
  } else {
    try Hotkey(SWAP_Config["HotkeyOutput"], "Off")
    try Hotkey(SWAP_Config["HotkeyInput"], "Off")
  }
}

; Q1: alphabetical cycling. Q2: only advances through eligible + currently-active devices;
; devices that disappear mid-rotation are skipped, not errored on.
SWAP_Cycle(kind) {
  global SWAP_Config
  SWAP_SyncDefaultState()
  devices := SWAP_EligibleDevices(kind)
  if !devices.Length {
    SWAP_RefreshTray()
    SWAP_ShowStatusOsd("No eligible " . kind . " devices to cycle.")
    return
  }

  lastId := (kind = "Output") ? SWAP_Config["LastOutputId"] : SWAP_Config["LastInputId"]
  currentIndex := 0
  for i, dev in devices {
    if (dev.id = lastId) {
      currentIndex := i
      break
    }
  }
  nextIndex := Mod(currentIndex, devices.Length) + 1
  nextDevice := devices[nextIndex]

  SWAP_SwitchTo(kind, nextDevice)
}

SWAP_SwitchTo(kind, device) {
  global SWAP_Config
  ok := SWAP_SetDefaultDevice(device.id)
  if !ok {
    SWAP_ShowStatusOsd("Failed to switch " . kind . " to " . device.name)
    return
  }

  if (kind = "Output")
    SWAP_Config["LastOutputId"] := device.id
  else
    SWAP_Config["LastInputId"] := device.id
  SWAP_SaveConfig(SWAP_Config)

  volume := SWAP_GetVolumeScalar(device.id)
  SWAP_ShowOsd(kind, device.name, volume, device.iconKey)
  SWAP_RefreshTray()
}

; ── On-demand device refresh ──────────────────────────────────────
; Windows may change the default outside SoundSwap, especially when RDP creates Remote Audio.
; Adopt the active Windows default when a user invokes SoundSwap, without switching devices.
SWAP_SyncDefaultState() {
  global SWAP_Config
  changed := false
  for kind in ["Output", "Input"] {
    lastId := (kind = "Output") ? SWAP_Config["LastOutputId"] : SWAP_Config["LastInputId"]
    defaultId := SWAP_GetDefaultDeviceId(kind)
    if (defaultId != "" && defaultId != lastId) {
      for dev in SWAP_EnumDevices(kind) {
        if (dev.id = defaultId) {
          SWAP_Config[(kind = "Output") ? "LastOutputId" : "LastInputId"] := defaultId
          changed := true
          break
        }
      }
    }
  }
  if changed
    SWAP_SaveConfig(SWAP_Config)
}

SWAP_OnTrayClick(wParam, lParam, *) {
  global SWAP_IsStandalone
  ; WM_RBUTTONUP, or WM_CONTEXTMENU with newer notification-icon behavior.
  event := lParam & 0xFFFF
  if (event != 0x205 && event != 0x7B)
    return
  SWAP_SyncDefaultState()
  if SWAP_IsStandalone
    SWAP_BuildStandaloneTray()
  else
    SWAP_RefreshTray()
}

; ── Tray integration ─────────────────────────────────────────────
; Called from traymenu.ahk's BuildTrayMenu() (repurposed "Custom Tools" -> "Plugins" submenu,
; per task-17 design session). Builds Input/Output submenus with checkmarks + Configure entry.
; Because BuildTrayMenu() does a full A_TrayMenu.Delete()+rebuild, this must be called on every
; rebuild (hotkey switch or tray invocation) rather than patching a live Menu in place.
SWAP_BuildDeviceMenu(parentMenu) {
  global SWAP_Config
  soundswapMenu := Menu()

  for kind in ["Output", "Input"] {
    kindMenu := Menu()
    devices := SWAP_EnumDevices(kind)
    lastId := (kind = "Output") ? SWAP_Config["LastOutputId"] : SWAP_Config["LastInputId"]

    if !devices.Length {
      kindMenu.Add("(No devices)", (*) => "")
      kindMenu.Disable("(No devices)")
    } else {
      for dev in devices {
        label := dev.name
        kindMenu.Add(label, SWAP_MakeSwitchHandler(kind, dev))
        if (dev.id = lastId)
          kindMenu.Check(label)
      }
    }
    soundswapMenu.Add(kind, kindMenu)
  }

  soundswapMenu.Add()
  soundswapMenu.Add("Configure Filtered Devices...", (*) => SWAP_OpenConfigWindowFromTray())

  parentMenu.Add("SoundSwap", soundswapMenu)
}

SWAP_MakeSwitchHandler(kind, dev) {
  return (*) => SWAP_SwitchTo(kind, dev)
}

SWAP_RefreshTray() {
  ; traymenu.ahk's BuildTrayMenu() does a full rebuild; if it's loaded (i.e. we're #Include'd
  ; into Mello-Workspace), re-trigger it so the checkmarks reflect the new active device.
  if IsSet(BuildTrayMenu)
    BuildTrayMenu()
}

; Read-only snapshot for the About dialog's Plugins tab (dlg-help.ahk) — kept separate from
; SWAP_OpenConfigWindowFromTray's state shape since the About tab has its own controls/layout.
SWAP_GetAboutState() {
  global SWAP_Config
  return {
    enabled: SWAP_Config["Enabled"],
    hotkeyOutput: SWAP_Config["HotkeyOutput"],
    hotkeyInput: SWAP_Config["HotkeyInput"],
    outputDevices: SWAP_EnumDevices("Output"),
    inputDevices: SWAP_EnumDevices("Input"),
    lastOutputId: SWAP_Config["LastOutputId"],
    lastInputId: SWAP_Config["LastInputId"]
  }
}

SWAP_OpenConfigWindowFromTray() {
  global SWAP_Config
  outEligible := Map()
  for dev in SWAP_EligibleDevices("Output")
    outEligible[dev.id] := true

  inEligible := Map()
  for dev in SWAP_EligibleDevices("Input")
    inEligible[dev.id] := true

  state := {
    outputDevices: SWAP_EnumDevices("Output"),
    inputDevices: SWAP_EnumDevices("Input"),
    outputMode: SWAP_Config["OutputMode"],
    inputMode: SWAP_Config["InputMode"],
    outputAllowed: outEligible,
    inputAllowed: inEligible,
    hotkeyOutput: SWAP_Config["HotkeyOutput"],
    hotkeyInput: SWAP_Config["HotkeyInput"]
  }
  SWAP_OpenConfigWindow(state, SWAP_OnConfigSaved)
}

SWAP_ToSet(arr) {
  s := Map()
  for id in arr
    s[id] := true
  return s
}

; Checked items always represent devices the user wants in the rotation ("check to include in rotation").
; If Mode is Allow: stored List = checked devices.
; If Mode is Block: stored List = unchecked devices (the ones to exclude).
SWAP_OnConfigSaved(result) {
  global SWAP_Config
  if (SWAP_Config["OutputMode"] = "Allow") {
    SWAP_Config["OutputList"] := result.outputChecked
  } else {
    blocked := []
    checkedSet := SWAP_ToSet(result.outputChecked)
    for dev in SWAP_EnumDevices("Output") {
      if !checkedSet.Has(dev.id)
        blocked.Push(dev.id)
    }
    SWAP_Config["OutputList"] := blocked
  }

  if (SWAP_Config["InputMode"] = "Allow") {
    SWAP_Config["InputList"] := result.inputChecked
  } else {
    blocked := []
    checkedSet := SWAP_ToSet(result.inputChecked)
    for dev in SWAP_EnumDevices("Input") {
      if !checkedSet.Has(dev.id)
        blocked.Push(dev.id)
    }
    SWAP_Config["InputList"] := blocked
  }
  if (result.hotkeyOutput != SWAP_Config["HotkeyOutput"]) || (result.hotkeyInput != SWAP_Config["HotkeyInput"])
    SWAP_ReregisterHotkeys(result.hotkeyOutput, result.hotkeyInput)
  SWAP_SaveConfig(SWAP_Config)
  SWAP_RefreshTray()
}

; ── Standalone tray (Q8) ──────────────────────────────────────────
; Minimal tray icon/menu — only built when running standalone, never when #Include'd (Mello-
; Workspace's own BuildTrayMenu() owns the tray in that case; see TASK-21 for QuickNoteMD parity).
SWAP_BuildStandaloneTray() {
  A_TrayMenu.Delete()
  SWAP_BuildDeviceMenu(A_TrayMenu)
  A_TrayMenu.Add()
  A_TrayMenu.Add("Exit", (*) => ExitApp())
  A_TrayMenu.Default := "Configure Filtered Devices..."
  iconPath := A_ScriptDir "\plugins\SoundSwap\assets\sound.ico"
  if FileExist(iconPath)
    TraySetIcon(iconPath)
}
