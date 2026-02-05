# Quick Start Guide

This guide will help you get started with the Mello Workspace build environment on Windows.

## Prerequisites

- Git for Windows installed
- Visual Studio or Windows SDK (for resource compiler and linker)
- Make utility (optional, for using makefiles)

## Initial Setup

### Option 1: Automated Setup (Recommended)

Run the automated setup script:

```batch
setup-environment.bat
```

This script will:
1. Initialize all bare repositories
2. Create initial commits
3. Set up worktrees
4. Create build output directories

### Option 2: Manual Setup

If you prefer manual setup or need to customize:

1. **Initialize each bare repository:**
   ```batch
   cd bare-repos\main-system.git
   git init --bare
   cd ..\..
   ```
   Repeat for `plugins.git`, `scripts.git`, and `resources.git`

2. **Create worktrees:**
   ```batch
   git --git-dir=bare-repos/main-system.git worktree add worktrees/main-system main
   ```
   Repeat for other repositories

## Daily Workflow

### Working on Main System

```batch
cd worktrees\main-system
# Edit files, make changes
git add .
git commit -m "Your changes"
git push origin main
```

### Working on Plugins

```batch
cd worktrees\plugins
# Develop plugin code
git add .
git commit -m "New plugin feature"
git push origin main
```

### Building Resources

```batch
cd makefiles
nmake /f resources.mk
# or
make -f resources.mk
```

### Creating a New Branch Worktree

To work on a feature branch:

```batch
git --git-dir=bare-repos/main-system.git worktree add worktrees/main-system-feature feature-branch
```

## Common Tasks

### Check Worktree Status

```batch
git --git-dir=bare-repos/main-system.git worktree list
```

### Remove a Worktree

```batch
git --git-dir=bare-repos/main-system.git worktree remove worktrees/main-system-feature
```

### Clean Build Outputs

```batch
cd build-output
del /s /q *.dll *.exe *.obj *.res
```

## Tips

- Each component (main-system, plugins, scripts, resources) has its own bare repository
- You can have multiple worktrees from the same bare repository for different branches
- Build outputs are automatically excluded from git via .gitignore
- Always commit in the worktree directory, not in bare-repos/

## Troubleshooting

**Issue**: Worktree creation fails
- **Solution**: Ensure the bare repository is initialized and has at least one commit

**Issue**: Resource compiler not found
- **Solution**: Run from Visual Studio Developer Command Prompt or add VC tools to PATH

**Issue**: Git commands show "not a git repository"
- **Solution**: Make sure you're in a worktree directory or using --git-dir parameter

## Next Steps

1. Start developing in `worktrees/main-system/`
2. Add your source files to appropriate worktrees
3. Set up build scripts in `worktrees/scripts/`
4. Create resource files in `worktrees/resources/`
5. Use makefiles to automate builds
