#!/usr/bin/env powershell
<#
.SYNOPSIS
    Host launcher for Mello-Workspace automated tests in Windows Sandbox.

.DESCRIPTION
    Verifies that Windows Sandbox is available on the host, dynamically generates
    a `.wsb` configuration file mapped to the current repository or worktree,
    and boots an isolated, ephemeral Windows Sandbox VM to execute end-to-end
    installation, artifact, and regression tests.

.PARAMETER WorkspaceRoot
    Root directory of the repository or worktree to mount. Defaults to repo root.

.PARAMETER NoLaunch
    Generate the `.wsb` configuration file without launching Windows Sandbox.

.PARAMETER Unattended
    Configures guest runner to exit after test completion instead of keeping console open.

.PARAMETER MemoryMB
    Memory in megabytes allocated to the sandbox VM (default: 4096).

.EXAMPLE
    ./scripts/test-sandbox.ps1
    ./scripts/test-sandbox.ps1 -NoLaunch
    ./scripts/test-sandbox.ps1 -MemoryMB 8192
#>

[CmdletBinding()]
param(
    [string]$WorkspaceRoot = "",
    [switch]$NoLaunch,
    [switch]$Unattended,
    [int]$MemoryMB = 4096
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "    MELLO-WORKSPACE - WINDOWS SANDBOX TEST HARNESS LAUNCHER     " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Resolve Workspace Root
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $WorkspaceRoot = (Resolve-Path $WorkspaceRoot).Path
}

Write-Host "[-] Workspace Root: $WorkspaceRoot" -ForegroundColor Gray

# Verify critical guest files exist
$guestRunnerPath = Join-Path $WorkspaceRoot "tests\sandbox\guest-runner.ps1"
if (!(Test-Path $guestRunnerPath)) {
    Write-Error "Guest runner not found at: $guestRunnerPath"
    exit 1
}

# 2. Check Windows Sandbox Capability
$sandboxExe = "C:\Windows\System32\WindowsSandbox.exe"
$sandboxCmd = Get-Command WindowsSandbox.exe -ErrorAction SilentlyContinue

if ($sandboxCmd) {
    $sandboxExe = $sandboxCmd.Source
} elseif (!(Test-Path $sandboxExe)) {
    Write-Host ""
    Write-Host "[ERROR] Windows Sandbox executable not found!" -ForegroundColor Red
    Write-Host "To enable Windows Sandbox on Windows 11 Enterprise/Pro, run in an elevated PowerShell:" -ForegroundColor Yellow
    Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "[-] Sandbox Executable: $sandboxExe" -ForegroundColor Gray

# 3. Check Hyper-V Host Compute Service (vmcompute)
$vmCompute = Get-Service vmcompute -ErrorAction SilentlyContinue
if ($vmCompute) {
    Write-Host "[-] Compute Service (vmcompute): $($vmCompute.Status)" -ForegroundColor Gray
    if ($vmCompute.Status -ne 'Running') {
        Write-Host "[WARN] 'vmcompute' service is not currently running. Windows Sandbox will attempt to start it." -ForegroundColor Yellow
    }
}

# 4. Generate .wsb Configuration
$wsbDir = Join-Path $WorkspaceRoot "tests\sandbox"
if (!(Test-Path $wsbDir)) {
    New-Item -ItemType Directory -Path $wsbDir -Force | Out-Null
}

$wsbFile = Join-Path $wsbDir "mello-sandbox.wsb"

$logonArgs = "-ExecutionPolicy Bypass -NoProfile "
if (!$Unattended) {
    $logonArgs += "-NoExit "
}
$logonArgs += "-File C:\Mello-Source\tests\sandbox\guest-runner.ps1"
if ($Unattended) {
    $logonArgs += " -Unattended"
}

$wsbXml = @"
<Configuration>
  <vGPU>Default</vGPU>
  <Networking>Default</Networking>
  <MemoryInMB>$MemoryMB</MemoryInMB>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$WorkspaceRoot</HostFolder>
      <SandboxFolder>C:\Mello-Source</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe $logonArgs</Command>
  </LogonCommand>
</Configuration>
"@

Set-Content -Path $wsbFile -Value $wsbXml -Encoding UTF8
Write-Host "[-] Generated Configuration: $wsbFile" -ForegroundColor Green

# 5. Launch Windows Sandbox
if ($NoLaunch) {
    Write-Host "[OK] Configuration generated. Skipped launch (-NoLaunch specified)." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host ">>> Launching Windows Sandbox... <<<" -ForegroundColor Cyan
Write-Host "The Sandbox will start in an isolated window." -ForegroundColor Gray
Write-Host "Upon boot, it will automatically stage the files, execute Mello-Workspace.ps1, and validate all acceptance criteria." -ForegroundColor Gray
Write-Host ""

try {
    $process = Start-Process -FilePath $sandboxExe -ArgumentList "`"$wsbFile`"" -PassThru
    Write-Host "[SUCCESS] Windows Sandbox process triggered (PID: $($process.Id))." -ForegroundColor Green
    Write-Host "Waiting for Sandbox VM session initialization..." -ForegroundColor Gray

    $sessionFound = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 1
        $session = Get-Process -Name "WindowsSandboxRemoteSession" -ErrorAction SilentlyContinue
        if ($session) {
            Write-Host "[SUCCESS] Active Windows Sandbox Remote Session detected (PID: $($session.Id))!" -ForegroundColor Green
            $sessionFound = $true
            break
        }
    }
    if (!$sessionFound) {
        Write-Host "[INFO] Sandbox is initializing in the background. Check your taskbar." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Monitor the guest console window inside Windows Sandbox to watch test execution." -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to launch Windows Sandbox: $($_.Exception.Message)"
    exit 1
}
