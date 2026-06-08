# App‑Hub Git Worktree Workflow

_A unified development structure for multi‑product, multi‑client teams_

## Purpose

This document defines a consistent, scalable Git workflow using Git worktrees. It standardizes how developers organize repositories, branches, and working directories across all projects inside ~/app-hub/.

The goals of this workflow:

- Keep development fast and frictionless
- Support multiple simultaneous feature branches
- Maintain a clean, always‑updated local main branch
- Provide a predictable directory structure across all repos
- Work seamlessly with IDEs like VS Code
- Avoid the complexity of bare repos while retaining their benefits
  
# 1. Directory Structure

All repositories live under this Hub `repos/` directory.

Each repository follows this structure:

```
🏷️[hub-directory]
 ├──📁 repos/
 │   ├──📁 .main/              ← local mirror of remote main (always clean)
 │   ├──📁 feat-<branch>/      ← feature branches
 │   ├──📁 fix-<branch>/       ← bugfix branches
 │   ├──📁 lab-<branch>/       ← experiments / spikes
 │   └──📁 refac-<branch>/     ← refactoring branches
 └──📁 releases                ← release packages
```
## Why this structure works

- **`.main/`** acts as a stable anchor for all worktrees
- Each branch has its own **isolated working directory**
- IDEs treat each worktree as a clean project folder
- **No nested repos**, no accidental commits of worktree metadata
- Easy to delete worktrees without touching the main repo

---

# Creating a New Repository in App‑Hub

### Clone the repo into the hub:

This creates the .main directory as the default working copy.

```bash
cd ~/app-hub/repos
git clone <repo-url> .main
```

### Keeping .main Updated

**`.main`** is your local mirror of remote `main` branch.It should always be clean and up to date.

**Update it frequently:**

```bash
cd ~/app-hub/repos/<repo-name>/.main
git pull

# Or from any worktree:

git fetch origin
git -C ~/app-hub/repos/<repo-name>/.main pull
```

> 🔥**IMPORTANT**
> - .main should never contain uncommitted work. 
> - DO NOT commit any changes directly to the .main branch.

### Creating a New Worktree for a Branch

From inside .main:

```bash
cd ~/app-hub/repos/<repo-name>/.main
git worktree add ../feat-MyFeature -b feat/MyFeature

# Or for an existing branch:

git worktree add ../fix-Bug42 fix/Bug42
```

This creates a new directory:

```bash
~/app-hub/repos/<repo-name>/feat-MyFeature/
```

You can open this directly in VS Code or any IDE.

### Working on a Feature Branch

Each worktree is a fully isolated working directory.

Typical workflow:

```bash
cd ~/app-hub/repos/<repo-name>/feat-MyFeature

# [edit the code with your choice of IDEs and Tools]

git add .
git commit -m "Implement feature"
```

---

## ℹ️ Rebasing Feature Branches onto Updated Main

When main changes (often dozens of times per day), update your feature branch:

**Step 1: Update .main**

```bash
git fetch origin
git -C ~/app-hub/repos/<repo-name>/.main pull
```

**Step 2: Rebase your feature branch**

```bash
cd ~/app-hub/repos/<repo-name>/feat-MyFeature
git rebase ../.main
```

ℹ️ This keeps your branch aligned with the latest changes.

### Why rebase instead of merge
- Cleaner history
- Easier code review
- No merge bubbles
- Ideal for **Trunk‑Based Development (TBD)**, the modern standard practice

## Deleting a Worktree

Once a branch is merged:

```bash
cd ~/app-hub/repos/<repo-name>/.main
git worktree remove ../feat-MyFeature
git branch -d feat/MyFeature
```

💡TIP: If the folder was deleted manually:
```bash
git worktree prune
```

## Naming Conventions

Use consistent prefixes:

| Prefix | Purpose |
|--------|---------|
| feat-  | New features |
| fix-   | Bug fixes |
| lab-   | Experiments, spikes, prototypes |
| refac- | Refactoring work |

**Note the differences between the directory names and the corresponding Git branch names.** For example:

| Worktree directory name | Git branch name |
|-------------------------|-----------------|
| feat-MyFeature | **`feat/MyFeature`** |
| fix-Bug42      | **`fix/Bug42`**      |
| lab-PrototypeA | **`lab/PrototypeA`** |

## TIPS: Recommended Developer Workflow

1. Keep .main clean and updated
2. Create a worktree for each task
3. Do all work inside the worktree
4. Rebase frequently
5. Push when ready
6. Delete the worktree after merge

This supports:
- fast context switching
- multiple parallel tasks
- clean Git history
- minimal merge conflicts

## Why We Don’t Use Bare Repos

Bare repos complicate:
- IDE integration
- tooling
- path resolution
- developer onboarding

This workflow gives you the benefits of a bare repo (a clean anchor) without the drawbacks.

---

## Full Workflow Example

### Start a new feature

Create a worktree for a new feature branch:

```bash
cd ~/app-hub/repos/myrepo/.main
git pull
git worktree add ../feat-UserLogin -b feat/UserLogin
```
Work on it

```bash
cd ../feat-UserLogin

# or 

code ../feat-UserLogin
```

### Regularly fetch and rebase your local main repo while your branch is in progress
This ensures your branch stays up to date with the latest changes from main, minimizing merge conflicts and keeping your work aligned with the current codebase.

```bash
git fetch origin
git -C ../.main pull
git rebase ../.main
```

### Push your changes before opening a Pull Request

```bash
git push --set-upstream origin feat/UserLogin
```

### After Pull Request is merged, clean up your worktree

```bash
git worktree remove ../feat-UserLogin
git branch -d feat/UserLogin
```

# Summary

This workflow is:
- simple
- scalable
- IDE‑friendly
- perfect for teams juggling many products and clients
- optimized for trunk‑based development
- easy to teach and easy to adopt

It keeps your local environment clean, your branches organized, and your development velocity high.