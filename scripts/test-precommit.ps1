#!/usr/bin/env powershell
<#
.SYNOPSIS
    Pre-commit validation tests for Mello-Workspace
    
.DESCRIPTIO
    Validates AutoHotkey v2.0 code quality and consistency before commits.
    Run via git pre-commit hook or manually.

.PARAMETER Strict
    Exit with error code 1 if any warnings are found (not just errors).

.EXAMPLE
    ./scripts/test-precommit.ps1
    ./scripts/test-precommit.ps1 -Strict
#>

param(
    [switch]$Strict,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$errors = @()
$warnings = @()

# Helper Functions

function Test-RequiresHeader {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -First 1 -ErrorAction SilentlyContinue
    if ($content -notmatch '#Requires AutoHotkey v2') {
        return $false
    }
    return $true
}

function Test-PascalCaseFunction {
    param([string]$FunctionName)
    
    # Check if function name starts with capital letter
    if ($FunctionName -match '^[A-Z][a-zA-Z0-9]*$') {
        return $true
    }
    return $false
}

function Test-FunctionDefinitions {
    param([string]$FilePath)
    
    $violations = @()
    $content = Get-Content $FilePath -Raw
    
    # Match AHK v2.0 function definitions: FunctionName(params) {
    $functionMatches = [regex]::Matches($content, '^\s*(\w+)\s*\([^)]*\)\s*\{', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
    foreach ($match in $functionMatches) {
        $funcName = $match.Groups[1].Value
        # Skip built-in AHK functions and callback functions (starting with underscore)
        if ($funcName -notmatch '^[A-Z]' -and -not $funcName.StartsWith('_')) {
            $violations += $funcName
        }
    }
    
    return $violations
}

function Test-HardcodedPaths {
    param([string]$FilePath)
    
    $violations = @()
    $content = Get-Content $FilePath -Raw
    
    # Look for absolute paths that would break the installer
    # Common patterns: C:\, D:\, C:/, etc.
    if ($content -match '[C-Z]:\\' -or $content -match '[C-Z]:/') {
        # Check if it's not in a comment
        $lines = Get-Content $FilePath | Select-Object -Property @{Name='LineNum'; Expression={$_}}, @{Name='Text'; Expression={$_}}
        $lineNum = 0
        foreach ($line in Get-Content $FilePath) {
            $lineNum++
            if ($line -match '[C-Z]:\\' -and $line -notmatch '^\s*;') {
                $violations += "Line $lineNum`: $line"
            }
        }
    }
    
    return $violations
}

function Test-IsExcludedWindowUsage {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    
    # Check if file touches windows but doesn't validate with IsExcludedWindow()
    $hasWindowOps = $content -match 'WinMove|WinResize|WinActivate|WinMaximize|WinMinimize|WinSetStyle'
    $hasExcludedCheck = $content -match 'IsExcludedWindow'
    
    if ($hasWindowOps -and -not $hasExcludedCheck) {
        return $true
    }
    return $false
}

# Test 1: #Requires Header Validation

Write-Host "`n[TEST 1] Checking #Requires headers..." -ForegroundColor Cyan

Get-ChildItem -Path 'lib' -Filter '*.ahk' -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not (Test-RequiresHeader $_.FullName)) {
        $errors += "$($_.Name): Missing or invalid #Requires AutoHotkey v2.0 header"
    }
}

# Main script should also have #Requires
if (-not (Test-RequiresHeader 'Mello-Workspace.ahk')) {
    $errors += "Mello-Workspace.ahk: Missing or invalid #Requires AutoHotkey v2.0 header"
}

if ($errors.Count -eq 0) {
    Write-Host "  [OK] All .ahk files have valid #Requires headers" -ForegroundColor Green
}

# Test 2: #SingleInstance Check

Write-Host "`n[TEST 2] Checking #SingleInstance directive..." -ForegroundColor Cyan

$mainContent = Get-Content 'Mello-Workspace.ahk' -Raw
if ($mainContent -notmatch '#SingleInstance') {
    $errors += "Mello-Workspace.ahk: Missing #SingleInstance directive"
} else {
    Write-Host "  [OK] #SingleInstance found in main script" -ForegroundColor Green
}

# Test 3: Function Naming Conventions (PascalCase)

Write-Host "`n[TEST 3] Checking function naming conventions (PascalCase)..." -ForegroundColor Cyan

$nameViolations = 0
Get-ChildItem -Path 'lib' -Filter '*.ahk' -ErrorAction SilentlyContinue | ForEach-Object {
    $badFuncs = Test-FunctionDefinitions $_.FullName
    if ($badFuncs.Count -gt 0) {
        $badFuncs | ForEach-Object {
            $warnings += "$($_.FullName): Function '$_' does not use PascalCase convention"
        }
        $nameViolations++
    }
}

