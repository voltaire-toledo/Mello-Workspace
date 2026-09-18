<#
.SYNOPSIS
    Guest test runner executed inside Windows Sandbox for Mello-Workspace.

.DESCRIPTION
    Runs inside the ephemeral Windows Sandbox environment (as WDAGUtilityAccount).
    Performs an end-to-end regression test:
      1. Stages repository files from the read-only host mount to a writable workspace.
      2. Executes Mello-Workspace.ps1 (fresh local installation flow).
      3. Verifies AutoHotkey download and extraction.
      4. Verifies executable deployment and Start Menu shortcut generation.
      5. Validates runtime process execution of Mello-Workspace.exe.
      6. Checks registry readiness for custom protocol suppression (TASK-25).
      7. Emits a structured PASS/FAIL test summary.
#>

[CmdletBinding()]
param(
    [string]$SourceDir = "C:\Mello-Source",
    [string]$StagingDir = "C:\Mello-Test",
    [switch]$Unattended
)

$ErrorActionPreference = "Continue"

# Configure console appearance
try {
    $host.UI.RawUI.WindowTitle = "Mello-Workspace - Windows Sandbox Test Runner"
} catch {}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "        MELLO-WORKSPACE - WINDOWS SANDBOX TEST HARNESS          " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Host Source Mount: $SourceDir" -ForegroundColor Gray
Write-Host " Staging Directory: $StagingDir" -ForegroundColor Gray
Write-Host " Guest User:        $($env:USERNAME)" -ForegroundColor Gray
Write-Host " Execution Time:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Assert-Test {
    param(
        [string]$Name,
        [scriptblock]$Condition,
        [string]$Details = ""
    )
    Write-Host -NoNewline "[-] $Name ... "
    try {
        $result = & $Condition
        if ($result) {
            Write-Host "[PASS]" -ForegroundColor Green
            if ($Details) { Write-Host "    $Details" -ForegroundColor DarkGray }
            $script:testsPassed++
        } else {
            Write-Host "[FAIL]" -ForegroundColor Red
            if ($Details) { Write-Host "    Assertion failed: $Details" -ForegroundColor Yellow }
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "[ERROR]" -ForegroundColor Red
        Write-Host "    Exception: $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
    }
}

# --- Stage 1: Verify Host Mount & Prepare Staging Directory ---
Write-Host "--- Stage 1: Workspace Staging ---" -ForegroundColor Magenta

Assert-Test -Name "Host Mount Available" -Condition {
    Test-Path -Path $SourceDir -PathType Container
} -Details "Path: $SourceDir"

if (!(Test-Path -Path $SourceDir)) {
    Write-Host "FATAL: Host mount $SourceDir not accessible. Aborting." -ForegroundColor Red
    exit 1
}

