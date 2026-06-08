<!-- Auto-generated: guidance for AI coding agents working on Mello.Ops.Local -->
# Copilot instructions for Mello.Ops.Local

Goal: Be productive quickly. This repository is a modular AutoHotkey v2 toolkit for Windows. Focus edits on small, well-scoped changes to the `lib/` modules and `Mello.Ops.ahk` entrypoint.

Key facts
- Language/runtime: AutoHotkey v2 (every library file begins with `#Requires AutoHotkey v2.0`).
- No compiled build step. Run locally by double-clicking `Mello.Ops.ahk` or using `Start-Mello.Ops.ps1` (installer/launcher).
- Installer uses PowerShell to fetch the repo and deploy a portable AutoHotkey runtime (see `Start-Mello.Ops.ps1`).

Project structure to reference
- `Mello.Ops.ahk` — main script / composition point. New `lib/` modules should be included here.
- `lib/` — modular AHK libraries (e.g. `hotkeys-core.ahk`, `winui-mgmt.ahk`, `_parse_config.ahk`). Use these as canonical examples for style and patterns.
- `Start-Mello.Ops.ps1` — install/launch flow; mimic its expectations when changing runtime or paths.
- `docs/README.md` and root `README.md` — useful for high-level behavior, hotkey lists and UI UX assumptions.

Conventions and patterns (do NOT invent other styles)
- Use `#Requires AutoHotkey v2.0` and `#SingleInstance Force` in top-level scripts.
- File and function naming: PascalCase for functions (e.g. `SqueezeAndPose`, `HandleWindowResize`).
- Use global uppercase constants for configuration, e.g. `global GESTURE_TOLERANCE := 60`.
- Hotkey layers: scripts commonly use `#HotIf` to avoid conflicting behavior in remote sessions (see `hotkeys-core.ahk` using `#HotIf !(WinActive("ahk_class TscShellContainerClass"))`). Keep remote-session guards intact.
- Exclude lists: use `IsExcludedWindow()` in window-management code to avoid manipulating system/overlay windows (see `winui-mgmt.ahk`). When adding excluded classes/titles, add to the array used there.

Hotkey and input patterns (examples)
- Double-press detectors: use prior-hotkey + A_TimeSincePriorHotkey pattern (see `~RAlt::` in `hotkeys-core.ahk`).
- Modifier checks: prefer `GetKeyState("LShift", "P")` style inside hotkey blocks for multi-modifier behaviors.
- When adding hotkeys that move/resize windows, always call `IsExcludedWindow()` and check `WinGetMinMax()` to avoid messing maximized or remote windows.

Testing & debug workflow
- Local test: run `Mello.Ops.ahk` directly; changes load on script reload. Use `Ctrl+Win+Alt+R` (or configured reload hotkey) to reload during development.
- If a runtime change is needed, update `Start-Mello.Ops.ps1` and document in README. Avoid changing the default install behavior unless necessary.
- For visual/debug traces, follow existing patterns (small `MsgBox` or `TrayTip`) rather than noisy logging.

Integration & external dependencies
- Only external runtime is AutoHotkey v2 (portable distribution handled by `Start-Mello.Ops.ps1`).
- Installer and update flows use raw GitHub URLs — avoid hardcoding local paths that break the installer.

What to change and what to avoid
- Good: Add small, focused modules under `lib/`, following existing function naming and hotkey patterns; include `#Requires` header; reference `IsExcludedWindow()` if touching windows; update messages in 'lib/_help_about.ahk' to reflect changes
- Avoid: Large refactors across many modules in a single PR. Avoid changing installer semantics without updating `Start-Mello.Ops.ps1` and README.

Files to read first when working on features
- `lib/hotkeys-core.ahk` — canonical hotkey patterns and `#HotIf` usage
- `lib/winui-mgmt.ahk` — window management best practices, DllCall/monitor helpers
- `Mello.Ops.ahk` — script composition and inclusion points
- `Start-Mello.Ops.ps1` — install/launcher behavior

If unclear, ask the user these concrete questions
1. Should a new lib/ file be auto-included by `Mello.Ops.ahk`, or do you want me to add an explicit include line?
2. Should changes to hotkeys be optional (config-driven) or always enabled by default?

End of guidance — ready to iterate on specifics or merge into an existing `.github/copilot-instructions.md` if you want changes.
