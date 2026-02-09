# Core Project Rules & Facts

This directory serves as the centralized "Source of Truth" for all AI agents (Gemini, Claude, Copilot, Codex).

## Project Identity
- **Project Name**: Mello-WS-Hub
- **Purpose**: Workspace Hub management using Git Worktrees and automated scaffolding.

## Shared Development Rules
1. **Tool Usage**: Prefer scripts in `workspace-context/tools/` for repetitive tasks.
2. **Documentation**: Always check `workspace-context/docs/` before proposing architectural changes.
3. **Git Hygiene**: Use worktrees for multi-tasking; do not pollute the main branch with experimental scaffolding.

## Tech Stack
- **OS**: Windows (win32)
- **VCS**: Git (using Bare Repos and Worktrees)
- **Scripting**: PowerShell, Batch
