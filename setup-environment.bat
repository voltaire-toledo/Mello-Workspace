@echo off
REM Setup script for initializing the Mello Workspace build environment
REM Run this script once to set up all bare repositories and worktrees

echo ========================================
echo Mello Workspace Environment Setup
echo ========================================
echo.

REM Initialize bare repositories
echo [1/4] Initializing bare repositories...
cd bare-repos\main-system.git
git init --bare
cd ..\..

cd bare-repos\plugins.git
git init --bare
cd ..\..

cd bare-repos\scripts.git
git init --bare
cd ..\..

cd bare-repos\resources.git
git init --bare
cd ..\..

echo.
echo [2/4] Creating initial commits in bare repositories...

REM Create initial commits (optional but recommended)
echo Creating temp directory for initial commit...
mkdir temp-init 2>nul

REM Main system initial commit
cd temp-init
git init
echo # Main System > README.md
git add README.md
git commit -m "Initial commit"
git remote add origin ../bare-repos/main-system.git
git push origin master:main
cd ..

REM Plugins initial commit
cd temp-init
git init
echo # Plugins > README.md
git add README.md
git commit -m "Initial commit"
git remote add origin ../bare-repos/plugins.git
git push origin master:main
cd ..

REM Scripts initial commit
cd temp-init
git init
echo # Scripts > README.md
git add README.md
git commit -m "Initial commit"
git remote add origin ../bare-repos/scripts.git
git push origin master:main
cd ..

REM Resources initial commit
cd temp-init
git init
echo # Resources > README.md
git add README.md
git commit -m "Initial commit"
git remote add origin ../bare-repos/resources.git
git push origin master:main
cd ..

REM Clean up temp directory
rd /s /q temp-init

echo.
echo [3/4] Creating worktrees...

REM Create worktrees
git --git-dir=bare-repos/main-system.git worktree add worktrees/main-system main
git --git-dir=bare-repos/plugins.git worktree add worktrees/plugins main
git --git-dir=bare-repos/scripts.git worktree add worktrees/scripts main
git --git-dir=bare-repos/resources.git worktree add worktrees/resources main

echo.
echo [4/4] Creating build output directories...

REM Create build output subdirectories
mkdir build-output\main-system 2>nul
mkdir build-output\plugins 2>nul
mkdir build-output\scripts 2>nul
mkdir build-output\resources 2>nul

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo You can now start developing in the worktrees/ directory.
echo Build outputs will be placed in build-output/ directory.
echo.

pause
