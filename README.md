# gf — Simple Gitflow Helper PowerShell

A lightweight PowerShell script inspired by [twgit](https://github.com/Twenga/twgit), providing a streamlined Git branching workflow for feature, release, and hotfix management.

## Installation (Windows)

### Automated Install (recommended)

Run the installer in **PowerShell**:

```powershell
.\install.ps1
```

The script detects existing installations, checks prerequisites, configures your PowerShell profile, and sets the execution policy — all interactively.

### Manual Install

#### Prerequisites

- **Git** — installed and available on your `PATH` ([download](https://git-scm.com/download/win))
- **PowerShell 5.1+** — included with Windows 10/11

#### Step 1 — Clone or Download

```powershell
# Clone the repository anywhere you like (e.g., your projects folder)
git clone https://github.com/your-username/simple-gitflow-helper-powershell.git C:\path\to\simple-gitflow-helper-powershell
```

Or download `gf.ps1` directly and place it in a folder of your choice (e.g., `C:\Tools\simple-gitflow-helper-powershell\`).

### Step 2 — Add to Your PowerShell Profile

Edit your PowerShell profile to make `gf` available in every session:

```powershell
# Open your profile (creates it if it doesn't exist)
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force }
notepad $PROFILE
```

Add the following line (adjust the path to match where you cloned the script):

```powershell
function gf { & "C:\path\to\simple-gitflow-helper-powershell\gf.ps1" @args }
```

Save the file and reload your profile:

```powershell
. $PROFILE
```

### Step 3 — Allow Script Execution

PowerShell restricts script execution by default. Set the execution policy **once per machine**:

```powershell
# Run PowerShell as Administrator, then:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Alternatively, relax it only for the current session (must repeat each time you open PowerShell):

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

### Step 4 — Verify

```powershell
gf feature start my-feature
```

If a new branch `feature-my-feature` is created from `stable`, the installation is complete.

## Quick Start

```powershell
# After installation, use from any directory:
gf feature start my-feature
gf release start
gf hotfix start
```

## Commands

| Command | Description |
|---------|-------------|
| `gf feature start {name}` | Create `feature-{name}` from `stable` and push to origin |
| `gf feature remove {name}` | Delete local and remote `feature-{name}` branch |
| `gf feature merge-into-release [version]` | Merge current feature into a release branch and push |
| `gf release start` | Create `release-X.Y.Z` from last tag (minor bump) |
| `gf release start --major` | Create `release-X.Y.Z` from last tag (major bump) |
| `gf release finish` | Merge release → `stable`, tag `vX.Y.Z`, delete release branch |
| `gf hotfix start` | Create `hotfix-X.Y.Z` from last tag (revision bump) |
| `gf hotfix finish` | Merge hotfix → `stable`, tag `vX.Y.Z`, delete hotfix branch |
| `gf clean` | Delete local branches whose remote tracking branch is gone |

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
gf feature merge-into-release  # merges into latest active release branch

# Or, to discard a feature entirely:
gf feature remove login-page   # deletes local and remote feature-login-page
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

### Clean

```powershell
gf clean                       # prune remote refs, then list & delete stale local branches
```

## Requirements

- Git installed and on `PATH`
- PowerShell 5.1+
- A `stable` branch must exist in the repository

## Known Issues

- PowerShell `$ErrorActionPreference` conflicts with git's stderr output — the script uses `"Continue"` internally, but the calling session may interfere
- Execution policy may need to be relaxed per session