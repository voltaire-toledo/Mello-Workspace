---
name: autohotkey-v2
description: Expert guidance on AutoHotkey (AHK) V2 scripting, syntax, and known limitations. Use when writing, debugging, or converting scripts to AHK V2, especially for Windows automation and UI interaction.
---

# AutoHotkey V2 Skill

This skill provides expert knowledge for developing automation scripts using AutoHotkey (AHK) V2.

## Core Syntax & Paradigms

AHK V2 is a major departure from V1, moving toward a more consistent, expression-based, and object-oriented syntax.

- **Everything is an Expression**: No more literal strings by default. Use quotes for strings: `MsgBox("Hello World")` instead of `MsgBox Hello World`.
- **Functions over Commands**: Almost all "commands" are now functions. Parentheses are optional for top-level calls but recommended for clarity.
- **Objects & Classes**: V2 has first-class object support. Maps and Arrays are distinct types.
  - `myMap := Map("key", "value")`
  - `myArray := ["item1", "item2"]`
- **Variable Declaration**: Variables do not need explicit declaration but `local` and `global` keywords are strictly enforced inside functions.

## Common Patterns

### Hotkeys and Hotstrings
```autohotkey
; Simple Hotkey
#n::Run("notepad.exe") ; Win+N

; Context-sensitive Hotkey
#HotIf WinActive("ahk_class Notepad")
^s::MsgBox("You pressed Ctrl+S in Notepad")
#HotIf
```

### GUI Creation
```autohotkey
myGui := Gui()
myGui.Add("Text",, "Name:")
myGui.Add("Edit", "vName")
myGui.Add("Button", "Default", "OK").OnEvent("Click", ProcessOK)
myGui.Show()

ProcessOK(btn, info) {
    saved := myGui.Submit()
    MsgBox("Hello " . saved.Name)
}
```

## Limitations & Gotchas

1. **V1 Incompatibility**: V2 is NOT backward compatible with V1 scripts. Most V1 scripts will require manual or tool-assisted conversion.
2. **Scope Strictness**: V2 is much stricter about global variables. Use `global` keyword explicitly if you need to modify a global variable inside a function.
3. **Empty Values**: `""` is an empty string, while `unset` is a specific state for uninitialized variables.
4. **Library Availability**: While many popular libraries have been ported, some niche V1 libraries may not have V2 equivalents yet.
5. **Windows Only**: AHK remains a Windows-only automation tool.

## Resources

- **Official Docs**: [AutoHotkey v2 Help](https://www.autohotkey.com/docs/v2/)
- **v1 to v2 Converter**: [A HK-v2-script-converter](https://github.com/mmikeww/AHK-v2-script-converter) (Community tool)
