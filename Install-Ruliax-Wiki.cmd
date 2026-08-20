@echo off
REM ===================================================================
REM  Ruliax Wiki - Windows installer
REM
REM  Double-click this file. It installs Git, the GitHub CLI and
REM  Obsidian if they are missing, signs you in to GitHub, downloads
REM  the knowledge domains you have access to, and sets Obsidian up to
REM  open them.
REM
REM  One file on purpose: it has to survive being emailed to someone
REM  who has nothing installed yet, so it cannot depend on a second
REM  file sitting next to it.
REM
REM  Everything below the marker line at the bottom of this header is
REM  PowerShell. The batch header hands the rest of the file to
REM  PowerShell and exits before cmd.exe ever reads it.
REM
REM  The marker is assembled from two pieces in the command line below,
REM  so that the string being searched for never appears in the line
REM  doing the searching - and so that this comment cannot match it
REM  either, which it did on the first attempt.
REM ===================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText('%~f0');$m='#PS'+'BEGIN';Invoke-Expression $c.Substring($c.IndexOf($m)+$m.Length)"
set EXITCODE=%ERRORLEVEL%

echo.
pause
exit /b %EXITCODE%

#PSBEGIN

# Deliberately Continue, not Stop. Almost everything below is a native
# command, and Windows PowerShell 5.1 turns a native program's stderr into an
# ErrorRecord - so under Stop, any tool that writes a harmless warning to
# stderr kills the installer. Exit codes are checked explicitly instead.
$ErrorActionPreference = 'Continue'

# 5.1 still negotiates TLS 1.0 by default on some builds, and github.com has
# refused that for years. Without this the first download fails with "the
# underlying connection was closed".
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# The progress bar makes Invoke-WebRequest roughly ten times slower.
$ProgressPreference = 'SilentlyContinue'

$Slug = 'Ruliax-AI/RuliaxWiki'

# ── Output ───────────────────────────────────────────────────────────────

function Say { param($m) Write-Host "  $m" }
function Good { param($m) Write-Host "  [ok]   $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  [warn] $m" -ForegroundColor Yellow }
function Bad { param($m) Write-Host "  [x]    $m" -ForegroundColor Red }
function Dim { param($m) Write-Host "         $m" -ForegroundColor DarkGray }
function Head {
    param($m)
    Write-Host ''
    Write-Host ("== $m " + ('=' * [Math]::Max(0, 58 - $m.Length))) -ForegroundColor Cyan
}

function Stop-Here {
    param($Message, $Hint)
    Write-Host ''
    Bad $Message
    if ($Hint) { Dim $Hint }
    Write-Host ''
    exit 1
}

# ── Running other programs ───────────────────────────────────────────────

function Invoke-Tool {
    # Captures output and returns the exit code, without letting a native
    # program's stderr become a PowerShell exception.
    param([string]$Command, [string[]]$Arguments = @())
    $lines = & $Command @Arguments 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.ToString() } else { $_ }
    }
    return [pscustomobject]@{
        Ok     = ($LASTEXITCODE -eq 0)
        Code   = $LASTEXITCODE
        Output = (($lines | Out-String).Trim())
    }
}

function Update-SessionPath {
    # An installer writes the new PATH to the registry, but this process was
    # started with the old one and will never see it. Without this, installing
    # git and then running git in the same session fails with "not recognised"
    # on a machine where git is plainly installed.
    # Appended rather than replaced. A session PATH can hold entries that are
    # not in the registry - a developer shell, or a terminal launched with a
    # modified environment - and dropping those would hide a perfectly good git
    # and install a second copy of it.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH = (@($env:PATH, $machine, $user) | Where-Object { $_ }) -join ';'
}

