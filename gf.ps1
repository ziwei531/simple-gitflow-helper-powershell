# gf.ps1 - Simple Git Workflow Helper

# Mitigate PowerShell ErrorActionPreference conflicts with git's stderr
$ErrorActionPreference = 'Continue'

# Parse arguments manually to allow flexible CLI syntax like '--major'
$command = $args[0]
$action = $args[1]
$targetName = $args[2]
$isMajor = $args -contains "--major"

# Helper: Get the latest git tag
function Get-LatestTag {
    $tag = git describe --tags --abbrev=0 2>$null
    if ([string]::IsNullOrWhiteSpace($tag)) {
        return "v0.0.0" # Fallback if no tags exist
    }
    return $tag
}

# Helper: Parse version string into Major, Minor, Patch integers
function Get-VersionParts($tag) {
    $cleanTag = $tag -replace '^v', ''
    $parts = $cleanTag.Split('.')
    
    $major = if ($parts.Length -gt 0 -and $parts[0] -match '\d+') { [int]$parts[0] } else { 0 }
    $minor = if ($parts.Length -gt 1 -and $parts[1] -match '\d+') { [int]$parts[1] } else { 0 }
    $patch = if ($parts.Length -gt 2 -and $parts[2] -match '\d+') { [int]$parts[2] } else { 0 }
    
    return @{ Major=$major; Minor=$minor; Patch=$patch }
}

# -----------------------------------------------------------------------------
# Command Routing
# -----------------------------------------------------------------------------