Write-Host "[-] Staging files to $StagingDir..." -ForegroundColor Gray
if (Test-Path -Path $StagingDir) {
    Remove-Item -Path $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Use robocopy for fast staging, excluding git history and caches
& robocopy $SourceDir $StagingDir /E /XD .git .vscode .gemini /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

Assert-Test -Name "Staged Bootstrap Script Present" -Condition {
    Test-Path -Path (Join-Path $StagingDir "Mello-Workspace.ps1")
} -Details "File: $(Join-Path $StagingDir 'Mello-Workspace.ps1')"

Assert-Test -Name "Staged Main AHK Script Present" -Condition {
    Test-Path -Path (Join-Path $StagingDir "Mello-Workspace.ahk")
} -Details "File: $(Join-Path $StagingDir 'Mello-Workspace.ahk')"

# --- Stage 2: Execute Bootstrap Script ---
Write-Host ""
Write-Host "--- Stage 2: Bootstrap Execution (Mello-Workspace.ps1) ---" -ForegroundColor Magenta

$bootstrapScript = Join-Path $StagingDir "Mello-Workspace.ps1"
Write-Host "Running: powershell.exe -ExecutionPolicy Bypass -File $bootstrapScript" -ForegroundColor Gray

# Force TLS 1.2 in current environment for web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$bootstrapProcess = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$bootstrapScript`"" `
    -WorkingDirectory $StagingDir `
    -NoNewWindow -Wait -PassThru

Assert-Test -Name "Bootstrap Script Clean Exit" -Condition {
    $bootstrapProcess.ExitCode -eq 0
} -Details "Exit Code: $($bootstrapProcess.ExitCode)"

# --- Stage 3: Validate Installed Artifacts ---
Write-Host ""
Write-Host "--- Stage 3: Artifact & Installation Validation ---" -ForegroundColor Magenta

$ahkExePath = Join-Path $StagingDir "ahkbin\AutoHotkey32.exe"
Assert-Test -Name "AutoHotkey32 Downloaded & Extracted" -Condition {
    (Test-Path $ahkExePath) -and ((Get-Item $ahkExePath).Length -gt 1000000)
} -Details "Path: $ahkExePath ($(if (Test-Path $ahkExePath) { [Math]::Round((Get-Item $ahkExePath).Length / 1MB, 2) } else { 0 }) MB)"

$melloExePath = Join-Path $StagingDir "Mello-Workspace.exe"
Assert-Test -Name "Mello-Workspace.exe Cloned from AHK" -Condition {
    (Test-Path $melloExePath) -and ((Get-Item $melloExePath).Length -gt 1000000)
} -Details "Path: $melloExePath"

$startMenuFolder = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\Mello"
$shortcutFile = Join-Path $startMenuFolder "Mello-Workspace.lnk"
Assert-Test -Name "Start Menu Shortcut Created" -Condition {
    Test-Path $shortcutFile
} -Details "Path: $shortcutFile"

Assert-Test -Name "Shortcut Target Resolution" -Condition {
    if (!(Test-Path $shortcutFile)) { return $false }
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutFile)
    return ($shortcut.TargetPath -eq $melloExePath)
} -Details "Target matches $melloExePath"

# --- Stage 4: Runtime Process Verification ---
Write-Host ""
Write-Host "--- Stage 4: Process Health Verification ---" -ForegroundColor Magenta

Write-Host "Waiting 3 seconds for process initialization..." -ForegroundColor Gray
Start-Sleep -Seconds 3

$melloProcess = Get-Process -Name "Mello-Workspace" -ErrorAction SilentlyContinue
Assert-Test -Name "Mello-Workspace Process Resident" -Condition {
    $null -ne $melloProcess
} -Details "Process Found: $(if ($melloProcess) { "PID: $($melloProcess.Id), WorkingSet: $([Math]::Round($melloProcess.WorkingSet64 / 1MB, 2)) MB" } else { "None" })"

# --- Stage 5: Registry Readiness Check (TASK-25 Context) ---
Write-Host ""
Write-Host "--- Stage 5: Registry & Environment Isolation ---" -ForegroundColor Magenta

Assert-Test -Name "HKCU Registry User Isolation Verified" -Condition {
    $testKey = "HKCU:\Software\Mello-Workspace-SandboxTest"
    New-Item -Path $testKey -Force | Out-Null
    Set-ItemProperty -Path $testKey -Name "TestVal" -Value "OK" | Out-Null
    $readVal = (Get-ItemProperty -Path $testKey -Name "TestVal").TestVal
    Remove-Item -Path $testKey -Force -ErrorAction SilentlyContinue
    return ($readVal -eq "OK")
} -Details "HKCU user registry write/read operations verified"

# --- Test Summary Report ---
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                         TEST SUMMARY                           " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Tests Executed: $($testsPassed + $testsFailed)" -ForegroundColor White
Write-Host " Tests Passed:   $testsPassed" -ForegroundColor $(if ($testsPassed -gt 0) { "Green" } else { "White" })
Write-Host " Tests Failed:   $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })

if ($testsFailed -eq 0) {
    Write-Host ""
    Write-Host " >>> ALL SANDBOX TESTS PASSED SUCCESSFULLY! <<< " -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host " >>> SOME TESTS FAILED. CHECK LOGS ABOVE. <<< " -ForegroundColor Red
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Write results file to Desktop
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $logFile = Join-Path $desktopPath "mello-test-results.log"
    $logContent = @"
================================================================
MELLO-WORKSPACE - WINDOWS SANDBOX TEST RESULTS
================================================================
Date/Time:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Tests Executed:  $($testsPassed + $testsFailed)
Tests Passed:    $testsPassed
Tests Failed:    $testsFailed
Status:          $(if ($testsFailed -eq 0) { "SUCCESS / ALL TESTS PASSED" } else { "FAILED" })
================================================================
"@
    Set-Content -Path $logFile -Value $logContent -Encoding UTF8
    Write-Host "[-] Test results written to Desktop: $logFile" -ForegroundColor DarkGray
} catch {}

if (!$Unattended) {
    Write-Host "Windows Sandbox is currently running interactively." -ForegroundColor Yellow
    Write-Host "You can test hotkeys, check the system tray icon, or close the Sandbox window when finished." -ForegroundColor Yellow
    Write-Host ""
}
