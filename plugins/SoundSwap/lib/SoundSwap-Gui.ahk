#Requires AutoHotkey v2.0

; ╭──────────────────────────────────────────────────────────────╮
; │ SoundSwap-Gui.ahk — OSD + standalone config window            │
; │ OSD mirrors ModalMsg's singleton/dark-styled shape (see        │
; │ lib/apps-hk.ahk) per ADR — not a reuse of that function, since │
; │ ModalMsg is hardcoded to the per-app hotkey-help use case.     │
; ╰──────────────────────────────────────────────────────────────╯

; Shows a brief OSD confirming the active device after a cycle. Auto-dismisses on a timer.
; Theme read once per popup via AppsUseLightTheme() (Mello-Workspace.ahk) — not a live watcher.
SWAP_ShowOsd(kind, deviceName, volumeScalar, iconKey) {
  static guiOsd := ""

  if IsObject(guiOsd) {
    try guiOsd.Destroy()
  }

  isLight := false
  try isLight := !!AppsUseLightTheme()
  bg := isLight ? "ffffff" : "232a2f"
  fg := isLight ? "1a2023" : "f3f3f3"
  subFg := isLight ? "555555" : "9e9e9e"

  guiOsd := Gui("+AlwaysOnTop -Caption +ToolWindow", "SoundSwap OSD")
  guiOsd.BackColor := bg

  iconPath := A_ScriptDir "\plugins\SoundSwap\assets\sound.ico"
  hasIcon := FileExist(iconPath)
  if hasIcon
    guiOsd.Add("Picture", "x24 y20 w32 h32", iconPath)

  textX := hasIcon ? 72 : 24
  textW := 320

  guiOsd.SetFont("s10 norm c" . subFg, "Segoe UI Variable")
  guiOsd.Add("Text", "x" textX " y14 w" textW, kind . " Device Switched")

  guiOsd.SetFont("s12 bold c" . fg, "Segoe UI Variable")
  guiOsd.Add("Text", "x" textX " y34 w" textW, deviceName)

  guiOsd.SetFont("s10 norm c" . subFg, "Segoe UI Variable")
  volPct := Round(volumeScalar * 100)
  guiOsd.Add("Text", "x" textX " y56 w" textW, "Volume: " . volPct . "%")

  totalW := textX + textW + 24
  totalH := 86

  guiOsd.Show("w" totalW " h" totalH " Center")
  guiOsd.GetClientPos(,, &w, &h)
  try WinSetRegion("0-0 w" . w . " h" . h . " r16-16", guiOsd.Hwnd)

  guiOsd.OnEvent("Click", (*) => (IsObject(guiOsd) ? guiOsd.Destroy() : ""))
  SetTimer(() => (IsObject(guiOsd) ? guiOsd.Destroy() : ""), -2200)
}

; Shows a one-shot low-noise OSD when no devices/Audiosrv is down — separate from the per-switch
; OSD above since this is a status notice, not a switch confirmation (ADR / Q5).
SWAP_ShowStatusOsd(message) {
  static guiStatus := ""
  if IsObject(guiStatus) {
    try guiStatus.Destroy()
  }
  isLight := false
  try isLight := !!AppsUseLightTheme()
  bg := isLight ? "ffffff" : "232a2f"
  fg := isLight ? "1a2023" : "f3f3f3"

  guiStatus := Gui("+AlwaysOnTop -Caption +ToolWindow", "SoundSwap Status")
  guiStatus.BackColor := bg

  iconPath := A_ScriptDir "\plugins\SoundSwap\assets\sound.ico"
  hasIcon := FileExist(iconPath)
  if hasIcon
    guiStatus.Add("Picture", "x20 y18 w24 h24", iconPath)

  textX := hasIcon ? 56 : 20
  guiStatus.SetFont("s11 norm c" . fg, "Segoe UI Variable")
  guiStatus.Add("Text", "x" textX " y20 w320", message)

  totalW := textX + 340
  guiStatus.Show("w" totalW " h60 Center")
  guiStatus.GetClientPos(,, &w, &h)
  try WinSetRegion("0-0 w" . w . " h" . h . " r16-16", guiStatus.Hwnd)
  guiStatus.OnEvent("Click", (*) => (IsObject(guiStatus) ? guiStatus.Destroy() : ""))
  SetTimer(() => (IsObject(guiStatus) ? guiStatus.Destroy() : ""), -2200)
}

; Standalone config window: two ListViews (Output / Input), each with an allow/block checkbox
; column, plus hotkey rebind fields. Singleton — reopening focuses the existing window (Q3/Q9).
SWAP_OpenConfigWindow(state, onSave) {
  static guiConfig := ""
  if IsObject(guiConfig) {
    try {
      guiConfig.Show()
      WinActivate(guiConfig.Hwnd)
      return
    }
  }

  guiConfig := Gui("+Resize", "SoundSwap — Configure Filtered Devices")
  guiConfig.SetFont("s10", "Segoe UI")

  guiConfig.AddText("x16 y12", "Output devices — check to include in rotation (Mode: " . state.outputMode . ")")
  lvOutput := guiConfig.AddListView("x16 y32 w400 h180 Checked", ["Device"])
  for dev in state.outputDevices {
    row := lvOutput.Add(state.outputAllowed.Has(dev.id) ? "Check" : "", dev.name)
  }
  lvOutput.ModifyCol(1, 380)

  guiConfig.AddText("x16 y224", "Input devices — check to include in rotation (Mode: " . state.inputMode . ")")
  lvInput := guiConfig.AddListView("x16 y244 w400 h180 Checked", ["Device"])
  for dev in state.inputDevices {
    row := lvInput.Add(state.inputAllowed.Has(dev.id) ? "Check" : "", dev.name)
  }
  lvInput.ModifyCol(1, 380)

  guiConfig.AddText("x436 y32", "Output hotkey:")
  editOutputHotkey := guiConfig.AddEdit("x436 y52 w140", state.hotkeyOutput)
  guiConfig.AddText("x436 y92", "Input hotkey:")
  editInputHotkey := guiConfig.AddEdit("x436 y112 w140", state.hotkeyInput)
  guiConfig.AddText("x436 y152 w150", "Combos like ^!F12. Applies without a reload.")

  btnSave := guiConfig.AddButton("x436 y440 w140 h30", "Save")
  btnSave.OnEvent("Click", (*) => (
    onSave({
      outputChecked: SWAP_CollectChecked(lvOutput, state.outputDevices),
      inputChecked: SWAP_CollectChecked(lvInput, state.inputDevices),
      hotkeyOutput: editOutputHotkey.Text,
      hotkeyInput: editInputHotkey.Text
    }),
    guiConfig.Destroy(),
    guiConfig := ""
  ))

  guiConfig.OnEvent("Close", (*) => (guiConfig := ""))
  guiConfig.Show("w600 h480")
}

SWAP_CollectChecked(lv, devices) {
  checked := []
  row := 0
  while (row := lv.GetNext(row, "Checked"))
    checked.Push(devices[row].id)
  return checked
}
