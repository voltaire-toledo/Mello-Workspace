# SoundSwap uses a named mutex to guard against standalone + #Include'd concurrent hotkey registration

SoundSwap can run standalone or `#Include`d into Mello-Workspace. If both run simultaneously (a dev accident), each process independently registers the same global hotkeys — AHK's `#SingleInstance` only guards against two copies of the *same* script, not two different processes claiming the same hotkey combo, which can silently misroute or double-fire keypresses.

We chose to actively guard this with a named Win32 mutex (`Local\MelloWorkspace_SoundSwap_Mutex`) checked at startup: if already held, standalone mode skips hotkey registration and shows a one-time notice that SoundSwap is already active via Mello-Workspace, instead of documenting the conflict as a footgun to avoid. This was a deliberate choice over the cheaper option (do nothing, document "don't run both") because it directly satisfies TASK-17.2 AC #6 for a few lines of Win32 code.
