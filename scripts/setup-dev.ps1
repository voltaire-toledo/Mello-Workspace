<#
.SYNOPSIS
    Configures local development settings for this repository.

.DESCRIPTION
    Git does not track .git/hooks, so this script points the local checkout at
    the repo-tracked .githooks directory.
#>

$ErrorActionPreference = "Stop"

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    throw "Unable to determine repository root."
}

$hooksPath = Join-Path $repoRoot ".githooks"
if (-not (Test-Path -Path $hooksPath -PathType Container)) {
    throw "Hooks directory not found: $hooksPath"
}

git config core.hooksPath .githooks

Write-Host "Configured Git hooks path: .githooks" -ForegroundColor Green
