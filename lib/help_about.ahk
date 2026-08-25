#Requires Autohotkey v2.0
; ╭════════════════════════════════════════════════════════════════════════════════════════════════════════════════─╮
; ║  _HELP_ABOUT.AHK                                                                                                ║
; ╰═════════════════════════════════════════════════════════════════════════════════════════════════════════════════╯

; ╭────────────────────────╮
; │ GLOBAL SCOPE VARIABLES │
; ╰────────────────────────╯
global aboutDlg := ""
global dlgWidth := 890
global dlgHeight := 560
global guiFont := "Segoe UI Variable"
global cpuText := ""

class ThisPC {
  static CPUInfo := Map()
  static RAM := ""
  static OS := Map()
  static Motherboard := Map()
  static Network := []
  static ExternalIP := ""
  static Battery := Map()
  static Uptime := ""

  static CollectInfo() {
    ThisPC.CPUInfo := ThisPC.CPUInfoClass()
    ThisPC.RAM := ThisPC.GetRAMInfo()
    ThisPC.OS := ThisPC.GetOSInfo()
    ThisPC.Motherboard := ThisPC.GetMotherboardInfo()
    ThisPC.Network := ThisPC.GetNetworkInfo()
    ThisPC.ExternalIP := ThisPC.GetExternalIP()
    ThisPC.Battery := ThisPC.GetBatteryInfo()
    ThisPC.Uptime := ThisPC.GetUptime()
  }

  class CPUInfoClass {
    Name := ""
    Manufacturer := ""
    Description := ""
    NumberOfCores := ""
    NumberOfLogicalProcessors := ""
    MaxClockSpeed := ""
    Architecture := ""
    ProcessorId := ""

    __New() {
      for cpu in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Processor") {
        this.Name := cpu.Name
        this.Manufacturer := cpu.Manufacturer
        this.Description := cpu.Description
        this.NumberOfCores := cpu.NumberOfCores
        this.NumberOfLogicalProcessors := cpu.NumberOfLogicalProcessors
        this.MaxClockSpeed := cpu.MaxClockSpeed
        this.Architecture := cpu.Architecture
        this.ProcessorId := cpu.ProcessorId
        break
      }
    }
  }

  static GetRAMInfo() {
    total := 0
    for mem in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_PhysicalMemory")
      total += mem.Capacity
    return Round(total / (1024 ** 3), 2) ; GiB
  }

  static GetOSInfo() {
    for os in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_OperatingSystem") {
      ; Convert install date from WMI format
      installDate := os.InstallDate
      if installDate
        installDate := SubStr(installDate, 1, 4) "-" SubStr(installDate, 5, 2) "-" SubStr(installDate, 7, 2) " " SubStr(installDate, 9, 2) ":" SubStr(installDate, 11, 2)
      return Map(
        "Name", os.Caption,
        "Version", os.Version,
        "BuildNumber", os.BuildNumber,
        "Architecture", os.OSArchitecture,
        "InstallDate", installDate
      )
    }
    return Map()
  }

  static GetMotherboardInfo() {
    for board in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_BaseBoard") {
      return Map(
        "Manufacturer", board.Manufacturer,
        "Product", board.Product,
        "SerialNumber", board.SerialNumber
      )
    }
    return Map()
  }

  static GetNetworkInfo() {
    info := []
    for nic in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_NetworkAdapterConfiguration WHERE IPEnabled=TRUE") {
      info.Push(Map(
        "Description", nic.Description,
        "MACAddress", nic.MACAddress,
        "IPAddress", nic.IPAddress ? nic.IPAddress[0] : "",
        "Gateway", nic.DefaultIPGateway ? nic.DefaultIPGateway[0] : ""
      ))
    }
    return info
  }

  static GetExternalIP() {
    try {
      whr := ComObject("WinHttp.WinHttpRequest.5.1")
      whr.SetTimeouts(2000, 2000, 2000, 2000)
      whr.Open("GET", "https://api.ipify.org/", true)
      whr.Send()
      whr.WaitForResponse(2)
      return whr.ResponseText
    } catch {
      return "Unavailable"
    }
  }

  static GetBatteryInfo() {
    for bat in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Battery") {
      return Map(
        "Status", bat.BatteryStatus,
        "EstimatedChargeRemaining", bat.EstimatedChargeRemaining,
        "EstimatedRunTime", bat.EstimatedRunTime
      )
    }
    return Map()
  }

  static GetUptime() {
    for os in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_OperatingSystem") {
      lastBoot := os.LastBootUpTime
      if lastBoot {
        ; Parse WMI datetime: yyyymmddHHMMSS.xxxxxx±UUU
        yyyy := SubStr(lastBoot, 1, 4)
        MM := SubStr(lastBoot, 5, 2)
        dd := SubStr(lastBoot, 7, 2)
        hh := SubStr(lastBoot, 9, 2)
        mi := SubStr(lastBoot, 11, 2)
        ss := SubStr(lastBoot, 13, 2)
        lastBootTime := yyyy . MM . dd . hh . mi . ss
        ; Calculate seconds since last boot
        uptimeSec := DateDiff(A_Now, lastBootTime, "Seconds")
        days := Floor(uptimeSec / 86400)
        hours := Floor(Mod(uptimeSec, 86400) / 3600)
        mins := Floor(Mod(uptimeSec, 3600) / 60)
        return days "d " hours "h " mins "m"
      }
    }
    return "Unavailable"
  }
}

ShowHelpAbout(*) {
  global aboutDlg
  ; If dialog exists and is visible, bring it to front and return
  try {
    ; aboutDlg.Show("w" dlgWidth " h" dlgHeight)
    aboutDlg.Restore()
    aboutDlg.Show() ; Ensure it is brought to focus
    return
  } catch Any {
    ; If dialog does not exist, create it
    aboutDlg := ConstructAboutDialog()

    ; Win32 API Winodw DarkMode
    DllCall("dwmapi\DwmSetWindowAttribute"
      , "ptr", aboutDlg.Hwnd, "int", 20, "int*", 1, "UInt", 4)
    ; aboutDlg.Show("w" dlgWidth " h" dlgHeight)
    aboutDlg.Show()
  }

  aboutDlg.OnEvent("Escape", (*) => aboutDlg.Destroy())
  aboutDlg.OnEvent("Close", (*) => aboutDlg.Destroy())
  ; aboutDlg.OnEvent("Size", (dlg, *) => (
  ;   mainTab.Move("w" . (dlg.ClientPos.W - 16) . " h" . (dlg.ClientPos.H - 80)),
  ;   aboutDlg["StatusBar"].Move("w" . dlg.ClientPos.W)
  ; ))

  ; Prevent attempts handle the "Size" event to ignore resizing from WinMove
  aboutDlg.OnEvent("Size", (*) => aboutDlg.Show("w" dlgWidth " h" dlgHeight))
}

