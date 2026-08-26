<#
.SYNOPSIS
    Script to create a Start Menu shortcut for Mello-Workspace and ensure AutoHotkey is downloaded and configured.

.DESCRIPTION
    This script downloads AutoHotkey, creates a Start Menu folder, and generates a shortcut to launch Mello-Workspace.
    It includes error handling and modularized functions for better maintainability.

.NOTES
    Compatible with PowerShell 5.1 and later.
#>

#region Configuration
$ThisAppName = 'Mello-Workspace'
$InstallDir = Join-Path $env:LOCALAPPDATA $ThisAppName
$ShortcutName = "$ThisAppName.lnk"
$ShortcutDisplayName = "Mello-Workspace"
$ShortcutExecutableName = "$ThisAppName.exe"
$AHKExecutableName = "AutoHotkey32.exe"
$AHKBinPath = Join-Path -Path $InstallDir -ChildPath "ahkbin"
$Arguments = Join-Path -Path $InstallDir -ChildPath "$ThisAppName.ahk"
$Description = "Start $ThisAppName"
$IconPath = Join-Path -Path $InstallDir -ChildPath "assets\icons\$ThisAppName.ico"
$StartMenuFolderName = "Mello"
$AHKZipUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.19/AutoHotkey_2.0.19.zip"
$AHKZipPath = Join-Path -Path $InstallDir -ChildPath "AutoHotkey.zip"
$RepoZipUrl = "https://github.com/voltaire-toledo/Mello-Workspace.Local/archive/refs/heads/main.zip"
$RepoZipPath = Join-Path $env:TEMP "$ThisAppName-main.zip"
$TempExtractPath = Join-Path $env:TEMP "$ThisAppName-extract"
$StartMenuPath = [Environment]::GetFolderPath("StartMenu")
$StartMenuProgramsPath = Join-Path -Path $StartMenuPath -ChildPath "Programs"
$StartMenuFolderPath = Join-Path -Path $StartMenuProgramsPath -ChildPath $StartMenuFolderName
$ShortcutPath = Join-Path -Path $StartMenuFolderPath -ChildPath $ShortcutName
$TargetPath = Join-Path -Path $InstallDir -ChildPath $ShortcutExecutableName
$isRunFromUrl = $false
#endregion

#region Helper Functions
function New-Directory {
  # ╭───────────────────────────────────────────────────────╮
  # │ Function: New-Directory                               │
  # | General Create-Directory function with error handling │
  # ╰───────────────────────────────────────────────────────╯
  [CmdletBinding(SupportsShouldProcess = $true)]
  param([string] $Path)
  if ($PSCmdlet.ShouldProcess("Creating directory at $Path")) {
    if (!(Test-Path -Path $Path -PathType Container)) {
      try {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Verbose "Created directory: $Path"
      }
      catch {
        Write-Error "Failed to create directory ${Path}:  $($_.Exception.Message)"
        return $false
      }
    }
    return $true
  }
}

function Get-AutoHotkey {
  # ╭─────────────────────────────────────────────────────╮
  # │ Function: Get-AutoHotkey                            │
  # | Download and extract an approved AutoHotkey version │
  # ╰─────────────────────────────────────────────────────╯
  if (!(New-Directory -Path $AHKBinPath)) {
    return $false
  }
    Write-Verbose "Downloading AutoHotkey..."
  try {
    # Force strong TLS
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # Downloaded from GitHub Releases (not autohotkey.com) — github.com is
        # near-universally allow-listed in locked-down/enterprise environments,
        # sidestepping per-domain trust/categorization issues. No Host header
        # override here: that was specific to the old autohotkey.com workaround
        # and is unnecessary (and can look like header manipulation to
        # SSL-inspecting proxies).
        $headers = @{ "User-Agent" = "curl/8.14.1"; "Accept" = "*/*" }
        Invoke-WebRequest -Uri $AHKZipUrl -Headers $headers -OutFile $AHKZipPath -ErrorAction Stop
        Expand-Archive -Path $AHKZipPath -DestinationPath $AHKBinPath -Force
        Remove-Item -Path $AHKZipPath -Force
        Write-Verbose "AutoHotkey downloaded and extracted to '$AHKBinPath'."
        return $true
    }
    catch {
        $errorDetail = $_.Exception.Message
        $resp = $_.Exception.Response
        if ($resp) {
            try {
                $stream = $resp.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $errorDetail += " | Response body (first 500 chars): $($body.Substring(0, [Math]::Min(500, $body.Length)))"
            } catch {
                # best-effort diagnostics only; don't let this mask the original error
            }
        }
        Write-Error "Failed to download or extract AutoHotkey: $errorDetail"
        return $false
    }
}

