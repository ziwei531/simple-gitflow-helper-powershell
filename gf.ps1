# gf.ps1 - Simple Gitflow Helper PowerShell

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
    
    Write-Host "Deleting local release branch '$currentBranch'..." -ForegroundColor Cyan
    git branch -d $currentBranch
    
    Write-Host "Deleting remote release branch 'origin/$currentBranch'..." -ForegroundColor Cyan
    git push origin --delete $currentBranch

    # Clean up remote feature branches
    $remoteFeatures = git branch -r --list "origin/feature-*" | ForEach-Object { $_.Trim() }
    if ($remoteFeatures.Count -gt 0) {
        Write-Host "Cleaning up remote feature branches..." -ForegroundColor Cyan
        foreach ($rf in $remoteFeatures) {
            $bareName = $rf -replace '^origin/', ''
            Write-Host "  Deleting remote '$rf'..." -ForegroundColor DarkGray
            git push origin --delete $bareName
        }
        Write-Host "All remote feature branches deleted." -ForegroundColor Green
    } else {
        Write-Host "No remote feature branches to clean up." -ForegroundColor DarkGray
    }

    Write-Host "Success: Release $version merged to stable, tagged as v$version, pushed, and branches cleaned up." -ForegroundColor Green
    Write-Host ""
    Write-Host "Tip: Run 'gf clean' to remove local branches whose remotes have been deleted." -ForegroundColor Green
    Write-Host "     (Local feature branches are not deleted automatically by convention.)" -ForegroundColor Green
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

    Write-Host "Deleting local hotfix branch '$currentBranch'..." -ForegroundColor Cyan
    git branch -d $currentBranch

    Write-Host "Deleting remote hotfix branch 'origin/$currentBranch'..." -ForegroundColor Cyan
    git push origin --delete $currentBranch
    
    Write-Host "Success: Hotfix $version merged to stable, tagged as v$version, pushed, and branches cleaned up." -ForegroundColor Green
    exit 0
}
elseif ($command -eq "clean") {
    Write-Host "Fetching and pruning remote references..." -ForegroundColor Cyan
    git fetch --prune
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: git fetch --prune failed." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    # Find local branches whose upstream tracking branch is gone
    $goneBranches = git branch -vv 2>$null | Select-String ': gone]' | ForEach-Object {
        $line = $_ -replace '^\*?\s+', '' -replace '\s+.*$', ''
        $line
    }

    if ($null -eq $goneBranches -or $goneBranches.Count -eq 0) {
        Write-Host "No stale local branches detected. Everything is clean!" -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "The following local branches have been deleted on remote:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($branch in $goneBranches) {
        Write-Host "  $branch" -ForegroundColor Red
    }
    Write-Host ""

    $deletedCount = 0
    foreach ($branch in $goneBranches) {
        $confirm = Read-Host "Delete '$branch'? [y/N]"
        if ($confirm -match '^[Yy]') {
            Write-Host "  Deleting local branch '$branch'..." -ForegroundColor Cyan
            git branch -D $branch
            if ($LASTEXITCODE -eq 0) {
                $deletedCount++
            } else {
                Write-Host "    Warning: Failed to delete '$branch'." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Skipped '$branch'." -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($deletedCount -gt 0) {
        Write-Host "Clean complete! Removed $deletedCount stale local branch(es)." -ForegroundColor Green
    } else {
        Write-Host "No branches were deleted." -ForegroundColor DarkGray
    }
    exit 0
}
else {
    # Help Menu
    Write-Host "gf - Simple Gitflow Helper PowerShell" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  gf feature start {name}                      Create 'feature-{name}' from 'stable' and push to origin"
    Write-Host "  gf feature merge-into-release [version]      Merge feature into active release branch and push"
    Write-Host "  gf release start                             Create 'release-X.Y.Z' from last tag and push to origin"
    Write-Host "  gf release start --major                     Create 'release-X.Y.Z' from last tag (major bump) and push to origin"
    Write-Host "  gf release finish                            Merge current release to stable, tag, push, and delete local branch"
    Write-Host "  gf hotfix start                              Create 'hotfix-X.Y.Z' from last tag (revision bump) and push to origin"
    Write-Host "  gf hotfix finish                             Merge current hotfix to stable, tag, push, and delete local branch"
    Write-Host "  gf clean                                     Delete local branches whose remote tracking branch is gone"
}