if ($command -eq "feature" -and $action -eq "start") {
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        Write-Host "Error: Feature name is required. Usage: gf feature start <name>" -ForegroundColor Red
        exit 1
    }
    
    # Verify 'stable' exists
    git rev-parse --verify stable >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: 'stable' branch does not exist in this repository." -ForegroundColor Red
        exit 1
    }

    $branchName = "feature-$targetName"
    Write-Host "Starting feature '$targetName'..." -ForegroundColor Cyan
    
    git checkout -b $branchName stable
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushing branch to remote and setting upstream..." -ForegroundColor Cyan
        git push -u origin $branchName
    }
    
    exit $LASTEXITCODE
}
elseif ($command -eq "feature" -and $action -eq "merge-into-release") {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    
    if ($currentBranch -notmatch '^feature-(.+)$') {
        Write-Host "Error: You must be on a feature branch to use this command. Current branch: $currentBranch" -ForegroundColor Red
        exit 1
    }

    $releaseBranch = ""
    if ([string]::IsNullOrWhiteSpace($targetName)) {
        # Auto-detect latest active release branch based on most recent commit
        $releaseBranch = git for-each-ref --sort=-committerdate --format="%(refname:short)" --count=1 refs/heads/release-*
        
        if ([string]::IsNullOrWhiteSpace($releaseBranch)) {
            Write-Host "Error: No active release branches found. Please start a release first." -ForegroundColor Red
            exit 1
        }
        Write-Host "Auto-detected active release branch: $releaseBranch" -ForegroundColor DarkGray
    } else {
        $releaseBranch = "release-$targetName"
    }
    
    # Verify the target release branch exists (catches typos if user manually inputs a version)
    git rev-parse --verify $releaseBranch >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Release branch '$releaseBranch' does not exist locally." -ForegroundColor Red
        exit 1
    }

    Write-Host "Merging $currentBranch into $releaseBranch..." -ForegroundColor Cyan
    
    git checkout $releaseBranch
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    # Auto-commit message added here to skip the interactive editor
    git merge --no-ff -m "Merge branch '$currentBranch' into $releaseBranch" $currentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Merge conflict or error occurred. Please resolve manually, commit, and push." -ForegroundColor Yellow
        exit $LASTEXITCODE
    }

    Write-Host "Pushing updated release branch to origin..." -ForegroundColor Cyan
    git push origin $releaseBranch

    Write-Host "Success: $currentBranch merged into $releaseBranch and pushed to origin." -ForegroundColor Green
    exit 0
}
elseif ($command -eq "release" -and $action -eq "start") {
    $latestTag = Get-LatestTag
    $ver = Get-VersionParts $latestTag

    # Calculate version bump
    if ($isMajor) {
        $ver.Major += 1
        $ver.Minor = 0
        $ver.Patch = 0
    } else {
        if ($latestTag -eq "v0.0.0") {
            $ver.Minor = 1 # Initial tag logic starts at 0.1.0
        } else {
            $ver.Minor += 1
        }
        $ver.Patch = 0
    }

    $newVersion = "$($ver.Major).$($ver.Minor).$($ver.Patch)"
    $branchName = "release-$newVersion"
    $startPoint = if ($latestTag -eq "v0.0.0") { "stable" } else { $latestTag }

    Write-Host "Starting release $newVersion from $startPoint..." -ForegroundColor Cyan
    git checkout -b $branchName $startPoint
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushing branch to remote and setting upstream..." -ForegroundColor Cyan
        git push -u origin $branchName
    }

    exit $LASTEXITCODE
}
elseif ($command -eq "release" -and $action -eq "finish") {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    
    if ($currentBranch -notmatch '^release-(.+)$') {
        Write-Host "Error: You are not currently on a release branch. Current branch: $currentBranch" -ForegroundColor Red
        exit 1
    }
    
    $version = $matches[1]
    Write-Host "Finishing release $version..." -ForegroundColor Cyan
    
    git checkout stable
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    # Auto-commit message added here
    git merge --no-ff -m "Merge release '$version' into stable" $currentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Merge conflict or error occurred. Please resolve manually, commit, and then tag/delete the branch yourself." -ForegroundColor Yellow
        exit $LASTEXITCODE
    }

    git tag -a "v$version" -m "Release $version"
    
    Write-Host "Pushing stable branch and tags to origin..." -ForegroundColor Cyan
    git push origin stable --tags
    
    git branch -d $currentBranch
    
    Write-Host "Success: Release $version merged to stable, tagged as v$version, pushed to origin, and local branch deleted." -ForegroundColor Green
    exit 0
}
elseif ($command -eq "hotfix" -and $action -eq "start") {
    $latestTag = Get-LatestTag
    $ver = Get-VersionParts $latestTag

    # Calculate version bump
    if ($latestTag -eq "v0.0.0") {
        $ver.Minor = 1
        $ver.Patch = 0
    } else {
        $ver.Patch += 1
    }

    $newVersion = "$($ver.Major).$($ver.Minor).$($ver.Patch)"
    $branchName = "hotfix-$newVersion"
    $startPoint = if ($latestTag -eq "v0.0.0") { "stable" } else { $latestTag }

    Write-Host "Starting hotfix $newVersion from $startPoint..." -ForegroundColor Cyan
    git checkout -b $branchName $startPoint
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushing branch to remote and setting upstream..." -ForegroundColor Cyan
        git push -u origin $branchName
    }

    exit $LASTEXITCODE
}
elseif ($command -eq "hotfix" -and $action -eq "finish") {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    
    if ($currentBranch -notmatch '^hotfix-(.+)$') {
        Write-Host "Error: You are not currently on a hotfix branch. Current branch: $currentBranch" -ForegroundColor Red
        exit 1
    }
    
    $version = $matches[1]
    Write-Host "Finishing hotfix $version..." -ForegroundColor Cyan
    
    git checkout stable
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    # Auto-commit message added here
    git merge --no-ff -m "Merge hotfix '$version' into stable" $currentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Merge conflict or error occurred. Please resolve manually, commit, and then tag/delete the branch yourself." -ForegroundColor Yellow
        exit $LASTEXITCODE
    }

    git tag -a "v$version" -m "Hotfix $version"
    
    Write-Host "Pushing stable branch and tags to origin..." -ForegroundColor Cyan
    git push origin stable --tags

    git branch -d $currentBranch
    
    Write-Host "Success: Hotfix $version merged to stable, tagged as v$version, pushed to origin, and local branch deleted." -ForegroundColor Green
    exit 0
}
else {
    # Help Menu
    Write-Host "gf - Simple Git Workflow Helper" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  gf feature start {name}                      Create 'feature-{name}' from 'stable' and push to origin"
    Write-Host "  gf feature merge-into-release [version]      Merge feature into active release branch and push"
    Write-Host "  gf release start                             Create 'release-X.Y.Z' from last tag and push to origin"
    Write-Host "  gf release start --major                     Create 'release-X.Y.Z' from last tag (major bump) and push to origin"
    Write-Host "  gf release finish                            Merge current release to stable, tag, push, and delete local branch"
    Write-Host "  gf hotfix start                              Create 'hotfix-X.Y.Z' from last tag (revision bump) and push to origin"
    Write-Host "  gf hotfix finish                             Merge current hotfix to stable, tag, push, and delete local branch"
}