# Pushes Call Mom v1.0.0 to GitHub and tags it.
# The TestFlight workflow is workflow_dispatch: run it by hand from
# the Actions tab after pushing (a tag push does not start it).
#
# 1. Create an EMPTY repo on GitHub first: MikeGyver-SME/mikegyver-callmom
#    (no README, no .gitignore — this script supplies both).
# 2. Save this script AND callmom-v1.0.0.zip in E:\Downloads.
# 3. Run (after the Apple portal + GitHub secrets steps, see README.md):
#      powershell -ExecutionPolicy Bypass -File E:\Downloads\push-callmom.ps1
#
# If the repo folder already exists with a .git folder, the script overlays
# the zip onto it instead of re-initialising. Either way it tags v1.0.0.
# If v1.0.0 already exists, stop: bump CURRENT_PROJECT_VERSION in
# project.yml and re-zip before tagging again (TestFlight rejects a
# duplicate version/build pair).

param(
    [string]$RepoPath = ""
)

$ErrorActionPreference = 'Stop'

$downloads = if (Test-Path 'E:\Downloads') { 'E:\Downloads' } else { "$env:USERPROFILE\Downloads" }
$zip  = Join-Path $downloads 'callmom-v1.0.0.zip'
$repo = if ($RepoPath) { $RepoPath } elseif ($args.Count -ge 1) { $args[0] } else { Join-Path $downloads 'mikegyver-callmom' }

if (-not (Test-Path $zip)) { throw "Zip not found: $zip" }

$isNew = -not (Test-Path (Join-Path $repo '.git'))
if ($isNew) {
    New-Item -ItemType Directory -Force -Path $repo | Out-Null
    Expand-Archive -Path $zip -DestinationPath $repo -Force
    Set-Location $repo
    git init -b main
    git remote add origin https://github.com/MikeGyver-SME/mikegyver-callmom.git
} else {
    Expand-Archive -Path $zip -DestinationPath $repo -Force
    Set-Location $repo
}

$status = git status --porcelain
if (-not $status -and -not $isNew) { Write-Host "Nothing changed - working tree already has v1.0.0."; exit 0 }

if (git tag --list 'v1.0.0') { throw "Tag v1.0.0 already exists. Bump CURRENT_PROJECT_VERSION in project.yml and re-zip first." }

git add -A
git commit -m "Call Mom v1.0.0: single-number Google Voice handoff for cruise Wi-Fi" | Out-Null
if ($isNew) {
    git push -u origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Initial push rejected (remote probably has a README) - pulling and retrying..."
        git pull --rebase origin main
        if ($LASTEXITCODE -ne 0) { throw "git pull --rebase failed - resolve conflicts, then re-run." }
        git push -u origin main
        if ($LASTEXITCODE -ne 0) { throw "git push failed after rebase - main was NOT updated." }
    }
} else {
    git push
    if ($LASTEXITCODE -ne 0) { throw "git push failed - main was NOT updated. Do not tag; fix the push first." }
}
git tag v1.0.0
git push origin v1.0.0
if ($LASTEXITCODE -ne 0) { throw "git push origin v1.0.0 (tag) failed." }

Write-Host ""
Write-Host "Pushed v1.0.0 - now run the TestFlight workflow BY HAND:"
Write-Host "GitHub repo -> Actions -> 'Call Mom - Signed TestFlight' -> Run workflow."
Write-Host "Pushing a tag does NOT start it (it is workflow_dispatch, manual only)."
Write-Host "Watch it at: https://github.com/MikeGyver-SME/mikegyver-callmom/actions"
Write-Host "Before that workflow can succeed, set the repo secrets ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, TEAM_ID,"
Write-Host "and create the App ID + App Store Connect record for studio.mikegyver.callmom (see README.md section 3)."
