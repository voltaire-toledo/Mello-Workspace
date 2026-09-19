#Requires AutoHotkey v2.0
; ╭════════════════════════════════════════════════════════════════════════════════════════════════════════════════─╮
; ║  HK-MGMT.AHK                                                                                                    ║
; ║    - Hotkey Management and string formatting utilities.                                                         ║
; ║    - Translates internal AHK modifier characters (^, !, +, #) to friendly user strings (Ctrl, Alt, Shift, Win).║
; ║    - Parses user-input hotkey strings back to valid AHK modifier syntax.                                        ║
; ╰═════════════════════════════════════════════════════════════════════════════════════════════════════════════════╯

; ╭────────────────────────────────────────────────────────────────────────────────────────────╮
; │ FormatHotkeyForDisplay(hk)                                                                 │
; │   Converts AHK hotkey syntax (e.g. "^!F12", "#!m") into human-friendly strings              │
; │   (e.g. "Ctrl + Alt + F12", "Win + Alt + M").                                              │
; ╰────────────────────────────────────────────────────────────────────────────────────────────╯
FormatHotkeyForDisplay(hk) {
  if (hk = "")
    return ""
  if RegExMatch(hk, "i)\b(ctrl|alt|shift|win)\b")
    return hk

  mods := []
  pos := 1
  len := StrLen(hk)

  while pos <= len {
    ch := SubStr(hk, pos, 1)
    if (ch = "^") {
      mods.Push("Ctrl")
      pos++
    } else if (ch = "!") {
      mods.Push("Alt")
      pos++
    } else if (ch = "+") {
      mods.Push("Shift")
      pos++
    } else if (ch = "#") {
      mods.Push("Win")
      pos++
    } else if (ch = "<" || ch = ">") {
      side := (ch = "<") ? "L" : "R"
      nextCh := (pos < len) ? SubStr(hk, pos + 1, 1) : ""
      if (nextCh = "^") {
        mods.Push(side "Ctrl")
        pos += 2
      } else if (nextCh = "!") {
        mods.Push(side "Alt")
        pos += 2
      } else if (nextCh = "+") {
        mods.Push(side "Shift")
        pos += 2
      } else if (nextCh = "#") {
        mods.Push(side "Win")
        pos += 2
      } else {
        break
      }
    } else if (ch = "~" || ch = "*") {
      pos++
    } else {
      break
    }
  }

  key := SubStr(hk, pos)
  if (StrLen(key) = 1)
    key := StrUpper(key)
  else if (RegExMatch(key, "i)^f\d+$"))
    key := StrUpper(key)

  if (mods.Length = 0)
    return key

  result := ""
  for i, m in mods
    result .= (i = 1 ? "" : " + ") . m
  return result . " + " . key
}

; ╭────────────────────────────────────────────────────────────────────────────────────────────╮
; │ ParseHotkeyFromDisplay(inputStr)                                                           │
; │   Parses user-entered hotkey strings (e.g. "Ctrl + Alt + F12", "[Win] [Alt] M", "^!F12")    │
; │   into canonical AHK hotkey modifier combinations for Hotkey() and INI storage.             │
; ╰────────────────────────────────────────────────────────────────────────────────────────────╯
ParseHotkeyFromDisplay(inputStr) {
  s := Trim(RegExReplace(inputStr, "[\[\]]", ""))
  if (s = "")
    return ""

  if !RegExMatch(s, "i)\b(ctrl|alt|shift|win)\b")
    return s

  parts := StrSplit(RegExReplace(s, "\s*\+\s*", "+"), ["+", " ", "-"])
  modsPrefix := ""
  key := ""

  for part in parts {
    p := Trim(part)
    if (p = "")
      continue
    pLower := StrLower(p)
    if (pLower = "ctrl" || pLower = "control")
      modsPrefix .= "^"
    else if (pLower = "lctrl")
      modsPrefix .= "<^"
    else if (pLower = "rctrl")
      modsPrefix .= ">^"
    else if (pLower = "alt")
      modsPrefix .= "!"
    else if (pLower = "lalt")
      modsPrefix .= "<!"
    else if (pLower = "ralt")
      modsPrefix .= ">!"
    else if (pLower = "shift")
      modsPrefix .= "+"
    else if (pLower = "lshift")
      modsPrefix .= "<+"
    else if (pLower = "rshift")
      modsPrefix .= ">+"
    else if (pLower = "win" || pLower = "windows")
      modsPrefix .= "#"
    else if (pLower = "lwin")
      modsPrefix .= "<#"
    else if (pLower = "rwin")
      modsPrefix .= ">#"
    else
      key := p
  }

  if (StrLen(key) = 1)
    key := StrLower(key)

  return modsPrefix . key
}
