# Mello-Workspace

An AutoHotkey v2 productivity toolkit for Windows, composed of a main script plus modular libraries and standalone-capable plugins.

## Language

**SoundSwap**:
The audio-device-switching plugin (`plugins/SoundSwap/`). A minimal cycle/select tool for Windows playback and recording devices.
_Avoid_: SoundSwitch, SoundSwitcher — these collide with the existing third-party Windows utility "SoundSwitch" (Antoine Aflalo / Rogue Amoeba), a larger, full-featured product SoundSwap is deliberately not competing with.

**Device kind**:
The Output/Input split for an audio endpoint — Output (playback, `eRender`) or Input (recording, `eCapture`). Determined by which enumeration role a device was returned under.
_Avoid_: device type (ambiguous with form factor)

**Form factor**:
The endpoint's physical category (Speakers, Headphones, Microphone, Digital/HDMI, etc.), read from Windows' `PKEY_AudioEndpoint_FormFactor` property. The sole source used to pick a device's tray/OSD icon — never guessed from the friendly name.
_Avoid_: device kind (that's the Output/Input split, a different axis)

**Cycle**:
Advancing to the next eligible device in rotation via hotkey — alphabetical by friendly name, silent (no on-screen picker), confirmed afterward by the OSD. SoundSwap's only hotkey-driven interaction model; a separate on-screen picker was considered and rejected.
_Avoid_: switch (too generic — cycle is specifically the hotkey-driven rotate action, as distinct from an explicit pick via the tray menu)

**Mode** (allow/block filtering):
Per device-kind setting in `config.ini` controlling which devices are eligible for cycling. `Block` (default) rotates all devices except those listed; `Allow` rotates only the listed devices.
_Avoid_: whitelist/blacklist

**Filtered out**:
A device excluded from cycling by the current allow/block Mode. Distinct from **removed** (the device is physically disconnected). Filtering the active device out does not force an immediate switch — only removal does.
