#!/usr/bin/env bash
#
# Ruliax Wiki - macOS and Linux installer
#
# Normally run as one line, which is the only way that is genuinely one action
# on a Mac:
#
#     curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | bash
#
# It can also be double-clicked as a .command file, if you have one that still
# has its executable bit. macOS quarantines anything downloaded through a
# browser and Gatekeeper then refuses to run it, which is why the line above
# exists: nothing is "opened", so there is nothing for Gatekeeper to block.
#
# It installs git, the GitHub CLI and Obsidian if they are missing, signs you
# in to GitHub, downloads the knowledge domains you have access to, and sets
# Obsidian up to open them.
#
# Self-contained on purpose. It runs before this project exists on the machine,
# so it cannot use the shared library in bin/lib/wiki.sh, and it installs the
# GitHub CLI straight from that project's own release into ~/.local/bin rather
# than requiring Homebrew - which would mean a multi-gigabyte Xcode download
# before the first note is read.
#
# Everything that *does* anything lives inside main(), which is called on the
# very last line. Piped into bash, a download cut off halfway would otherwise
# execute half an installer; this way a truncated file defines an incomplete
# function, bash never reaches the call, and nothing happens at all.

set -uo pipefail

SLUG='Ruliax-AI/RuliaxWiki'
ROOT="$HOME/RuliaxWiki"
BIN="$HOME/.local/bin"

# ── Talking to the person running this ────────────────────────────────────
#
# When this is piped into bash, stdin is the script itself - so anything that
# tries to read an answer gets shell source code, and `gh auth login` reads a
# stray line of bash instead of waiting for you. Interactive things therefore
# read from the terminal directly.

TTY=/dev/tty
[ -r "$TTY" ] || TTY=''

if [ -t 1 ]; then
    C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m';  C_DIM=$'\033[90m';   C_OFF=$'\033[0m'
else
    C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_DIM=''; C_OFF=''
fi

say()  { printf '  %s\n' "$1"; }
good() { printf '  %s\n' "${C_GREEN}[ok]   $1${C_OFF}"; }
warn() { printf '  %s\n' "${C_YELLOW}[warn] $1${C_OFF}"; }
bad()  { printf '  %s\n' "${C_RED}[x]    $1${C_OFF}"; }
dim()  { printf '  %s\n' "${C_DIM}       $1${C_OFF}"; }
head_() {
    # A heading longer than the rule would ask seq for a negative range.
    n=$((58 - ${#1}))
    [ "$n" -gt 0 ] || n=1
    printf '\n%s\n' "${C_CYAN}== $1 $(printf '=%.0s' $(seq 1 "$n"))${C_OFF}"
}

# A double-clicked window closes the instant the script ends, taking the error
# message with it. Hold it open - but only when double-clicked. Run from a
# terminal, the window is the person's own and pausing it is just rude.
finish() {
    code=$?
    printf '\n'
    if [ -t 0 ] && [ -t 1 ]; then
        printf '  %s' "${C_DIM}Press return to close this window.${C_OFF}"
        read -r _ || true
    fi
    exit "$code"
}
trap finish EXIT

stop_here() {
    printf '\n'
    bad "$1"
    [ $# -gt 1 ] && dim "$2"
    exit 1
}

# ── Downloading ───────────────────────────────────────────────────────────

fetch() {
    # $1 url, $2 destination file
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        return 1
    fi
}

read_url() {
    # $1 url -> the body, on stdout.
    #
    # A separate function rather than `fetch url /dev/stdout`, which looks like
    # it should work and does not: curl writing to /dev/stdout inside a
    # pipeline fails with "failure writing output to destination" as soon as
    # the reader closes the pipe, and the caller sees an empty string rather
    # than an error.
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$1"
    else
        return 1
    fi
}

release_asset_url() {
    # $1 owner/repo, $2 extended regex matched against the file name.
    #
    # No jq. Nothing in this project requires a JSON parser to be installed,
    # and an installer least of all - it runs before anything is installed.
    read_url "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*"' \
        | sed 's/.*"\(https[^"]*\)"/\1/' \
        | grep -E "$2" \
        | head -1
}

# ── Root ──────────────────────────────────────────────────────────────────

as_root() {
    # Not every Linux box has sudo. Containers and minimal images often run as
    # root already, and some distributions ship doas instead.
    if [ "$(id -u)" -eq 0 ]; then "$@"
    elif command -v sudo >/dev/null 2>&1; then sudo "$@"
    elif command -v doas >/dev/null 2>&1; then doas "$@"
    else return 127
    fi
}

can_be_root() {
    [ "$(id -u)" -eq 0 ] && return 0
    command -v sudo >/dev/null 2>&1 && return 0
    command -v doas >/dev/null 2>&1 && return 0
    return 1
}

# ── PATH ──────────────────────────────────────────────────────────────────

shell_rc() {
    case "$(basename "${SHELL:-/bin/bash}")" in
        zsh)  printf '%s\n' "$HOME/.zshrc" ;;
        bash) [ "$PLATFORM" = macos ] && printf '%s\n' "$HOME/.bash_profile" || printf '%s\n' "$HOME/.bashrc" ;;
        *)    printf '%s\n' "$HOME/.profile" ;;
    esac
}

ensure_local_bin_on_path() {
    mkdir -p "$BIN"
    case ":$PATH:" in *":$BIN:"*) ;; *) PATH="$BIN:$PATH"; export PATH ;; esac

    rc="$(shell_rc)"
    # A marker rather than grepping for the line itself, so re-running this
    # installer a year from now does not append a second copy.
    if [ ! -f "$rc" ] || ! grep -q 'added by the Ruliax Wiki installer' "$rc" 2>/dev/null; then
        {
            printf '\n# added by the Ruliax Wiki installer\n'
            printf 'export PATH="$HOME/.local/bin:$PATH"\n'
        } >> "$rc"
        dim "added ~/.local/bin to your PATH in $(basename "$rc")"
    fi
}