ConstructAboutDialog(*) {
  isInfoLoaded := false
  isInfoLoaded := false
  ; Detect the active private working memory usage of this process
  pid := DllCall("GetCurrentProcessId")
  ; Open process with query info rights
  hProcess := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
  if hProcess {
    ; PROCESS_MEMORY_COUNTERS structure is 72 bytes on 64-bit, 40 bytes on 32-bit
    structSize := (A_PtrSize = 8) ? 72 : 40

    ; PROCESS_MEMORY_COUNTERS := Buffer(structSize, 0)
    ; NumPut("UInt", structSize, PROCESS_MEMORY_COUNTERS, 0)
    ; if DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", PROCESS_MEMORY_COUNTERS.Ptr, "UInt", structSize) {
    ;   Offsets for PROCESS_MEMORY_COUNTERS (see MSDN)
    ;   cnt := ""
    ;   cnt .= "PageFaultCount: " NumGet(PROCESS_MEMORY_COUNTERS, 4, "UInt") "`n"
    ;   cnt .= "PeakWorkingSetSize: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "WorkingSetSize: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "QuotaPeakPagedPoolUsage: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + 2*A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "QuotaPagedPoolUsage: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + 3*A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "QuotaPeakNonPagedPoolUsage: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + 4*A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "QuotaNonPagedPoolUsage: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + 5*A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "PagefileUsage: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + 6*A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB`n"
    ;   cnt .= "PeakPagefileUsage: " Round(NumGet(PROCESS_MEMORY_COUNTERS, 8 + 7*A_PtrSize, (A_PtrSize=8)?"UInt64":"UInt") / 1024, 2) " MB"
    ;   MsgBox(cnt, "Process Memory Counters (MB)")
    ; }

    ; Get the active private working set and calculate in MB
    PROCESS_MEMORY_COUNTERS := Buffer(structSize, 0)
    NumPut("UInt", structSize, PROCESS_MEMORY_COUNTERS, 0)
    if DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", PROCESS_MEMORY_COUNTERS.Ptr, "UInt", structSize) {
      ; WorkingSetSize: offset 16 on 64-bit (after cb=4, PageFaultCount=4, PeakWorkingSetSize=8)
      ;                 offset 12 on 32-bit (after cb=4, PageFaultCount=4, PeakWorkingSetSize=4)
      wsOffset := (A_PtrSize = 8) ? 16 : 12
      wsType   := (A_PtrSize = 8) ? "UInt64" : "UInt"
      workingSetSize := NumGet(PROCESS_MEMORY_COUNTERS, wsOffset, wsType)
      memMB := Round(workingSetSize / (1024 * 1024), 1)
    } else {
      memMB := "??"
    }
    DllCall("CloseHandle", "Ptr", hProcess)
  } else {
    memMB := "?"
  }

  ; Calculate Uptime
  __Uptime := A_TickCount - __StartTime
  __days := Floor(__Uptime / 86400000)
  __hours := Floor(Mod(__Uptime, 86400000) / 3600000)
  __minutes := Floor(Mod(__Uptime, 3600000) / 60000)
  __seconds := Floor(Mod(__Uptime, 60000) / 1000)
  UptimeString := __days " Days " __hours " Hrs " __minutes " Mins " __seconds " Secs"

  ; Dialog Construction
  aboutDlg := Gui()
  aboutDlg.SetFont("q5 s11", guiFont)
  aboutDlg.Opt("-MinimizeBox -MaximizeBox") ; +AlwaysOnTop")

  ; First Line with link to docs
  aboutDlg.Add("Link", "x9 y12 h23",
    "All items below are frequently used features. Visit the <a href=`"https://github.com/voltaire-toledo/Mello-Workspace/tree/main/docs`">Official Documentation</a> for a more comprehensive list."
  )

  ; Status Bar
  aboutDlg.Add("StatusBar", "x0 y540 w880 h30 vStatusBar", "  Hit the [Esc] key to close this window.")

  ; Tab Control
  aboutDlg.SetFont("q5 s10", guiFont)
  mainTab := aboutDlg.Add("Tab3", "x8 y42 w878 h520",
    ["About",
      "Hotkeys  ",
      "Hotstrings  ",
      "Window Management  ",
      "Arpeggios  ",
      "App Controls  ",
      "Other Options ",
      "Other Info"])
  ; mainTab.OnEvent("Change",

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 1 - About                                                                         │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(1)
  ; Logo and Title, version number, and license
  aboutDlg.Add("Picture", "x16 y76 w92 h92", A_ScriptDir "\media\images\mello-keycap.png")
  ; aboutDlg.SetFont("c3e3d32", guiFont)
  aboutDlg.SetFont("c039314 Bold s21", guiFont)
  ; aboutDlg.Add("Text", "x72 y74 w470", "Mello-Workspace")
  aboutDlg.Add("Text", "x+m yp w470", "Mello-Workspace")

  ; Tagline
  aboutDlg.SetFont("Bold Italic s14", guiFont)
  aboutDlg.Add("Text", "xp y+m-4 w400 h23 ", "Chill. Flow. Repeat.")

  ; Version and License
  ; aboutDlg.Add("Text", "xp-30 yp+20 w600 h23", "Margin: " aboutDlg.MarginX " px, " aboutDlg.MarginY " px")
  aboutDlg.SetFont("c353881 q5 s10", guiFont)
  aboutDlg.Add("Text", "xp yp+25 w300", "Version: " thisapp_version)
  aboutDlg.Add("Text", "yp w300", "Working Set (RAM): " memMB " MB")
  aboutDlg.Add("Text", "xp-308 yp+20 w300", "Licensed under the GPLv2 License")
  aboutDlg.Add("Text", "yp w300", "Uptime: " UptimeString)
  
  ; Recent Update Note
  aboutDlg.SetFont("c0066cc Bold Italic q5 s9", guiFont)
  aboutDlg.Add("Text", "xp-308 yp+25 w600", "✓ Tray menu fixed: Now uses Menu().Show() instead of Gui+MenuBar (correct AutoHotkey v2 pattern)")

  ; Credit Section and Links to other resources
  aboutDlg.SetFont("c039314 Bold q5 s11", guiFont)
  aboutDlg.Add("Text", "x72 y400 w600 h23", "Credits and Resources")  ; Fixed location
  aboutDlg.SetFont("c000000 Norm q5 s10", guiFont)
  aboutDlg.Add("Picture", "x72 y+0 w16 h16", A_AhkPath,)
  aboutDlg.Add("Link", "yp w400 h23",
    "AutoHotkey (version " A_AhkVersion ") is available at <a href=`"https://www.autohotkey.com`">autohotkey.com</a>")

  aboutDlg.Add("Picture", "x70 yp+20 w20 h20", A_ScriptDir "\media\icons\icons8.ico")
  aboutDlg.Add("Link", "yp w600 h23", "Icons by <a href=`"https://icons8.com`">icons8.com</a>")

  aboutDlg.Add("Picture", "x70 yp+20 w20 h20", A_ScriptDir "\media\icons\icons8-github-windows-10-16.png")
  ; aboutDlg.Add("Link", "yp w600 h23",
  ;   "<a href=`"https://www.autohotkey.com/boards/viewtopic.php?f=83&t=94044`">WiseGUI.ahk library</a> by <a href=`"https://www.autohotkey.com/boards/memberlist.php?mode=viewprofile&u=54&sid=f3bac845536fc1eace03994a9e73273e`">SKAN</a>")

  aboutDlg.Add("Picture", "x70 yp+20 w20 h20", A_ScriptDir "\media\icons\icons8-github-windows-10-16.png")
  aboutDlg.Add("Link", "yp w300 h23",
    "<a href=`"https://github.com/FuPeiJiang/VD.ahk/tree/v2_port`">VD.ahk library</a> by <a href=`"https://github.com/FuPeiJiang`">FuPeiJiang</a>")
  ; aboutDlg.Add("Link", "x72 y270 w300 h23",
  ; "<a href=`"https://github.com/Ciantic/VirtualDesktopAccessor`">VirtualDesktopAccessor</a> by <a href=`"https://github.com/Ciantic`">Ciantic</a>")

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 2 - Hotkeys                                                                       │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(2)
  aboutDlg.SetFont("Bold s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w835 h23", "Hotkeys = keyboard shortcuts. Go ahead and try them out!")

  ; Add ListView for Hotkeys
  aboutDlg.SetFont("Norm q5 s10", guiFont)
  lv_corehkeys := aboutDlg.Add("ListView", "x16 y100 w862 r19", ["Action", "Hotkey", "Description"])
  lv_corehkeys.Opt("+Report") ; +Sort")

  ; Example hotkeys - replace/add as needed for your project
  lv_corehkeys.Opt("+Report") ; +Sort")
  lv_corehkeys.Opt("-Redraw")
  lv_corehkeys.Add(, "Reload and Restart " thisapp_name, "[Ctrl][Alt][Win]R ", "Reload and restart " thisapp_name)
  lv_corehkeys.Add(, "AutoHotkey Help", "[Ctrl] [Alt][Win]F2", "Open the AutoHotkey help docs")
  lv_corehkeys.Add(, "Sleep", "[Ctrl] [Alt][Win]F12", "Put this system to sleep")
  lv_corehkeys.Add(, thisapp_name " Help", "[Ctrl] [Alt][Win]F1", "Display this dialog")
  lv_corehkeys.Add(, "Open the user's folder", "⊞ F", "Open the user's Documents folder in File Explorer")
  lv_corehkeys.Add(, "Edit this script", "[Ctrl] [Alt][Win]E", "Open the main " thisapp_name " script (default editor)")
  ; lv_corehkeys.Add(, "Open the " thisapp_name " folder", "[Ctrl] [Alt][Win]F", "Open the " thisapp_name " folder in File Explorer")
  lv_corehkeys.Add(, "Windows Terminal", "[Ctrl] [Alt] T", "Open or focus the Windows Terminal window")
  lv_corehkeys.Add(, "Windows Terminal (Elevated)", "[Ctrl] [Shift] [Alt] T", "Open an elevated Windows Terminal instance")
  lv_corehkeys.Add(, "Open Calculator", "2 × [Right_Alt/⌥]", "Open or focus the Calculator app")
  lv_corehkeys.Add(, "Increase Mouse Pointer Size", "[Ctrl] [Alt] [Win]", "Incrase the mouse cursor size (Settings > Accessibility)")
  lv_corehkeys.Add(, "Decrease Mouse Pointer Size", "[Ctrl] [Alt][Win][", "Decrease  the mouse cursor size (Settings > Accessibility)")
  lv_corehkeys.Add(, "Home", "[RCtrl] ←", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.Add(, "End", "[RCtrl] →", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.Add(, "PgUp", "[RCtrl] ↑", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.Add(, "PgDn", "[RCtrl] ↓", "[Right_Alt/⌥] supported inside an RDP connection.")
  ; lv_corehkeys.Add(, "Set current window to 70%", "[Ctrl] [Alt][Win]/","")
  ; lv_corehkeys.Add(, "Shrink current window", "[Ctrl] [Alt][Win]<", "5% smaller")
  ; lv_corehkeys.Add(, "Expand current window", "[Ctrl] [Alt][Win]>", "5% larger")
  ; lv_corehkeys.Add(, "Extend current window's top border", "[Ctrl] [Alt] I", "Extend windo to the top of the screen")
  ; lv_corehkeys.Add(, "Extend current window's bottom border", "[Ctrl] [Alt] K", "Extend windo to the bottom of the screen")
  ; lv_corehkeys.Add(, "Extend current window's left border", "[Ctrl] [Alt] J", "Extend windo to the left of the screen")
  ; lv_corehkeys.Add(, "Extend current window's right border", "[Ctrl] [Alt] L", "Extend windo to the right of the screen")
  ; lv_corehkeys.Add(, "Move current window up", "[Ctrl] [Alt][Win]I", "Move window up by 10%")
  ; lv_corehkeys.Add(, "Move current window down", "[Ctrl] [Alt][Win]K", "Move window down by 10%")
  ; lv_corehkeys.Add(, "Move current window left", "[Ctrl] [Alt][Win]J", "Move window left by 10%")
  ; lv_corehkeys.Add(, "Move current window right", "[Ctrl] [Alt][Win]L", "Move window right by 10%")
  lv_corehkeys.ModifyCol() ; Auto-size the first column
  lv_corehkeys.ModifyCol(2) ; Auto-size the second column
  lv_corehkeys.ModifyCol(3)
  lv_corehkeys.Opt("+Redraw")
  lv_corehkeys.Visible := True

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 3 - Hotstrings                                                                    │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(3)
  aboutDlg.SetFont("c000000 Bold q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w835 h54", "Hotstrings = string replacements.")
  aboutDlg.SetFont("c000000 Norm q5 s11", guiFont)

  ; --- Radio Buttons and Dynamic ListViews ---
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y100 w862 h50", "Hotstring Groups")

  aboutDlg.SetFont("Norm s10", guiFont)
  hs_rb_ansi := aboutDlg.Add("Radio", "x32 y120 w90 h23 vhs_rb_ansi", "ANSI")
  hs_rb_kaomoji := aboutDlg.Add("Radio", "x120 y120 w90 h23 vhs_rb_kaomoji", "Kaomoji")
  hs_rb_emoji := aboutDlg.Add("Radio", "x220 y120 w90 h23 vhs_rb_emoji", "Emojis")
  hs_rb_boxes := aboutDlg.Add("Radio", "x320 y120 w130 h23 vhs_rb_boxes", "ASCII P-Graphics")
  hs_rb_custom := aboutDlg.Add("Radio", "x500 y120 w90 h23 vhs_rb_custom", "Custom")

  hs_rb_ansi.Value := true ; Default selection
  aboutDlg.SetFont("c000000 Norm q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y155 w862 h54 vhs_rb_text", "Hotstrings include optional expansions and modifiers for advanced use.")

  ; ANSI/ASCII Alt Codes
  aboutDlg.SetFont("Norm q5 s10", guiFont)
  hs_lv_ansi := aboutDlg.Add("ListView", "x16 y185 w862 r15 vhs_lv_ansi", ["Hotstring", "Replacement", "Comments"])
  hs_lv_ansi.Opt("+Report")
  hs_lv_ansi.Opt("-Redraw")
  hs_lv_ansi.Add(, "`:arrowdown", "↓", "ANSI 25")
  hs_lv_ansi.Add(, "`:arrowleft", "←", "ANSI 27")
  hs_lv_ansi.Add(, "`:arrowright", "→", "ANSI 26")
  hs_lv_ansi.Add(, "`:arrowup", "↑", "ANSI 24")
  hs_lv_ansi.Add(, "`:backspace", "⌫", "")
  hs_lv_ansi.Add(, "`:bullet", "•", "ANSI 7")
  hs_lv_ansi.Add(, "`:copyright", "©", "ANSI 0169")
  hs_lv_ansi.Add(, "`:delete", "⌦", "")
  hs_lv_ansi.Add(, "`:divide", "÷", "ANSI 0247")
  hs_lv_ansi.Add(, "`:enter", "↵", "")
  hs_lv_ansi.Add(, "`:escape", "⎋", "")
  hs_lv_ansi.Add(, "`:insert", "⎀", "")
  hs_lv_ansi.Add(, "`:keybackspace", "⌫", "")
  hs_lv_ansi.Add(, "`:keycaps", "⇪", "")
  hs_lv_ansi.Add(, "`:keydel", "⌦", "")
  hs_lv_ansi.Add(, "`:keyenter", "↵", "")
  hs_lv_ansi.Add(, "`:keyescape", "⎋", "")
  hs_lv_ansi.Add(, "`:keyins", "⎀", "")
  hs_lv_ansi.Add(, "`:keyshift", "⇧", "")
  hs_lv_ansi.Add(, "`:keytab", "⇥", "")
  hs_lv_ansi.Add(, "`:keyspace", "␣", "")
  hs_lv_ansi.Add(, "`:keywin", "⊞", "")
  hs_lv_ansi.Add(, "`:keyalt", "⌥", "Alt / Option key")
  hs_lv_ansi.Add(, "`:keycmd", "⌘", "Command key")
  hs_lv_ansi.Add(, "`:keyctrl", "∧", "Control key")
  hs_lv_ansi.Add(, "`:keymeta", "✦", "Meta key")
  hs_lv_ansi.Add(, "`:kbdhold", "⭳", "Keyboard Hold")
  hs_lv_ansi.Add(, "`:kbdtap", "⭿", "Keyboard Tap")
  hs_lv_ansi.Add(, "`:kbdrelease", "⭱", "Keyboard Release")
  hs_lv_ansi.Add(, "`:multiply", "×", "ANSI 0215")
  hs_lv_ansi.Add(, "`:registered", "®", "ANSI 0174")
  hs_lv_ansi.Add(, "`:space", "␣", "")
  hs_lv_ansi.Add(, "`:trademark", "™", "ANSI 0153")
  hs_lv_ansi.Add(, "`:tricolon", "⁝", "")
  hs_lv_ansi.Add(, "`:hdots", "⋯", "Horizontal ellipsis")
  hs_lv_ansi.Add(, "`:vdots", "⋮", "Vertical ellipsis")
  hs_lv_ansi.Add(, "`:ddots", "⋱", "Diagonal dots (down-right)")
  hs_lv_ansi.Add(, "`:udots", "⋰", "Diagonal dots (up-right)")
  hs_lv_ansi.ModifyCol()
  hs_lv_ansi.ModifyCol(2, 100)
  hs_lv_ansi.ModifyCol(3)
  hs_lv_ansi.Opt("+Redraw")

  ; Japanese Emoticons (Kaomoji)
  hs_lv_kaomoji := aboutDlg.Add("ListView", "x16 y185 w862 r12 vhs_lv_kaomoji", ["Hotstring", "Replacement", "Comments"])
  hs_lv_kaomoji.Opt("+Report")
  hs_lv_kaomoji.Opt("-Redraw")
  hs_lv_kaomoji.Add(, "`:fuckoff", "୧༼ಠ益ಠ╭∩╮༽", "")
  hs_lv_kaomoji.Add(, "`:fuckyou", "┌П┐(ಠ_ಠ)", "")
  hs_lv_kaomoji.Add(, "`:idk", "¯\(°_o)/¯", "")
  hs_lv_kaomoji.Add(, "`:ohshit", "( º﹃º )", "")
  hs_lv_kaomoji.Add(, "`:shrug", "¯\_(ツ)_/¯", "")
  hs_lv_kaomoji.Add(, "`:tableflip", "(ノಠ益ಠ)ノ彡┻━┻", "")
  hs_lv_kaomoji.ModifyCol(1)
  hs_lv_kaomoji.ModifyCol(2)
  hs_lv_kaomoji.ModifyCol(3, 100)
  hs_lv_kaomoji.Opt("+Redraw")
  hs_lv_kaomoji.Visible := false

  ; Emojis
  hs_lv_emoji := aboutDlg.Add("ListView", "x16 y185 w862 r12 vhs_lv_emoji", ["Hotstring", "Replacement", "Comments"])
  hs_lv_emoji.Opt("+Report")
  hs_lv_emoji.Opt("-Redraw")
  hs_lv_emoji.Add(, "`:blackcircle", "⚫", "Emoji")
  hs_lv_emoji.Add(, "`:bluecircle", "🔵", "Emoji")
  hs_lv_emoji.Add(, "`:bug", "🕷️", "Emoji")
  hs_lv_emoji.Add(, "`:check", "✔️", "Emoji")
  hs_lv_emoji.Add(, "`:checkmark", "✅", "Emoji")
  hs_lv_emoji.Add(, "`:clock", "⏰", "Emoji")
  hs_lv_emoji.Add(, "`:crossmark", "❎", "Emoji")
  hs_lv_emoji.Add(, "`:error", "❗", "Emoji")
  hs_lv_emoji.Add(, "`:file", "📄", "Emoji")
  hs_lv_emoji.Add(, "`:fire", "🔥", "Emoji")
  hs_lv_emoji.Add(, "`:folder", "📁", "Emoji")
  hs_lv_emoji.Add(, "`:folderopen", "📂", "Emoji")
  hs_lv_emoji.Add(, "`:greencircle", "🟢", "Emoji")
  hs_lv_emoji.Add(, "`:heart", "❤️", "Emoji")
  hs_lv_emoji.Add(, "`:home", "🏠", "Emoji")
  hs_lv_emoji.Add(, "`:info", "ℹ️", "Emoji")
  hs_lv_emoji.Add(, "`:lightbulb", "💡", "Emoji")
  hs_lv_emoji.Add(, "`:link", "🔗", "Emoji")
  hs_lv_emoji.Add(, "`:lookup", "🔍", "Emoji")
  hs_lv_emoji.Add(, "`:noob", "🔰", "Emoji")
  hs_lv_emoji.Add(, "`:ok", "👌", "Emoji")
  hs_lv_emoji.Add(, "`:purplecircle", "🟣", "Emoji")
  hs_lv_emoji.Add(, "`:question", "❓", "Emoji")
  hs_lv_emoji.Add(, "`:sarcsmile", "🙃", "Emoji")
  hs_lv_emoji.Add(, "`:search", "🔎", "Emoji")
  hs_lv_emoji.Add(, "`:smile", "😀", "Emoji")
  hs_lv_emoji.Add(, "`:sprout", "🌱", "Emoji")
  hs_lv_emoji.Add(, "`:star", "⭐", "Emoji")
  hs_lv_emoji.Add(, "`:thumbsdown", "👎", "Emoji")
  hs_lv_emoji.Add(, "`:thumbsup", "👍", "Emoji")
  hs_lv_emoji.Add(, "`:wait", "⏳", "Emoji")
  hs_lv_emoji.Add(, "`:warning", "⚠️", "Emoji")
  hs_lv_emoji.Add(, "`:x", "❌", "Emoji")
  hs_lv_emoji.Add(, "`:yellowcircle", "🟡", "Emoji")
  hs_lv_emoji.Add(, "`:zap", "⚡", "Emoji")
  hs_lv_emoji.ModifyCol(1)
  hs_lv_emoji.ModifyCol(2, 100)
  hs_lv_emoji.ModifyCol(3, 100)
  hs_lv_emoji.Opt("+Redraw")
  hs_lv_emoji.Visible := false

  ; ASCII Art / Boxes
  hs_lv_boxes := aboutDlg.Add("ListView", "x16 y185 w862 r12 vhs_lv_boxes", ["Hotstring", "Description", "Comments"])
  hs_lv_boxes.Opt("+Report")
  hs_lv_boxes.Opt("-Redraw")
  hs_lv_boxes.Add(, "##sbox##", "Simple ASCII box  +--+", "")
  hs_lv_boxes.Add(, "##stable##", "Simple ASCII table  +--+--+", "")
  hs_lv_boxes.Add(, "```:box", "Box with light corners  ┌──┐", "")
  hs_lv_boxes.Add(, "```:rbox", "Round-cornered box  ╭──╮", "")
  hs_lv_boxes.Add(, "```:rtable", "Round-cornered table  ╭──┬──╮", "")
  hs_lv_boxes.Add(, "##tbox-thick##", "Thick-bordered box  ╔══╗", "")
  hs_lv_boxes.Add(, "```:insert-row", "Insert divider row above current line", "")
  hs_lv_boxes.Add(, "```:b|", "│", "Vertical line")
  hs_lv_boxes.Add(, "```:b-", "─", "Horizontal line")
  hs_lv_boxes.Add(, "```:b<", "├", "Branch right")
  hs_lv_boxes.Add(, "```:b<-", "├──", "Branch + run")
  hs_lv_boxes.Add(, "```:b\", "└", "End corner")
  hs_lv_boxes.Add(, "```:b\-", "└──", "End + run")
  hs_lv_boxes.Add(, "```:b+", "┼", "Cross")
  hs_lv_boxes.Add(, "```:b^", "┬", "T down")
  hs_lv_boxes.Add(, "```:bv", "┴", "T up")
  hs_lv_boxes.Add(, "```:b>", "┤", "Branch left")
  hs_lv_boxes.Add(, "```:br", "┌", "Corner top-left")
  hs_lv_boxes.Add(, "```:b7", "┐", "Corner top-right")
  hs_lv_boxes.Add(, "```:bL", "└", "Corner bottom-left")
  hs_lv_boxes.Add(, "```:bJ", "┘", "Corner bottom-right")
  hs_lv_boxes.Add(, "```:b<d", "├──📁", "Branch dir")
  hs_lv_boxes.Add(, "```:b<f", "├──📄", "Branch file")
  hs_lv_boxes.Add(, "```:b\d", "└──📁", "End dir")
  hs_lv_boxes.Add(, "```:b\f", "└──📄", "End file")
  hs_lv_boxes.ModifyCol(1)
  hs_lv_boxes.ModifyCol(2)
  hs_lv_boxes.ModifyCol(3, 100)
  hs_lv_boxes.Opt("+Redraw")
  hs_lv_boxes.Visible := false

  ; Locate the user's custom hotstrings file
  customHsPath := ""
  customHsCandidates := [
      A_ScriptDir "\custom\.mslrc.ahk",
      A_ScriptDir "\.mslrc.ahk",
      A_AppData "\.mslrc.ahk"
  ]
  for p in customHsCandidates {
      if FileExist(p) {
          customHsPath := p
          break
      }
  }

  hs_lv_custom := aboutDlg.Add("ListView", "x16 y185 w862 r12 vhs_lv_custom", ["Hotstring", "Replacement"])
  hs_lv_custom.Opt("+Report")
  hs_lv_custom.Opt("-Redraw")
  if customHsPath {
      content := FileRead(customHsPath)
      pos := 1
      while pos := RegExMatch(content, "m)^:(?:[^:]*):([^:`n]+)::(.*)$", &m, pos) {
          trigger := Trim(m[1])
          replacement := Trim(m[2])
          if trigger != "" && !RegExMatch(replacement, "^\s*\{")
              hs_lv_custom.Add(, trigger, replacement)
          pos += Max(1, m.Len)
      }
      if hs_lv_custom.GetCount() = 0
          hs_lv_custom.Add(, "(no hotstrings found in file)", "")
  } else {
      hs_lv_custom.Add(, "(file not found)", "Expected: " customHsCandidates[1])
  }
  hs_lv_custom.ModifyCol(1)
  hs_lv_custom.ModifyCol(2)
  hs_lv_custom.Opt("+Redraw")
  hs_lv_custom.Visible := false

  ; Handler to switch ListViews
  hs_switchListView(*) {
    hs_lv_ansi.Visible := hs_rb_ansi.Value
    hs_lv_kaomoji.Visible := hs_rb_kaomoji.Value
    hs_lv_boxes.Visible := hs_rb_boxes.Value
    hs_lv_emoji.Visible := hs_rb_emoji.Value
    hs_lv_custom.Visible := hs_rb_custom.Value
    if (hs_rb_ansi.Value)
      aboutDlg["hs_rb_text"].Value := "ANSI Hotstrings allow you to use special characters and symbols. Here are some examples:"
    else if (hs_rb_custom.Value)
      aboutDlg["hs_rb_text"].Value := customHsPath ? "Custom hotstrings loaded from: " customHsPath : "Custom file not found. Create it at: " customHsCandidates[1]
    else if (hs_rb_kaomoji.Value)
      aboutDlg["hs_rb_text"].Value := "Kaomojis are Japanese emoticons that can be used in text. Here are some examples:"
    else if (hs_rb_boxes.Value)
      aboutDlg["hs_rb_text"].Value := "ASCII pseudographics (also called line/box-drawing characters) are used to create boxes, tables and dirtrees. Best used with monospace fonts with full UTF-8 coverage."
    else if (hs_rb_emoji.Value)
      aboutDlg["hs_rb_text"].Value := "Emojis can be used to add visual elements to your text. Here are some examples:"
  }
  hs_rb_ansi.OnEvent("Click", hs_switchListView)
  hs_rb_kaomoji.OnEvent("Click", hs_switchListView)
  hs_rb_boxes.OnEvent("Click", hs_switchListView)
  hs_rb_emoji.OnEvent("Click", hs_switchListView)
  hs_rb_custom.OnEvent("Click", hs_switchListView)

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 4 - Window Management                                                             │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(4)
  aboutDlg.SetFont("c000000 Bold q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w862 h60", "Control to the size and location of an active window with hotkeys and mouse-based adjustments!")

  ; ; --- Radio Buttons and Dynamic ListViews ---

  ; ; GroupBox for visual clarity (optional)
  ; aboutDlg.SetFont("c000000 Bold q5 s10", guiFont)
  ; aboutDlg.Add("GroupBox", "x16 y100 w862 h50", "Modality")

  ; ; Radio Buttons (horizontal)
  ; aboutDlg.SetFont("c000000 Norm q5 s10", guiFont)
  ; wm_rb_keeb := aboutDlg.Add("Radio", "x32 y120 w120 h23 ", "")
  ; wm_rb_keyclick := aboutDlg.Add("Radio", "x172 y120 w200 h23 ", "CapsLock ⇪  + Mouse 🖱️ ")

  ; wm_rb_keeb.Value := true ; Default selection
  ; ListViews for each category (stacked, only one visible at a time)
  aboutDlg.SetFont("Norm q5 s10", guiFont)
  wm_lv_keeb := aboutDlg.Add("ListView", "x16 y100 w862 r19 vwm_lv_keeb", ["Action", "Hotkey", "Description"])
  wm_lv_keeb.Opt("+Report") ; +Sort")
  wm_lv_keeb.Opt("-Redraw")
  wm_lv_keeb.Add(, "Resize Window to 70%", "[Ctrl] [Alt][Win]/", "Resize the window to 70% of the monitor.")
  wm_lv_keeb.Add(, "Shrink current window", "[Ctrl] [Alt][Win]<", "5% smaller")
  wm_lv_keeb.Add(, "Expand current window", "[Ctrl] [Alt][Win]>", "5% larger")
  wm_lv_keeb.Add(, "Extend current window's top border", "[Ctrl] [Alt] I", "Extend windo to the top of the screen")
  wm_lv_keeb.Add(, "Extend current window's bottom border", "[Ctrl] [Alt] K", "Extend windo to the bottom of the screen")
  wm_lv_keeb.Add(, "Extend current window's left border", "[Ctrl] [Alt] J", "Extend windo to the left of the screen")
  wm_lv_keeb.Add(, "Extend current window's right border", "[Ctrl] [Alt] L", "Extend windo to the right of the screen")
  wm_lv_keeb.Add(, "Resize window with mouse", "[Ctrl] [Alt][Win]Right🖱️ drag", "Extend windo to the right of the screen")
  wm_lv_keeb.Add(, "Move window up", "[Ctrl] [Alt][Win]I", "Move window up by 10%")
  wm_lv_keeb.Add(, "Move window down", "[Ctrl] [Alt][Win]K", "Move window down by 10%")
  wm_lv_keeb.Add(, "Move window left", "[Ctrl] [Alt][Win]J", "Move window left by 10%")
  wm_lv_keeb.Add(, "Move window right", "[Ctrl] [Alt][Win]L", "Move window right by 10%"),
    wm_lv_keeb.Add(, "Move window with mouse", "[Ctrl] [Alt][Win]Left🖱️ drag", "Move window with mouse")
  ; wm_lv_keeb.Add(, "Move Window to Center", "[Ctrl] [Alt][Win]M", "Move the window to the center of the monitor.")
  wm_lv_keeb.Add(, "Expand Window Vertically", "[Ctrl] [Alt] [Shift/⇧] I", "Expand the window vertically.")
  wm_lv_keeb.Add(, "Shrink Window Vertically", "[Ctrl] [Alt] [Shift/⇧] J", "Shrink the window vertically.")
  wm_lv_keeb.Add(, "Expand Window Horizontally", "[Ctrl] [Alt] [Shift/⇧] K", "Expand the window horizontally.")
  wm_lv_keeb.Add(, "Shrink Window Horizontally", "[Ctrl] [Alt] [Shift/⇧] L", "Shrink the window horizontally.")

  wm_lv_keeb.ModifyCol(1) ; Auto-size the first column
  wm_lv_keeb.ModifyCol(2) ; Auto-size the second column
  wm_lv_keeb.ModifyCol(3)
  wm_lv_keeb.Opt("+Redraw")

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 5 - Arpeggios                                                                     │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(5)
  ; aboutDlg.SetFont("Bold s10", guiFont)
  ; aboutDlg.Add("Text", "x16 y70 w690 h30", "Arpeggios")
  aboutDlg.SetFont("c000000 Norm q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w862 h50", "Instead of a hotkey or hotstring, an Arpeggio is a sequence of keys — like playing musical notes. Set the Mood, tap a letter, and go.")

  ; --- Radio Buttons and Dynamic ListViews ---
  aboutDlg.SetFont("c000000 Norm q5 s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y128 w862 h52", "Mood  —  ⊞ Win  Alt  O,  then…")

  ; Radio Buttons (horizontal, inside GroupBox)
  a_rb_apps := aboutDlg.Add("Radio", "x32 y150 w120 h23", "Applications")
  a_rb_clip := aboutDlg.Add("Radio", "x172 y150 w120 h23", "Selected Text")
  a_rb_nav := aboutDlg.Add("Radio", "x312 y150 w120 h23", "Navigation")

  a_rb_apps.Value := true ; Default selection

  ; ListViews for each category (stacked, only one visible at a time)
  a_lv_apps := aboutDlg.Add("ListView", "x16 y192 w862 r14 va_lvapps", ["Key", "Application", "Notes"])
  a_lv_apps.Opt("+Report")
  a_lv_apps.Opt("-Redraw")
  a_lv_apps.Add(, "a", "Antigravity", "")
  a_lv_apps.Add(, "b", "Beyond Compare 4", "")
  a_lv_apps.Add(, "c", "Visual Studio Code", "")
  a_lv_apps.Add(, "C", "VS Code Insiders", "")
  a_lv_apps.Add(, "d", "Claude", "")
  a_lv_apps.Add(, "e", "Epic Pen", "")
  a_lv_apps.Add(, "k", "KeyViz", "")
  a_lv_apps.Add(, "l", "Copilot", "")
  a_lv_apps.Add(, "n", "Notion", "")
  a_lv_apps.Add(, "N", "Notepad", "")
  a_lv_apps.Add(, "o", "OpenAI Codex", "")
  a_lv_apps.Add(, "p", "Perplexity Comet", "")
  a_lv_apps.Add(, "t", "Windows Terminal", "")
  a_lv_apps.Add(, "T", "Windows Terminal", "Elevated")
  a_lv_apps.Add(, "v", "Windows Terminal Preview", "")
  a_lv_apps.Add(, "w", "Warp Terminal", "")
  a_lv_apps.Add(, "z", "Zed", "")
  a_lv_apps.ModifyCol(1, 40)
  a_lv_apps.ModifyCol(2)
  a_lv_apps.Opt("+Redraw")

  a_lv_clip := aboutDlg.Add("ListView", "x16 y192 w862 r14 va_lv_clip", ["Key", "Action", "Description"])
  a_lv_clip.Add(, "—", "No entries yet", "")
  a_lv_clip.Visible := false

  a_lv_nav := aboutDlg.Add("ListView", "x16 y192 w862 r14 va_lv_nav", ["Key", "Action", "Description"])
  a_lv_nav.Add(, "—", "No entries yet", "")
  a_lv_nav.Visible := false

  ; Handler to switch ListViews
  a_switchListView(*) {
    a_lv_apps.Visible := a_rb_apps.Value
    a_lv_clip.Visible := a_rb_clip.Value
    a_lv_nav.Visible := a_rb_nav.Value
  }
  a_rb_apps.OnEvent("Click", a_switchListView)
  a_rb_clip.OnEvent("Click", a_switchListView)
  a_rb_nav.OnEvent("Click", a_switchListView)


  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 6 - App Controls                                                                │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 7 - Other Options                                                                 │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 8 - This.Info                                                                     │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(8)
  aboutDlg.SetFont("Bold s11", guiFont)
  aboutDlg.Add("Text", "x16 y72 w400 h20", "ThisSystem.Info")

  btnLoad := aboutDlg.Add("Button", "x700 y68 w170 h26 vbtnLoad", "⚡ Load System Telemetry")
  btnLoad.OnEvent("Click", PopulateTelemetry)

  ; Group 1: System & OS (Left Top)
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y100 w410 h185", "System & OS")

  yPos := 125
  spacing := 28
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Host Name:")
  aboutDlg.SetFont("Norm s10", guiFont)
  aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtHost", A_ComputerName)
  btnCopyHost := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyHost.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtHost"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Current User:")
  aboutDlg.SetFont("Norm s10", guiFont)
  aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtUser", A_UserName . (A_IsAdmin ? " (Admin)" : ""))
  btnCopyUser := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyUser.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtUser"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "OS Version:")
  aboutDlg.SetFont("Norm s10", guiFont)
  aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtOS", A_OSVersion)
  btnCopyOS := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyOS.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtOS"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Architecture:")
  aboutDlg.SetFont("Norm s10", guiFont)
  aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtArch", A_Is64bitOS ? "64-bit" : "32-bit")
  btnCopyArch := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyArch.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtArch"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Uptime:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtUptime := aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtUptime", "Click 'Load Telemetry'")
  txtUptime.OnEvent("Click", PopulateTelemetry)
  btnCopyUptime := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14 vbtnCopyUptime Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyUptime.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtUptime"].Text))

  ; Group 2: Hardware (Left Bottom)
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y295 w410 h225", "Hardware")

  yPos := 320
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "CPU:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtCPU := aboutDlg.Add("Text", "x145 y" yPos " w230 r2 vtxtCPU", "Click 'Load Telemetry'")
  txtCPU.OnEvent("Click", PopulateTelemetry)
  btnCopyCPU := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14 vbtnCopyCPU Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyCPU.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtCPU"].Text))

  yPos += 40
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Motherboard:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtMB := aboutDlg.Add("Text", "x145 y" yPos " w230 r2 vtxtMB", "Click 'Load Telemetry'")
  txtMB.OnEvent("Click", PopulateTelemetry)
  btnCopyMB := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14 vbtnCopyMB Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyMB.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtMB"].Text))

  yPos += 40
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Installed RAM:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtRAM := aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtRAM", "Click 'Load Telemetry'")
  txtRAM.OnEvent("Click", PopulateTelemetry)
  btnCopyRAM := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14 vbtnCopyRAM Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyRAM.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtRAM"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x30 y" yPos " w110", "Battery / Power:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtBat := aboutDlg.Add("Text", "x145 y" yPos " w230 vtxtBat", "Click 'Load Telemetry'")
  txtBat.OnEvent("Click", PopulateTelemetry)
  btnCopyBat := aboutDlg.Add("Picture", "x385 y" (yPos+2) " w14 h14 vbtnCopyBat Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyBat.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtBat"].Text))

  ; Group 3: Network & Adapters (Right)
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x440 y100 w434 h420", "Network & Telemetry")

  yPos := 125
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "External IP:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtExtIP := aboutDlg.Add("Text", "x570 y" yPos " w260 vtxtExtIP", "Click 'Load Telemetry'")
  txtExtIP.OnEvent("Click", PopulateTelemetry)
  btnCopyExtIP := aboutDlg.Add("Picture", "x840 y" (yPos+2) " w14 h14 vbtnCopyExtIP Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyExtIP.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtExtIP"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "Primary NIC:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtNIC1Desc := aboutDlg.Add("Text", "x570 y" yPos " w280 r2 vtxtNIC1Desc", "Click 'Load Telemetry'")
  txtNIC1Desc.OnEvent("Click", PopulateTelemetry)

  yPos += 36
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "Local IPv4:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtNIC1IP := aboutDlg.Add("Text", "x570 y" yPos " w260 vtxtNIC1IP", "Click 'Load Telemetry'")
  txtNIC1IP.OnEvent("Click", PopulateTelemetry)
  btnCopyNIC1IP := aboutDlg.Add("Picture", "x840 y" (yPos+2) " w14 h14 vbtnCopyNIC1IP Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyNIC1IP.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC1IP"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "Gateway:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtNIC1GW := aboutDlg.Add("Text", "x570 y" yPos " w260 vtxtNIC1GW", "Click 'Load Telemetry'")
  txtNIC1GW.OnEvent("Click", PopulateTelemetry)
  btnCopyNIC1GW := aboutDlg.Add("Picture", "x840 y" (yPos+2) " w14 h14 vbtnCopyNIC1GW Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyNIC1GW.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC1GW"].Text))

  yPos += spacing
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "MAC Address:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtNIC1MAC := aboutDlg.Add("Text", "x570 y" yPos " w260 vtxtNIC1MAC", "Click 'Load Telemetry'")
  txtNIC1MAC.OnEvent("Click", PopulateTelemetry)
  btnCopyNIC1MAC := aboutDlg.Add("Picture", "x840 y" (yPos+2) " w14 h14 vbtnCopyNIC1MAC Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyNIC1MAC.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC1MAC"].Text))

  yPos += 36
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "Secondary NIC:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtNIC2Desc := aboutDlg.Add("Text", "x570 y" yPos " w280 r2 vtxtNIC2Desc", "-")

  yPos += 36
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("Text", "x454 y" yPos " w110", "Secondary IP:")
  aboutDlg.SetFont("Norm s10", guiFont)
  txtNIC2IP := aboutDlg.Add("Text", "x570 y" yPos " w260 vtxtNIC2IP", "-")
  btnCopyNIC2IP := aboutDlg.Add("Picture", "x840 y" (yPos+2) " w14 h14 vbtnCopyNIC2IP Hidden", A_ScriptDir "\media\icons\icons8-copy-16.png")
  btnCopyNIC2IP.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC2IP"].Text))

  aboutDlg.Title := "Mello-Workspace - About"
  return aboutDlg


}

PopulateTelemetry(_GuiControlObj, *) {
  dlgGui := _GuiControlObj.Gui
  try {
    dlgGui["btnLoad"].Text := "Loading..."
    dlgGui["btnLoad"].Enabled := false
  }

  ThisPC.CollectInfo()

  ; System & OS
  dlgGui["txtUptime"].Text := ThisPC.Uptime
  dlgGui["btnCopyUptime"].Visible := true

  ; Hardware
  cpuStr := ThisPC.CPUInfo.Name . " (" . ThisPC.CPUInfo.NumberOfCores . "/" . ThisPC.CPUInfo.NumberOfLogicalProcessors . ") @ " . Round(ThisPC.CPUInfo.MaxClockSpeed / 1000, 1) . "GHz"
  dlgGui["txtCPU"].Text := cpuStr
  dlgGui["btnCopyCPU"].Visible := true

  mbStr := (ThisPC.Motherboard.Has("Manufacturer") ? ThisPC.Motherboard["Manufacturer"] : "") . " " . (ThisPC.Motherboard.Has("Product") ? ThisPC.Motherboard["Product"] : "")
  dlgGui["txtMB"].Text := mbStr
  dlgGui["btnCopyMB"].Visible := true

  dlgGui["txtRAM"].Text := ThisPC.RAM . " GiB"
  dlgGui["btnCopyRAM"].Visible := true

  batText := (ThisPC.Battery.Count > 0 && ThisPC.Battery.Has("EstimatedChargeRemaining"))
    ? (ThisPC.Battery["EstimatedChargeRemaining"] . "%")
    : "N/A (Desktop / AC Only)"
  dlgGui["txtBat"].Text := batText
  dlgGui["btnCopyBat"].Visible := true

  ; Network
  dlgGui["txtExtIP"].Text := ThisPC.ExternalIP
  dlgGui["btnCopyExtIP"].Visible := true

  if ThisPC.Network.Length > 0 {
    nic1 := ThisPC.Network[1]
    dlgGui["txtNIC1Desc"].Text := nic1["Description"]
    dlgGui["txtNIC1IP"].Text := nic1["IPAddress"]
    dlgGui["btnCopyNIC1IP"].Visible := true
    dlgGui["txtNIC1GW"].Text := (nic1["Gateway"] != "") ? nic1["Gateway"] : "N/A"
    dlgGui["btnCopyNIC1GW"].Visible := (nic1["Gateway"] != "")
    dlgGui["txtNIC1MAC"].Text := (nic1["MACAddress"] != "") ? nic1["MACAddress"] : "N/A"
    dlgGui["btnCopyNIC1MAC"].Visible := (nic1["MACAddress"] != "")
  }

  if ThisPC.Network.Length > 1 {
    nic2 := ThisPC.Network[2]
    dlgGui["txtNIC2Desc"].Text := nic2["Description"]
    dlgGui["txtNIC2IP"].Text := nic2["IPAddress"]
    dlgGui["btnCopyNIC2IP"].Visible := true
  }

  try {
    dlgGui["btnLoad"].Text := "⚡ Refresh Telemetry"
    dlgGui["btnLoad"].Enabled := true
  }
}

GetPCInfo(_GuiControlObj, *) {
  PopulateTelemetry(_GuiControlObj)
}

CopyToClipboard(text, *) {
  ; Function to copy text to clipboard
  A_Clipboard := text
  ToolTip("Copied to clipboard!", , , 1)
  SetTimer () => ToolTip(, , , 1), -1000
  return
}