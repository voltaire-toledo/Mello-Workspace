# Mello Workspace Architecture

## Repository Structure Diagram

```plaintext

  📂 Mello-WS-Hub\
   │
   ├──📂 .claude\
   │
   ├──📂 .config\
   │
   ├──📂 .gemini\
   │   └──📂 skills\
   │
   ├──📂 .github\
   │
   ├──📂 .vscode\
   │
   ├──📂 build-output\
   │
   ├──📂 repos\                           (Bare Repos)
   │   ├──📂 .mello-workspace.git\        (Bare Repo - Mello-WorkspacePrimary System)
   │   ├──📂 .mws-plugin-chime.git\       (Bare Repo - Chime Plugin)
   │   ├──📂 .main\
   │   │   ├──📂 mws\                     (Main branch - Mello-Workspace)
   │   │   └──📂 chime\                   (Main branch - Chimne Plugin)
   │   │
   │   ├──📂 fix\
   │   │   └──📂 chime-audio\            (Chimne Plugin Quickfix branch)
   │   │
   │   ├──📂 feat\
   │   │   └──📂 chime-female-voice\     (Chimne Plugin Quickfix branch)
   │   │
   │   ├──📂 lab\
   │   │   └──📂 mws-chime-test\         (Mello-Workspace + Chime Test branch)
   │   │
   │   └──📂 refac\
   │       └──📂 mws-json\               (Mello-Workspace JSON Refactor branch)  
   │
   ├──📂 tools\
   └──📂 workspace-context\               (AI Hub sees ALL of this)

```

## Component Relationships

```
┌────────────────────────────────────────────────────────────┐
│                  Development Workflow                      │
└────────────────────────────────────────────────────────────┘

1. Developer works in repos/ (Worktrees)
   ├── repos/.main/mws/          (Primary System)
   ├── repos/.main/chime/        (Chime Plugin)
   ├── repos/fix/                (Quickfixes)
   └── repos/feat/               (New Features)
              │
              ▼
2. Commits are stored in Bare Repos
   ├── repos/.mello-workspace.git/    (Primary System history)
   └── repos/.mws-plugin-chime.git/   (Chime Plugin history)
              │
              ▼
3. Build process creates outputs
   └── build-output/                  (Compiled artifacts)
```

## Build Process Flow

```
┌─────────────┐
│  Source     │
│  Files      │
│  (repos/)   │
└──────┬──────┘
       │
       │ 1. Developer edits code
       ▼
┌─────────────┐
│   Build     │
│   Tasks     │
│(Taskfile.yml)│
└──────┬──────┘
       │
       │ 2. Compile/Link
       ▼
┌─────────────┐
│   Build     │
│   Output    │
│(build-output/)│
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
   - Source code & Worktrees: `repos/`
   - Build outputs: `build-output/`
   - Build tools: `tools/` and `Taskfile.yml`

2. **Multiple Worktrees**
   - Work on multiple branches simultaneously (feat, fix, lab, refac)
   - Each worktree is a complete working directory
   - Share the same git history (via bare repos in `repos/`)

3. **Component Isolation**
   - Primary system and plugins have independent version control
   - Can be worked on separately or together within the same hub