# ── git ───────────────────────────────────────────────────────────────────

install_git() {
    if git --version >/dev/null 2>&1; then
        good 'git is already installed'
        return 0
    fi

    if [ "$PLATFORM" = macos ]; then
        # macOS ships a stub at /usr/bin/git that exists but does nothing until
        # the Command Line Tools are installed. `command -v git` is a lie here;
        # only actually running it tells the truth.
        say 'git needs Apple Command Line Tools.'
        say 'A dialog is about to appear - click Install and wait for it to finish.'
        xcode-select --install >/dev/null 2>&1 || true
        printf '  waiting'
        waited=0
        while ! git --version >/dev/null 2>&1; do
            printf '.'
            sleep 10
            waited=$((waited + 10))
            if [ "$waited" -ge 1800 ]; then
                printf '\n'
                stop_here 'Command Line Tools did not finish installing.' \
                          'Finish the dialog, then run this again.'
            fi
        done
        printf '\n'
        good 'git installed'
        return 0
    fi

    can_be_root || stop_here 'git is missing, and installing it needs administrator rights.' \
                             'Install git with your package manager, then run this again.'

    say 'installing git (you may be asked for your password)'
    if   command -v apt-get >/dev/null 2>&1; then as_root apt-get update -qq && as_root apt-get install -y git
    elif command -v dnf     >/dev/null 2>&1; then as_root dnf install -y git
    elif command -v yum     >/dev/null 2>&1; then as_root yum install -y git
    elif command -v pacman  >/dev/null 2>&1; then as_root pacman -Sy --noconfirm git
    elif command -v zypper  >/dev/null 2>&1; then as_root zypper install -y git
    elif command -v apk     >/dev/null 2>&1; then as_root apk add --no-cache git
    elif command -v emerge  >/dev/null 2>&1; then as_root emerge --quiet dev-vcs/git
    else stop_here 'Could not work out how to install git on this system.' \
                   'Install git with your package manager, then run this again.'
    fi
    git --version >/dev/null 2>&1 || stop_here 'git still is not working.' 'Install it by hand and run this again.'
    good 'git installed'
}

# ── GitHub CLI ────────────────────────────────────────────────────────────