function Have {
    param($Name)
    Update-SessionPath
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-Arch {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { return 'arm64' }
    return 'amd64'
}

# ── Installing things ────────────────────────────────────────────────────

function Install-ViaWinget {
    param($Id)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    Say "installing $Id  (Windows may ask permission - click Yes)"
    $p = Start-Process -FilePath 'winget' -Wait -PassThru -NoNewWindow -ArgumentList @(
        'install', '--id', $Id, '--exact', '--silent',
        '--accept-source-agreements', '--accept-package-agreements'
    )
    # winget has several non-zero codes that all mean "already installed", so
    # the real test is whether the thing is there afterwards. This return value
    # only decides whether to bother with the fallback.
    return ($p.ExitCode -eq 0)
}

function Install-FromGitHubRelease {
    <#
        The fallback for machines with no winget - Windows 10 builds where App
        Installer was never delivered. Asks each project what its own latest
        release is, rather than pinning a URL that goes stale in a year.
    #>
    param($Repo, [scriptblock]$PickAsset, [scriptblock]$Runner)

    try {
        Say "downloading from github.com/$Repo"
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
            -Headers @{ 'User-Agent' = 'RuliaxWiki-Installer' } -ErrorAction Stop
        $asset = @($rel.assets | Where-Object $PickAsset) | Select-Object -First 1
        if (-not $asset) { return $false }

        $file = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -UseBasicParsing -ErrorAction Stop
        Say "installing $($asset.name)  (Windows may ask permission - click Yes)"
        try { return ((& $Runner $file).ExitCode -eq 0) }
        finally { Remove-Item $file -Force -ErrorAction SilentlyContinue }
    }
    catch {
        Warn "download failed: $($_.Exception.Message)"
        return $false
    }
}

$RunInno = { param($f) Start-Process -FilePath $f -Wait -PassThru -ArgumentList '/VERYSILENT', '/NORESTART' }
$RunNsis = { param($f) Start-Process -FilePath $f -Wait -PassThru -ArgumentList '/S' }
$RunMsi = { param($f) Start-Process -FilePath 'msiexec.exe' -Wait -PassThru -ArgumentList '/i', ('"' + $f + '"'), '/quiet', '/norestart' }

function Find-Obsidian {
    # Obsidian's installer puts it in LOCALAPPDATA\Programs\Obsidian, which is
    # neither where you would guess nor where winget reports. Guessing wrong is
    # worse than not guessing: the installer reinstalls software that is
    # already there and then announces that it failed.
    foreach ($p in @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'),
            (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
            (Join-Path ${env:ProgramFiles} 'Obsidian\Obsidian.exe'))) {
        if ($p -and (Test-Path $p)) { return $p }
    }

    # Whatever it calls itself and wherever it lands, an installed Windows
    # program registers itself here.
    $keys = @(
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $entry = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Obsidian*' } | Select-Object -First 1
    if ($entry) {
        if ($entry.InstallLocation) {
            $exe = Join-Path $entry.InstallLocation 'Obsidian.exe'
            if (Test-Path $exe) { return $exe }
        }
        if ($entry.DisplayIcon) {
            # Recorded as "C:\path\Obsidian.exe,0" - the trailing icon index is
            # not part of the path.
            $exe = ($entry.DisplayIcon -split ',')[0].Trim('"')
            if (Test-Path $exe) { return $exe }
        }
    }
    return $null
}

# ── Start ────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '  Ruliax Wiki' -ForegroundColor White
Write-Host '  Setting up this computer. It takes about five minutes.' -ForegroundColor DarkGray
Write-Host ''
Dim 'Everything this installs is ordinary, publicly available software.'
Dim 'It does not touch files you already have.'

# ── Where the wiki will live ─────────────────────────────────────────────

Head 'where'

$Root = Join-Path $env:USERPROFILE 'RuliaxWiki'

# Not Documents. On most machines Documents is redirected into OneDrive, and
# OneDrive syncing a git repository is a second sync system fighting the first
# - the one rule this system does not bend on. The home folder is also shorter,
# and Windows still cannot open a path longer than 260 characters.
if ($Root -like '*OneDrive*') {
    Stop-Here 'Your home folder sits inside OneDrive, and this cannot install there.' `
        'OneDrive would fight with the syncing this system already does. Ask a founder.'
}

Say "the wiki will live in  $Root"

# ── Prerequisites ────────────────────────────────────────────────────────

Head 'software'

if (Have 'git') {
    Good 'Git is already installed'
}
else {
    # winget has several non-zero exit codes that all mean "already
    # installed", so a false here is not proof that nothing happened. Look
    # again before downloading an installer and running it over software that
    # is already on this machine.
    if (-not (Install-ViaWinget 'Git.Git') -and -not (Have 'git')) {
        $arch = Get-Arch
        # -like is anchored at both ends, so 'Git-*' does not match
        # 'PortableGit-...', which is a 7-zip self-extractor and not an
        # installer at all.
        Install-FromGitHubRelease -Repo 'git-for-windows/git' -Runner $RunInno -PickAsset {
            if ($arch -eq 'arm64') { $_.name -like 'Git-*-arm64.exe' }
            else { $_.name -like 'Git-*-64-bit.exe' }
        } | Out-Null
    }
    if (Have 'git') { Good 'Git installed' }
    else {
        Stop-Here 'Could not install Git.' `
            'Install it from https://git-scm.com/download/win, then run this file again.'
    }
}

if (Have 'gh') {
    Good 'GitHub CLI is already installed'
}
else {
    if (-not (Install-ViaWinget 'GitHub.cli') -and -not (Have 'gh')) {
        $arch = Get-Arch
        Install-FromGitHubRelease -Repo 'cli/cli' -Runner $RunMsi -PickAsset {
            $_.name -like "gh_*_windows_$arch.msi"
        } | Out-Null
    }
    if (Have 'gh') { Good 'GitHub CLI installed' }
    else {
        Stop-Here 'Could not install the GitHub CLI.' `
            'Install it from https://cli.github.com, then run this file again.'
    }
}

$obsidian = Find-Obsidian
if ($obsidian) {
    Good 'Obsidian is already installed'
}
else {
    if (-not (Install-ViaWinget 'Obsidian.Obsidian') -and -not (Find-Obsidian)) {
        # One Windows installer, no ARM64 build - the arm64 assets in that
        # release are Linux AppImages. On ARM machines this one runs emulated,
        # which is what Obsidian intends.
        Install-FromGitHubRelease -Repo 'obsidianmd/obsidian-releases' -Runner $RunNsis -PickAsset {
            $_.name -like 'Obsidian-*.exe'
        } | Out-Null
    }
    $obsidian = Find-Obsidian
    if ($obsidian) { Good 'Obsidian installed' }
    else {
        # Not fatal. The notes are plain files; Obsidian is how you read them
        # comfortably. Stopping the install over it would be out of proportion.
        Warn 'Could not install Obsidian automatically.'
        Dim 'Get it from https://obsidian.md - everything below still works without it.'
    }
}

# ── GitHub ───────────────────────────────────────────────────────────────

Head 'github'

if ((Invoke-Tool 'gh' @('auth', 'status')).Ok) {
    $who = (Invoke-Tool 'gh' @('api', 'user', '--jq', '.login')).Output
    Good "already signed in as $who"
}
else {
    Write-Host ''
    Say 'A browser is about to open so you can sign in to GitHub.'
    Say 'Copy the code shown below, paste it into the browser, then come back here.'
    Write-Host ''
    # --web is the flow a non-technical person can actually finish: a short
    # code and a browser. No tokens to generate, no SSH keys to make. It is
    # run without capturing output, because it has to be able to talk to you.
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) {
        Stop-Here 'Sign-in did not finish.' 'Run this file again whenever you are ready.'
    }
    Good 'signed in'
}

# Teaches git itself to use those credentials, so pushing never prompts later.
Invoke-Tool 'gh' @('auth', 'setup-git') | Out-Null

# ── The wiki ─────────────────────────────────────────────────────────────

Head 'download'

if (Test-Path (Join-Path $Root '.git')) {
    Say 'already downloaded - checking for updates'
    $pull = Invoke-Tool 'git' @('-C', $Root, 'pull', '--ff-only')
    if ($pull.Ok) { Good 'up to date' }
    else { Warn "could not update: $($pull.Output)" }
}
else {
    # A folder already there but not a clone. Say so, rather than letting the
    # clone fail and blaming GitHub access - which is what it looked like, and
    # would have sent someone to ask a founder about a permission that was
    # never the problem. Nothing here is deleted or merged into.
    if ((Test-Path $Root) -and (Get-ChildItem -LiteralPath $Root -Force | Select-Object -First 1)) {
        Stop-Here "$Root already exists and has files in it." `
            'Nothing was changed. Rename or move that folder, then run this again.'
    }

    $clone = Invoke-Tool 'gh' @('repo', 'clone', $Slug, $Root)
    if (-not (Test-Path (Join-Path $Root '.git'))) {
        Stop-Here "Could not download $Slug." `
            'Most likely your GitHub account has not been added yet. Ask a founder, then run this again.'
    }
    Good 'downloaded'
}

# ── Hand over ────────────────────────────────────────────────────────────
# Everything past this point is the same script an existing teammate runs, so
# there is one description of what a set-up machine looks like, not two.

& (Join-Path $Root 'setup.ps1')
$setupCode = $LASTEXITCODE

if ($setupCode -ne 0) {
    Write-Host ''
    Bad 'Setup did not finish cleanly. The messages above say why.'
    exit $setupCode
}

Head 'done'
Good 'This computer is ready.'
Write-Host ''
Say 'The list just above shows where your notes are and what each vault holds.'
Write-Host ''
Dim 'Your notes save and sync by themselves. You never need to run this again -'
Dim 'except when your access changes, when running it once more catches up.'

if ($obsidian) {
    Write-Host ''
    $answer = Read-Host '  Open Obsidian now? [Y/n]'
    if ($answer -notmatch '^[Nn]') { Start-Process $obsidian }
}

exit 0
