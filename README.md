# Mello-Workspace Dev Environment

Dev workspace build environment scaffolding for Windows-based development systems. This repository provides a structured approach to managing multiple git repositories using bare repositories and worktrees, ideal for complex application development with multiple components.

## Overview

This scaffolding provides a local build environment structure that separates code repositories, build artifacts, and tooling into organized directories. It uses git bare repositories as the foundation, allowing multiple worktrees to be checked out from each repository.

## Directory Structure

```
Mello-Workspace_dev-env/
├── bare-repos/              # Git bare repositories (source of truth)
│   ├── main-system.git/     # Main application bare repository
│   ├── plugins.git/         # Plugins component bare repository
│   ├── scripts.git/         # Build scripts bare repository
│   └── resources.git/       # Resource DLLs bare repository
├── worktrees/               # Git worktrees (active working copies)
├── build-output/            # Compiled binaries and build artifacts
├── tools/                   # Build tools and utilities
├── makefiles/               # Makefiles for resource DLLs
└── README.md               # This file
```

## Getting Started

### 1. Initialize Bare Repositories

Each bare repository in `bare-repos/` needs to be initialized before use:

```bash
# Initialize main system repository
cd bare-repos/main-system.git
git init --bare

# Initialize plugins repository
cd ../plugins.git
git init --bare

# Initialize scripts repository
cd ../scripts.git
git init --bare

# Initialize resources repository
cd ../resources.git
git init --bare
```

### 2. Create Worktrees

After initializing bare repositories, create worktrees for active development:

```bash
# Create a worktree for main system
git --git-dir=bare-repos/main-system.git worktree add worktrees/main-system main

# Create a worktree for plugins
git --git-dir=bare-repos/plugins.git worktree add worktrees/plugins main

# Create a worktree for scripts
git --git-dir=bare-repos/scripts.git worktree add worktrees/scripts main

# Create a worktree for resources
git --git-dir=bare-repos/resources.git worktree add worktrees/resources main
```

### 3. Working with the Environment

- **Code Development**: Work in the `worktrees/` directory for each component
- **Build Outputs**: Compiled artifacts automatically go to `build-output/`
- **Resource Building**: Use makefiles in `makefiles/` directory to build resource DLLs
- **Tools**: Store development tools in the `tools/` directory

## Use Cases

### Plugin Development

1. Navigate to `worktrees/plugins/`
2. Develop plugin code
3. Commit changes (updates the bare repository)
4. Build outputs go to `build-output/plugins/`

### Resource DLL Creation

1. Place resource files (icons, audio, images) in `worktrees/resources/`
2. Use makefiles in `makefiles/` to build resource DLLs
3. Output DLLs are stored in `build-output/resources/`

### Build Scripts

1. Develop build automation in `worktrees/scripts/`
2. Scripts can reference other worktrees and build outputs
3. Common scripts: build-all.bat, clean.bat, package.bat

## Benefits of This Structure

- **Separation of Concerns**: Each component has its own repository
- **Clean History**: Bare repositories maintain clean git history
- **Multiple Worktrees**: Work on different branches simultaneously
- **Organized Builds**: Clear separation between source and build outputs
- **Windows-Friendly**: Structure designed for Windows development workflows

## Contributing

When adding new components:

1. Create a new bare repository in `bare-repos/`
2. Initialize it with `git init --bare`
3. Create corresponding worktree in `worktrees/`
4. Update this README with the new component

## Notes

- Build outputs in `build-output/` are excluded from version control
- Worktree contents are excluded from version control (managed by their respective bare repos)
- Each bare repository can have multiple worktrees for different branches