install_gh() {
    if command -v gh >/dev/null 2>&1; then
        good 'GitHub CLI is already installed'
        return 0
    fi

    say 'installing the GitHub CLI'
    tmp="$(mktemp -d)"
    if [ "$PLATFORM" = macos ]; then
        url="$(release_asset_url cli/cli "gh_.*_macOS_${ARCH}\.zip$")"
    else
        url="$(release_asset_url cli/cli "gh_.*_linux_${ARCH}\.tar\.gz$")"
    fi

    if [ -z "$url" ]; then
        rm -rf "$tmp"
        stop_here 'Could not find a GitHub CLI download for this machine.' \
                  'Install it from https://cli.github.com, then run this again.'
    fi

    file="$tmp/$(basename "$url")"
    if ! fetch "$url" "$file"; then
        rm -rf "$tmp"
        stop_here 'Download failed.' 'Check your internet connection and run this again.'
    fi

    case "$file" in
        *.zip)    unzip -q "$file" -d "$tmp" ;;
        *.tar.gz) tar -xzf "$file" -C "$tmp" ;;
    esac

    # unzip does not always preserve the executable bit, so do not filter on it.
    found="$(find "$tmp" -type f -name gh 2>/dev/null | head -1)"
    if [ -z "$found" ]; then
        rm -rf "$tmp"
        stop_here 'The GitHub CLI download did not contain what was expected.' \
                  'Install it from https://cli.github.com, then run this again.'
    fi
    install -m 0755 "$found" "$BIN/gh"
    rm -rf "$tmp"

    command -v gh >/dev/null 2>&1 || stop_here 'The GitHub CLI did not install.' 'Ask a founder.'
    good "GitHub CLI installed into $BIN"
}

# ── Obsidian ──────────────────────────────────────────────────────────────
# Never fatal. The notes are plain files; Obsidian is how you read them
# comfortably. Stopping the whole install over it would be out of proportion.

