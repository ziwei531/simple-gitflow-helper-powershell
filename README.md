# gf — Simple Git Workflow Helper

A lightweight PowerShell script inspired by [twgit](https://github.com/Twenga/twgit), providing a streamlined Git branching workflow for feature, release, and hotfix management.

## Quick Start

```powershell
# One-time session setup
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# Add to your PowerShell profile ($PROFILE)
function gf { & "E:\Projects\simple-twgit\gf.ps1" @args }

# Now use from anywhere
gf feature start my-feature
```

## Commands

| Command | Description |
|---------|-------------|
| `gf feature start {name}` | Create `feature-{name}` from `stable` |
| `gf release start` | Create `release-X.Y.Z` from last tag (minor bump) |
| `gf release start --major` | Create `release-X.Y.Z` from last tag (major bump) |
| `gf hotfix start` | Create `hotfix-X.Y.Z` from last tag (revision bump) |
| `gf hotfix finish` | Merge hotfix → `stable`, tag `vX.Y.Z`, delete hotfix branch |

## Branch Model

```
stable          ← integration branch (single source of truth)
feature-*       ← feature branches, branched from stable
release-X.Y.Z   ← release preparation, branched from last tag
hotfix-X.Y.Z    ← production hotfixes, branched from last tag
```

Feature branches start from `stable`. Release and hotfix branches start from the **most recent `vX.Y.Z` tag**.

## Versioning

Tags follow `vX.Y.Z` (semver). Release and hotfix commands scan existing tags to auto-detect version numbers:

| Action | Bump | Example |
|--------|------|---------|
| `release start` | minor (default) | `v0.1.0` → `release-0.2.0` |
| `release start --major` | major | `v0.1.0` → `release-1.0.0` |
| `hotfix start` | revision | `v0.1.0` → `hotfix-0.1.1` |

When no tags exist, the first release/hotfix starts at `0.1.0`.

## Workflow Examples

### Feature

```powershell
gf feature start login-page    # creates feature-login-page from stable
# ... make changes, commit ...
git checkout stable
git merge --no-ff feature-login-page
git branch -d feature-login-page
```

### Release

```powershell
gf release start               # creates release-0.2.0 (minor bump from v0.1.0)
gf release start --major        # creates release-1.0.0 (major bump from v0.1.0)
# ... stabilize, test, merge features ...
git checkout stable
git merge --no-ff release-0.2.0
git tag -a v0.2.0 -m "Release 0.2.0"
git branch -d release-0.2.0
```

### Hotfix

```powershell
gf hotfix start                # creates hotfix-0.1.1 from last tag (rev bump from v0.1.0)
# ... fix bugs, commit ...

gf hotfix finish               # auto: merge → stable, tag v0.1.1, delete branch
```

## Requirements

- Git installed and on `PATH`
- PowerShell 5.1+
- A `stable` branch must exist in the repository

## Known Issues

- PowerShell `$ErrorActionPreference` conflicts with git's stderr output — the script uses `"Continue"` internally, but the calling session may interfere
- Execution policy may need to be relaxed per session