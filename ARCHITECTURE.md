# Mello Workspace Architecture

## Repository Structure Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Mello-Workspace_dev-env                          │
│                   (Root Directory)                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│  bare-repos/ │      │  worktrees/  │     │build-output/ │
│              │      │              │     │              │
└──────────────┘      └──────────────┘     └──────────────┘
        │                     │                     │
        │                     │                     │
  ┌─────┴─────┐         ┌─────┴─────┐         ┌─────┴─────┐
  │           │         │           │         │           │
  ▼           ▼         ▼           ▼         ▼           ▼
main-sys   plugins   main-sys   plugins   main-sys   plugins
.git/      .git/     /          /         /          /
  │           │         │           │         │           │
scripts    resources scripts    resources scripts    resources
.git/      .git/     /          /         /          /


┌──────────────┐      ┌──────────────┐
│ makefiles/   │      │   tools/     │
│              │      │              │
└──────────────┘      └──────────────┘
```

## Component Relationships

```
┌────────────────────────────────────────────────────────────┐
│                  Development Workflow                      │
└────────────────────────────────────────────────────────────┘

1. Developer works in worktrees/
   ├── worktrees/main-system/    (active code)
   ├── worktrees/plugins/        (active code)
   ├── worktrees/scripts/        (active code)
   └── worktrees/resources/      (active code)
              │
              ▼
2. Commits are stored in bare-repos/
   ├── bare-repos/main-system.git/    (git history)
   ├── bare-repos/plugins.git/        (git history)
   ├── bare-repos/scripts.git/        (git history)
   └── bare-repos/resources.git/      (git history)
              │
              ▼
3. Build process creates outputs
   ├── build-output/main-system/      (binaries)
   ├── build-output/plugins/          (plugin DLLs)
   ├── build-output/scripts/          (helper scripts)
   └── build-output/resources/        (resource DLLs)
```

## Git Bare Repository + Worktree Model

```
┌─────────────────────────────────────────────────────────────┐
│  Bare Repository (main-system.git)                          │
│  ┌───────────────────────────────────────┐                 │
│  │ Git Objects & References              │                 │
│  │ - All commits, branches, tags         │                 │
│  │ - No working directory                │                 │
│  │ - Acts as "source of truth"           │                 │
│  └───────────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ git worktree add
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌──────────────┐        ┌──────────────┐
│ Worktree 1   │        │ Worktree 2   │
│              │        │              │
│ Branch: main │        │ Branch: dev  │
│              │        │              │
│ Working dir  │        │ Working dir  │
│ with files   │        │ with files   │
└──────────────┘        └──────────────┘
```

## Build Process Flow

```
┌─────────────┐
│  Source     │
│  Files      │
│ (worktrees) │
└──────┬──────┘
       │
       │ 1. Developer edits code
       ▼
┌─────────────┐
│   Build     │
│   Scripts   │
│ (makefiles) │
└──────┬──────┘
       │
       │ 2. Compile/Link
       ▼
┌─────────────┐
│   Build     │
│   Output    │
│  (DLLs/EXE) │
└──────┬──────┘
       │
       │ 3. Package/Deploy
       ▼
┌─────────────┐
│  Release    │
│  Package    │
└─────────────┘
```

## Key Benefits

1. **Separation of Concerns**
   - Source code: `worktrees/`
   - Git data: `bare-repos/`
   - Build outputs: `build-output/`
   - Build tools: `tools/` and `makefiles/`

2. **Multiple Worktrees**
   - Work on multiple branches simultaneously
   - Each worktree is a complete working directory
   - Share the same git history (bare repo)

3. **Component Isolation**
   - Each component (main, plugins, scripts, resources) has its own repo
   - Independent version control
   - Can be worked on separately or together

4. **Clean Build Management**
   - Build outputs separated from source
   - Easy to clean and rebuild
   - No build artifacts in version control