find_obsidian() {
    if [ "$PLATFORM" = macos ]; then
        for p in "/Applications/Obsidian.app" "$HOME/Applications/Obsidian.app"; do
            [ -d "$p" ] && { printf '%s\n' "$p"; return 0; }
        done
    else
        command -v obsidian >/dev/null 2>&1 && { command -v obsidian; return 0; }
        for p in "$BIN/obsidian" "$HOME/.local/share/obsidian/obsidian" \
                 "$HOME/Applications/Obsidian.AppImage" \
                 "/var/lib/flatpak/exports/bin/md.obsidian.Obsidian" \
                 "$HOME/.local/share/flatpak/exports/bin/md.obsidian.Obsidian"; do
            [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
        done
    fi
    return 1
}

install_obsidian_macos() {
    url="$(release_asset_url obsidianmd/obsidian-releases 'Obsidian-[0-9.]+\.dmg$')"
    [ -n "$url" ] || return 1
    tmp="$(mktemp -d)"
    say 'downloading Obsidian'
    fetch "$url" "$tmp/Obsidian.dmg" || { rm -rf "$tmp"; return 1; }

    # -mountpoint, so there is no guessing at where it landed, and -nobrowse so
    # a Finder window does not open on top of the terminal mid-install.
    mkdir -p "$tmp/mnt"
    hdiutil attach -nobrowse -quiet -mountpoint "$tmp/mnt" "$tmp/Obsidian.dmg" || { rm -rf "$tmp"; return 1; }

    dest=/Applications
    [ -w "$dest" ] || dest="$HOME/Applications"
    mkdir -p "$dest"
    cp -R "$tmp/mnt/Obsidian.app" "$dest/" 2>/dev/null
    rc=$?
    hdiutil detach -quiet "$tmp/mnt" || true
    rm -rf "$tmp"

    # It came from the internet, so it is quarantined, and the first launch
    # would be a Gatekeeper refusal. We downloaded it deliberately from
    # Obsidian's own release, so say so and clear the flag.
    [ $rc -eq 0 ] && xattr -dr com.apple.quarantine "$dest/Obsidian.app" 2>/dev/null
    return $rc
}

install_obsidian_linux() {
    # Debian and Ubuntu get the .deb: it is Obsidian's own build, and it wires
    # up the menu entry, the icon and the Chromium sandbox helper for us.
    if command -v apt-get >/dev/null 2>&1 && [ "$ARCH" = amd64 ] && can_be_root; then
        url="$(release_asset_url obsidianmd/obsidian-releases 'obsidian_[0-9.]+_amd64\.deb$')"
        if [ -n "$url" ]; then
            tmp="$(mktemp -d)"
            say 'downloading Obsidian'
            if fetch "$url" "$tmp/obsidian.deb"; then
                say 'installing Obsidian (you may be asked for your password)'
                as_root apt-get install -y "$tmp/obsidian.deb" && { rm -rf "$tmp"; return 0; }
            fi
            rm -rf "$tmp"
        fi
    fi

    # Everywhere else: Obsidian's own tarball, unpacked into the home folder.
    #
    # Not the AppImage, which is the same binary wrapped in a format that needs
    # FUSE 2 - and Fedora and others stopped shipping that, so it would install
    # cleanly and then refuse to start. Not Flatpak or Snap either: both are
    # third-party repackagings of an application that opens the cap table.
    install_obsidian_tarball
}

# Electron needs either unprivileged user namespaces or a setuid helper. Most
# distributions allow the former; Debian-derived ones that turned it off, and
# Ubuntu 24.04's AppArmor rule, do not - and Obsidian then exits complaining
# about the SUID sandbox. Checking first avoids asking for a password on the
# majority of machines where nothing needs doing.
userns_available() {
    [ "$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo 1)" != "0" ] || return 1
    [ "$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo 1)" != "0" ] || return 1
    [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)" = "0" ] || return 1
    return 0
}

install_obsidian_tarball() {
    if [ "$ARCH" = arm64 ]; then pat='obsidian-[0-9.]+-arm64\.tar\.gz$'
    else pat='obsidian-[0-9.]+\.tar\.gz$'
    fi
    url="$(release_asset_url obsidianmd/obsidian-releases "$pat")"
    [ -n "$url" ] || return 1

    say 'downloading Obsidian (about 120 MB, this is the slow part)'
    tmp="$(mktemp -d)"
    if ! fetch "$url" "$tmp/obsidian.tar.gz"; then rm -rf "$tmp"; return 1; fi

    dest="$HOME/.local/share/obsidian"
    rm -rf "$dest"
    mkdir -p "$dest"
    # The tarball holds one obsidian-<version>/ directory. Strip it, so an
    # upgrade lands in the same place and the menu entry never goes stale.
    if ! tar -xzf "$tmp/obsidian.tar.gz" -C "$dest" --strip-components=1; then
        rm -rf "$tmp" "$dest"
        return 1
    fi
    rm -rf "$tmp"
    [ -f "$dest/obsidian" ] || return 1
    # The archive does record rwxr-xr-x, but a home directory on a filesystem
    # that cannot store the bit would leave it unset - and the symptom is an
    # install that reports success and an Obsidian that never opens.
    chmod +x "$dest/obsidian" "$dest/obsidian-cli" 2>/dev/null || true

    ln -sf "$dest/obsidian" "$BIN/obsidian"

    exec_line="$BIN/obsidian %u"
    if ! userns_available; then
        if as_root chown root:root "$dest/chrome-sandbox" 2>/dev/null &&
           as_root chmod 4755 "$dest/chrome-sandbox" 2>/dev/null; then
            :
        else
            warn 'This kernel restricts user namespaces and the sandbox helper needs root.'
            dim 'Obsidian will run with --no-sandbox. To undo that later:'
            dim "  sudo chown root:root $dest/chrome-sandbox"
            dim "  sudo chmod 4755 $dest/chrome-sandbox"
            exec_line="$BIN/obsidian --no-sandbox %u"
        fi
    fi

    if [ -f "$dest/resources/icon.png" ]; then
        mkdir -p "$HOME/.local/share/icons/hicolor/512x512/apps"
        cp "$dest/resources/icon.png" "$HOME/.local/share/icons/hicolor/512x512/apps/obsidian.png"
    fi

    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/obsidian.desktop" <<DESKTOP
[Desktop Entry]
Name=Obsidian
Comment=A knowledge base that works on local Markdown files
Exec=$exec_line
Terminal=false
Type=Application
Icon=obsidian
Categories=Office;
MimeType=x-scheme-handler/obsidian;
StartupWMClass=obsidian
DESKTOP
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

    return 0
}

install_obsidian() {
    if OBSIDIAN="$(find_obsidian)"; then
        good 'Obsidian is already installed'
        return 0
    fi
    if [ "$PLATFORM" = macos ]; then install_obsidian_macos || true
    else install_obsidian_linux || true
    fi
    if OBSIDIAN="$(find_obsidian)"; then
        good 'Obsidian installed'
    else
        OBSIDIAN=''
        warn 'Could not install Obsidian automatically.'
        dim 'Get it from https://obsidian.md - everything below still works without it.'
    fi
}

# ── Everything that actually runs ─────────────────────────────────────────

main() {
    case "$(uname -s)" in
        Darwin) PLATFORM=macos ;;
        Linux)  PLATFORM=linux ;;
        *)      stop_here "This installer does not know how to set up $(uname -s)." \
                          'On Windows, use Install-Ruliax-Wiki.cmd instead.' ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)  ARCH=amd64 ;;
        arm64|aarch64) ARCH=arm64 ;;
        *) stop_here "Unsupported processor: $(uname -m)." 'Ask a founder to build for it.' ;;
    esac

    printf '\n  %s\n' "Ruliax Wiki"
    printf '  %s\n\n' "${C_DIM}Setting up this computer. It takes about five minutes.${C_OFF}"
    dim 'Everything this installs is ordinary, publicly available software.'
    dim 'It does not touch files you already have.'

    head_ where
    say "the wiki will live in  $ROOT"

    head_ software
    install_git
    ensure_local_bin_on_path
    install_gh
    install_obsidian

    # ── GitHub ────────────────────────────────────────────────────────────

    head_ github

    if gh auth status >/dev/null 2>&1; then
        good "already signed in as $(gh api user --jq .login 2>/dev/null || echo '?')"
    else
        [ -n "$TTY" ] || stop_here 'Cannot sign you in without a terminal to type into.' \
                                   'Open Terminal and run this again there.'
        printf '\n'
        say 'A browser is about to open so you can sign in to GitHub.'
        say 'Copy the code shown below, paste it into the browser, then come back here.'
        printf '\n'
        # --web is the flow a non-technical person can actually finish: a short
        # code and a browser. No tokens to generate, no SSH keys to make.
        #
        # < "$TTY" because when this script is piped into bash, gh's stdin is
        # the rest of the script - it would read a line of shell source as your
        # answer and give up before the browser ever opened.
        if ! gh auth login --hostname github.com --git-protocol https --web < "$TTY"; then
            stop_here 'Sign-in did not finish.' 'Run this again whenever you are ready.'
        fi
        good 'signed in'
    fi

    # Teaches git itself to use those credentials, so pushing never prompts.
    gh auth setup-git >/dev/null 2>&1 || true

    # ── The wiki ──────────────────────────────────────────────────────────

    head_ download

    if [ -d "$ROOT/.git" ]; then
        say 'already downloaded - checking for updates'
        if git -C "$ROOT" pull --ff-only >/dev/null 2>&1; then good 'up to date'
        else warn 'could not update - carrying on with what is here'
        fi
    else
        gh repo clone "$SLUG" "$ROOT" >/dev/null 2>&1 || true
        [ -d "$ROOT/.git" ] || stop_here "Could not download $SLUG." \
            'Most likely your GitHub account has not been added yet. Ask a founder, then run this again.'
        good 'downloaded'
    fi

    # ── Hand over ─────────────────────────────────────────────────────────
    # Everything past this point is the same script an existing teammate runs,
    # so there is one description of a working machine, not two.

    if ! bash "$ROOT/setup.sh"; then
        printf '\n'
        bad 'Setup did not finish cleanly. The messages above say why.'
        exit 1
    fi

    head_ done
    good 'This computer is ready.'
    printf '\n'
    say 'Open Obsidian and pick a vault from the list. That is the whole workflow.'
    printf '\n'
    dim 'Your notes save and sync by themselves. You never need to run this again -'
    dim 'except when your access changes, when running it once more catches up.'

    if [ -n "$OBSIDIAN" ] && [ -n "$TTY" ]; then
        printf '\n  Open Obsidian now? [Y/n] '
        read -r answer < "$TTY" || answer=n
        case "$answer" in
            [Nn]*) ;;
            *) if [ "$PLATFORM" = macos ]; then open "$OBSIDIAN"
               else ("$OBSIDIAN" >/dev/null 2>&1 &)
               fi ;;
        esac
    fi

    exit 0
}

# The last line of the file, deliberately. See the note at the top: piped into
# bash, a truncated download must do nothing rather than half of something.
main "$@"