function New-Backup {
  param([string] $InstallDir)
  try {
    if (!(Test-Path -Path $InstallDir)) { return $null }

    $date = Get-Date -Format yyyyMMdd
    $index = 1
    do {
      $backupName = "backup-$date" + "_${index}"
      $backupPath = Join-Path -Path $InstallDir -ChildPath $backupName
      $index++
    } while (Test-Path -Path $backupPath)

    $children = Get-ChildItem -Path $InstallDir -Force -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    foreach ($child in $children) {
      if ($child.FullName -eq $backupPath) { continue }
      try {
        Move-Item -Path $child.FullName -Destination $backupPath -Force -ErrorAction Stop
      }
      catch {
        try {
          Copy-Item -Path $child.FullName -Destination $backupPath -Recurse -Force -ErrorAction Stop
          Remove-Item -Path $child.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
          Write-Host "Failed to move or copy item '$($child.FullName)' to backup: $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }

    return $backupPath
  }
  catch {
    Write-Error "Failed to create backup: $($_.Exception.Message)"
    return $null
  }
}

function Copy-AHKExecutable {
  # ╭─────────────────────────────────────────────────────────────────╮
  # │ Function: Copy-AHKExecutable                                    │
  # │ Copy AutoHotkey executable to InstallDir as Mello-Workspace.exe │
  # ╰─────────────────────────────────────────────────────────────────╯
  param(
    [string] $AHKBinPath,
    [string] $InstallDir,
    [string] $AHKExecutableName,
    [string] $ShortcutExecutableName
  )
  try {
    $sourceExe = Join-Path -Path $AHKBinPath -ChildPath $AHKExecutableName
    $destExe = Join-Path -Path $InstallDir -ChildPath $ShortcutExecutableName
    Copy-Item -Path $sourceExe -Destination $destExe -Force
    Write-Host "Copied $AHKExecutableName to $ShortcutExecutableName" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "Failed to copy AutoHotkey executable: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function New-Shortcut {
  # ╭─────────────────────────────────────────────────╮
  # │ Function: New-Shortcut                          │
  # | Creates a shortcut to a target file or folder.  │
  # ╰─────────────────────────────────────────────────╯
  param(
    [string] $ShortcutPath,
    [string] $TargetPath,
    [string] $Arguments,
    [string] $Description,
    [string] $WorkingDirectory,
    [string] $IconPath,
    [string] $ShortcutDisplayName
  )
  try {
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Arguments = $Arguments
    $Shortcut.Description = $Description
    $Shortcut.WorkingDirectory = $WorkingDirectory
    $Shortcut.IconLocation = $IconPath
    $Shortcut.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Shell)
    if (Get-Variable Shell -ErrorAction SilentlyContinue) { Remove-Variable Shell }
  }
  catch {
    Write-Host "Failed to create shortcut: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
  Write-Host "Shortcut created at '$ShortcutPath'." -ForegroundColor Green
  return $true
}
#endregion

#region Main Logic Functions

function Install-FromUrl {
  # ╭───────────────────────────╮
  # │ Function: Install-FromUrl │
  # | Perform the installation  │
  # ╰───────────────────────────╯
  # Ensure install directory exists and back up existing contents if present, then copy repo contents
  if (!(Test-Path -Path $InstallDir)) {
    if (!(New-Directory -Path $InstallDir)) {
      Write-Host "Failed to create install directory. Exiting script." -ForegroundColor Red
      exit 1
    }
  }

  Write-Verbose "Preparing to download repository and replace contents of $InstallDir..."
  try {
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $RepoZipPath -ErrorAction Stop
    if (Test-Path $TempExtractPath) { Remove-Item $TempExtractPath -Recurse -Force }
    Expand-Archive -Path $RepoZipPath -DestinationPath $TempExtractPath -Force
    $SourceFolder = Join-Path $TempExtractPath "$ThisAppName-main"

    if (Test-Path -Path $InstallDir) {
      Write-Host "Install directory already exists. Creating backup of current contents..." -ForegroundColor Magenta
      $backupPath = New-Backup -InstallDir $InstallDir
      if ($backupPath) { Write-Host "Backup created at: $backupPath" -ForegroundColor Green}
      else { Write-Warning "Backup failed or skipped." -ForegroundColor Magenta}
    }

    Write-Verbose "Copying new files to $InstallDir..."
    Copy-Item -Path (Join-Path $SourceFolder '*') -Destination $InstallDir -Recurse -Force
    Remove-Item $RepoZipPath -Force
    Remove-Item $TempExtractPath -Recurse -Force
    Write-Verbose "Files copied to $InstallDir."
    # If the user hasn't created a custom functions file, duplicate the example into place
    try {
      $customDir = Join-Path -Path $InstallDir -ChildPath "custom"
      $exampleFile = Join-Path -Path $customDir -ChildPath "_custom_functions.ahk.example"
      $customFile = Join-Path -Path $customDir -ChildPath "_custom_functions.ahk"
      if (!(Test-Path -Path $customFile) -and (Test-Path -Path $exampleFile)) {
        Write-Host "Creating user custom file from example: $customFile" -ForegroundColor Cyan
        Copy-Item -Path $exampleFile -Destination $customFile -Force
      }
    }
    catch {
      Write-Host "Failed to create custom file from example: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
  catch {
    Write-Host "Failed to copy files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }

  # Ensure AutoHotkey is downloaded and extracted.
  if (!(Test-Path -Path (Join-Path $AHKBinPath $AHKExecutableName))) {
    if (!(Get-AutoHotkey)) {
      Write-Host "Failed to set up AutoHotkey. Exiting script." -ForegroundColor Red
      exit 1
    }
    Write-Host "AutoHotkey set up successfully." -ForegroundColor Green
  }

  # Ensure Mello-Workspace.exe (a copy of AutoHotkey32.exe) is in place.
  if (!(Test-Path -Path $TargetPath)) {
    if (!(Copy-AHKExecutable -AHKBinPath $AHKBinPath -InstallDir $InstallDir -AHKExecutableName $AHKExecutableName -ShortcutExecutableName $ShortcutExecutableName)) {
      exit 1
    }
  }

  # Ensure the Start Menu folder exists.
  if (!(New-Directory -Path $StartMenuFolderPath)) {
    Write-Host "Failed to create Start Menu folder. Using Start Menu root instead." -ForegroundColor Magenta
    $StartMenuFolderPath = $StartMenuPath
  }

  # Create the shortcut.
  if (!(New-Shortcut -ShortcutPath $ShortcutPath -TargetPath $TargetPath -Arguments $Arguments -Description $Description -WorkingDirectory $InstallDir -IconPath $IconPath -ShortcutDisplayName $ShortcutDisplayName)) {
    Write-Host "Failed to create the shortcut. Exiting script." -ForegroundColor Red
    exit 1
  }
}

function Run-FromLocal {
  Write-Host "Running from local copy. Using current directory as install directory." -ForegroundColor Cyan

  # Set InstallDir to the script's current directory for local execution
  $InstallDir = $PSScriptRoot
  $AHKBinPath = Join-Path -Path $InstallDir -ChildPath "ahkbin"
  $AHKZipPath = Join-Path -Path $InstallDir -ChildPath "AutoHotkey.zip"
  $Arguments = Join-Path -Path $InstallDir -ChildPath "$ThisAppName.ahk"
  $IconPath = Join-Path -Path $InstallDir -ChildPath "assets\icons\$ThisAppName.ico"
  $TargetPath = Join-Path -Path $InstallDir -ChildPath $ShortcutExecutableName

  # Ensure AutoHotkey is downloaded and extracted to the local ahkbin.
  if (!(Test-Path -Path (Join-Path $AHKBinPath $AHKExecutableName))) {
    if (!(Get-AutoHotkey)) {
      Write-Host "Failed to set up AutoHotkey for local run. Exiting script." -ForegroundColor Red
      exit 1
    }
    Write-Host "AutoHotkey set up successfully for local run." -ForegroundColor Green
  }

  # Ensure Mello-Workspace.exe (a copy of AutoHotkey32.exe) is in place before launching.
  if (!(Test-Path -Path $TargetPath)) {
    if (!(Copy-AHKExecutable -AHKBinPath $AHKBinPath -InstallDir $InstallDir -AHKExecutableName $AHKExecutableName -ShortcutExecutableName $ShortcutExecutableName)) {
      exit 1
    }
  }

  # Ensure the Start Menu folder exists.
  if (!(New-Directory -Path $StartMenuFolderPath)) {
    Write-Host "Failed to create Start Menu folder. Using Start Menu root instead." -ForegroundColor Magenta
    $StartMenuFolderPath = $StartMenuPath
  }

  # Remove old shortcuts and create a new one.
  Write-Host "Refreshing shortcuts in $StartMenuFolderPath..." -ForegroundColor Cyan
  if (Test-Path -Path $StartMenuFolderPath) {
    Get-ChildItem -Path $StartMenuFolderPath -Filter "$ThisAppName*.lnk" | Remove-Item -Force
  }

  if (!(New-Shortcut -ShortcutPath $ShortcutPath -TargetPath $TargetPath -Arguments $Arguments -Description $Description -WorkingDirectory $InstallDir -IconPath $IconPath -ShortcutDisplayName $ShortcutDisplayName)) {
    Write-Host "Failed to create the shortcut. Exiting script." -ForegroundColor Red
    exit 1
  }

  try {
    Start-Process -FilePath $ShortcutPath
    Write-Host "Shortcut '$ShortcutDisplayName' started." -ForegroundColor Green
    Write-Host "NOTE: If the script does not launch, you may need to unblock the $($TargetPath) file" -ForegroundColor Magenta
  }
  catch {
    Write-Host "Failed to start the shortcut: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
}
#endregion

#region Main()
# Determine if the script was invoked from a URL or from a file.
 $isRunFromUrl = ($null -eq $MyInvocation.MyCommand.Path -or $MyInvocation.MyCommand.Path -eq '-')
 if ($isRunFromUrl) {
   Write-Host "$MyInvocation.MyCommand.Path is null or empty. Assuming script is run from URL." -ForegroundColor Green
   Install-FromUrl
 } else {
   Run-FromLocal
 }
#endregion