# Check custom functions if they exist
if (Test-Path 'custom/_custom_functions.ahk') {
    $badFuncs = Test-FunctionDefinitions 'custom/_custom_functions.ahk'
    if ($badFuncs.Count -gt 0) {
        $badFuncs | ForEach-Object {
            $warnings += "custom/_custom_functions.ahk: Function '$_' does not use PascalCase convention"
        }
    }
}

if ($nameViolations -eq 0) {
    Write-Host "  [OK] All user-defined functions follow PascalCase convention" -ForegroundColor Green
}

# Test 4: Hardcoded Path Detection

Write-Host "`n[TEST 4] Checking for hardcoded absolute paths..." -ForegroundColor Cyan

Get-ChildItem -Path 'lib' -Filter '*.ahk' -ErrorAction SilentlyContinue | ForEach-Object {
    $pathViolations = Test-HardcodedPaths $_.FullName
    if ($pathViolations.Count -gt 0) {
        $pathViolations | ForEach-Object {
            $errors += "$($_.FullName): $_"
        }
    }
}

# Check custom folder
if (Test-Path 'custom') {
    Get-ChildItem -Path 'custom' -Filter '*.ahk' | ForEach-Object {
        $pathViolations = Test-HardcodedPaths $_.FullName
        if ($pathViolations.Count -gt 0) {
            $pathViolations | ForEach-Object {
                $errors += "$($_.FullName): $_"
            }
        }
    }
}

$hardcodedErrors = $errors | Where-Object { $_ -match 'hardcoded' }
if ($hardcodedErrors.Count -eq 0) {
    Write-Host "  [OK] No hardcoded absolute paths detected" -ForegroundColor Green
}

# Test 5: Window Management Safety Check

Write-Host "`n[TEST 5] Checking window management safety (IsExcludedWindow usage)..." -ForegroundColor Cyan

$windowSafetyIssues = 0
Get-ChildItem -Path 'lib' -Filter '*.ahk' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'winui|window|mgmt' } | ForEach-Object {
    if (Test-IsExcludedWindowUsage $_.FullName) {
        $warnings += "$($_.Name): Uses window operations but IsExcludedWindow() check may be missing"
        $windowSafetyIssues++
    }
}

if ($windowSafetyIssues -eq 0) {
    Write-Host "  [OK] Window management code appears safe" -ForegroundColor Green
}

# Test 6: Critical Settings Check

Write-Host "`n[TEST 6] Checking critical global settings..." -ForegroundColor Cyan

$mainContent = Get-Content 'Mello-Workspace.ahk' -Raw
$settingChecks = @{
    'SendMode' = 'SendMode\s+"Input"'
    'SetTitleMatchMode' = 'SetTitleMatchMode'
}

$settingsFound = 0
foreach ($setting in $settingChecks.GetEnumerator()) {
    if ($mainContent -match $setting.Value) {
        $settingsFound++
    }
}

if ($settingsFound -gt 0) {
    Write-Host "  [OK] Found $settingsFound critical settings" -ForegroundColor Green
}

# Test 7: Include Consistency Check

Write-Host "`n[TEST 7] Checking library includes..." -ForegroundColor Cyan

$mainContent = Get-Content 'Mello-Workspace.ahk' -Raw
$libFiles = Get-ChildItem -Path 'lib' -Filter '*.ahk' | Where-Object { $_.Name -notmatch '^help_about' }

$includeMatches = $mainContent | Select-String -Pattern '#Include' -AllMatches
$includeCount = if ($includeMatches) { $includeMatches.Matches.Count } else { 0 }
$libCount = $libFiles.Count

Write-Host "  Found $includeCount #Include directives" -ForegroundColor Gray
Write-Host "  Found $libCount lib files (excluding help files)" -ForegroundColor Gray

if ($includeCount -lt $libCount) {
    $warnings += "Mello-Workspace.ahk: Possible missing #Include directives for library files"
}

# Summary & Exit Code

Write-Host "`n================================================================"
Write-Host "TEST SUMMARY" -ForegroundColor Cyan

if ($errors.Count -gt 0) {
    Write-Host "`nERRORS ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  * $_" }
}

if ($warnings.Count -gt 0) {
    Write-Host "`nWARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  * $_" }
}

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "`nAll pre-commit checks passed!" -ForegroundColor Green
    exit 0
}

if ($errors.Count -gt 0) {
    Write-Host "`nPre-commit validation FAILED - commit aborted" -ForegroundColor Red
    exit 1
}

if ($Strict -and $warnings.Count -gt 0) {
    Write-Host "`nStrict mode enabled - warnings treated as errors" -ForegroundColor Yellow
    exit 1
}

if ($warnings.Count -gt 0) {
    Write-Host "`nPre-commit validation completed with warnings" -ForegroundColor Yellow
    exit 0
}
