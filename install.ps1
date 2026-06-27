<# 
.SYNOPSIS
    Install gf (Simple Gitflow Helper PowerShell) on Windows
.DESCRIPTION
    Detects existing installations, checks prerequisites, configures your
    PowerShell profile, and sets the execution policy — all interactively.
#>

$ErrorActionPreference = 'Stop'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   gf - Simple Gitflow Helper PowerShell Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ──────────────────────────────────────────────
# Step 0 — Check prerequisites
# ──────────────────────────────────────────────
Write-Host "[1/4] Checking prerequisites..." -ForegroundColor Yellow

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed or not on PATH." -ForegroundColor Red
    Write-Host "       Download from: https://git-scm.com/download/win"
    exit 1
}
Write-Host "  $([char]0x2713) Git found: $(git --version)" -ForegroundColor Green

# ──────────────────────────────────────────────
# Step 1 — Detect if already installed
# ──────────────────────────────────────────────
Write-Host ""
Write-Host "[2/4] Checking for existing installation..." -ForegroundColor Yellow

$alreadyInstalled = $false
if (Test-Path $PROFILE) {
    $match = Select-String -Path $PROFILE -Pattern 'function gf\b' | Select-Object -First 1
    if ($match) {
        $alreadyInstalled = $true
        Write-Host "  $([char]0x2713) gf is already installed in your PowerShell profile." -ForegroundColor Green
        Write-Host "  Profile entry: $($match.Line.Trim())" -ForegroundColor Cyan

        # Extract the script path from the existing profile line
        if ($match.Line -match '"([^"]*gf\.ps1)"') {
            $existingPath = $matches[1]
            if (Test-Path $existingPath) {
                Write-Host "  Script location: $existingPath" -ForegroundColor Cyan
            } else {
                Write-Host "  WARNING: Script not found at $existingPath" -ForegroundColor Red
            }
        }

        Write-Host ""
        $reinstall = Read-Host "  Reinstall/update? [y/N]"
        if ($reinstall -notmatch '^[Yy]') {
            Write-Host "  Installation skipped. gf is ready to use." -ForegroundColor Green
            exit 0
        }
        Write-Host "  Proceeding with reinstall..." -ForegroundColor Yellow
    }
}

if (-not $alreadyInstalled) {
    Write-Host "  $([char]0x25CB) gf is not yet installed in your PowerShell profile." -ForegroundColor Yellow
}

# ──────────────────────────────────────────────
# Step 2 — Determine script path
# ──────────────────────────────────────────────
Write-Host ""
Write-Host "[3/4] Configuring installation..." -ForegroundColor Yellow

$scriptDir = Split-Path -Parent $PSCommandPath
$gfScript = Join-Path $scriptDir "gf.ps1"

if (-not (Test-Path $gfScript)) {
    Write-Host "  ERROR: gf.ps1 not found at $gfScript" -ForegroundColor Red
    Write-Host "  Make sure you run this script from the simple-gitflow-helper-powershell directory."
    exit 1
}
Write-Host "  $([char]0x2713) gf.ps1 found at: $gfScript" -ForegroundColor Green

# ──────────────────────────────────────────────
# Step 3 — Install into PowerShell profile
# ──────────────────────────────────────────────
Write-Host ""
Write-Host "[4/4] Installing into PowerShell profile..." -ForegroundColor Yellow

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}

# Read existing profile content (if any), remove old gf entries
if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw
    # Remove old gf comment lines and function block
    $content = $content -replace '(?m)^# gf[^\n]*\r?\n', ''
    $content = $content -replace '(?ms)^function gf\s*\{[^}]*\}\s*\r?\n?', ''
    $content = $content.TrimEnd()
} else {
    $content = ''
}

# Append the gf function
$newContent = $content
if ($newContent) { $newContent += "`r`n`r`n" }
$newContent += '# gf - Simple Gitflow Helper PowerShell (auto-installed)' + "`r`n"
$newContent += "function gf { & `"$gfScript`" @args }" + "`r`n"

Set-Content -Path $PROFILE -Value $newContent -Encoding UTF8
Write-Host "  $([char]0x2713) Profile updated: $PROFILE" -ForegroundColor Green

# Set execution policy for the current user
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  $([char]0x2713) Execution policy set to RemoteSigned (CurrentUser)" -ForegroundColor Green
} else {
    Write-Host "  $([char]0x2713) Execution policy already set: $currentPolicy" -ForegroundColor Green
}

# ──────────────────────────────────────────────
# Verify
# ──────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To start using gf, reload your profile or open a new terminal:"
Write-Host ""
Write-Host "    . `$PROFILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Then try:"
Write-Host ""
Write-Host "    gf feature start my-feature" -ForegroundColor Cyan
Write-Host ""
Write-Host "  NOTE: A 'stable' branch must exist in your repo for gf to work."
Write-Host ""
