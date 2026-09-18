# SoundSwap classifies device icons by FormFactor only, with no name-keyword fallback

Icons in the tray submenu and OSD need to distinguish speakers, headphones/headsets, microphones, and digital (HDMI/SPDIF) outputs. Windows' `PKEY_AudioEndpoint_FormFactor` property gives a real classification for most devices, but returns `Unknown` for some. The obvious fallback — matching keywords like "headset" or "headphone" in the friendly name — was considered and rejected.

We chose `FormFactor` as the sole source, with devices it can't classify falling back to a generic Output/Input icon rather than a guessed one. Keyword matching reintroduces exactly the guessing problem `FormFactor` exists to avoid, and fails silently on non-English or branded device names (e.g. "Sony WH-1000XM5" has no "headset" in it). A wrong icon (mislabeling a headset as a plain speaker) was judged worse than a coarser-but-always-correct one.
