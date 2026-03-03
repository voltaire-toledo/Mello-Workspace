#Requires AutoHotkey v2.0
; ╭──────────────────────────────────────── ─ ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·   ·
; │ HOW TO ADD CUSTOM ACTIONS HERE
; │ 1. The customizations included in this file are meant to be examples. You 
; │    can modify or delete them as you see fit.
; │ 2. To add your own custom actions, simply copy and paste the code blocks 
; │    below and modify them to your needs.
; │ 3. MellOS-LE will search for a file called ".mwslrc.ahk" in an order of
; │    precedence where the first file found "wins":
; │    a. [Path-to-Mello-Workspace.ahk]\..\custom\.mwslrc.ahk
; │    b. [$env:LocalAppData]\.mwslrc.ahk
; │    c.The current working directory (CWD) where MellOS-LE is launched from
; │ 4. If you want to keep your customizations separate from the default ones, you can create a new file with that name in the same directory as this file and add your customizations there. MellOS-LE will automatically load it after loading this file, allowing you to override any of the default customizations if needed.
; ├────────────────────────────────────────────────────────────────── ─ ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·   
; │ Multi-line strings for hotstring replacements. You can create as many of these as you like and use them in hotstrings below.
; ╰────────────────────────────────────────────────────────────────── ─ ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·   ·
personal_sig :=
(
  "Best regards,
  
  Beefy McWhatnow
  💬 +1(519)-456-789ten
  🌐 myhome@email.com"
)

work_sig :=
(
  "Me out!
  
  Huge Hugs
  Working Goldfish
  💬 +1-248-DAT-GUY!
  🌐 jerb@chaingang.com"
)

; ╭────────────────────────────────────────────────────────────────── ─ ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·   ·
; │ Hotstrings Aliases                                                                                  │
; ├────────────────────────────────────────────────────────────────── ─ ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·   ·
; │ In the example below, string replacement occurs when you type !!home or !!work followed by ending   │
; │ character, i.e. -, (, ), [, ], {, }, :, ;, ', ", /, \, ,, ., ?, !, [ENTER], [Space] and[Tab]        │
; ╰─────────────────────────────────────────────────────────────────────────────────────────────────────╯
; ~@home for your personal signature
:X:`!`!home:: PasteWith(personal_sig)

; ~@work for your work signature
:X:`!`!work:: PasteWith(work_sig)

^!w::
; ╭─────────────────────────────── ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·
; │  [Ctrl]+[Alt]+[W] for Warp Terminal
; │  [Ctrl]+[Alt]+[Shift]+[W] for Warp Terminal in Admin Mode
; ╰───────────────────────────────────────── ─ ─ ─ ─ ▪ ▪ ▪ • •  ·  ·   ·   ·   ·
{
    ; Check if the user is also holding down the [Shift] key
    if GetKeyState("LShift", "P") && GetKeyState("Alt", "P") && GetKeyState("LCtrl", "P") {
        ShowActionSplash("Starting Warp Terminal (Admin)...")
        LaunchApp("Warp", 1)
    } else {
        ShowActionSplash("Starting Warp Terminal...")
        LaunchApp("Warp")
    }
}
