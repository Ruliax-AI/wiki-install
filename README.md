# Ruliax Wiki installer

Sets up a Mac or Linux machine to work with the Ruliax knowledge base.

```bash
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | bash
```

That installs git, the [GitHub CLI](https://cli.github.com) and
[Obsidian](https://obsidian.md) if they are missing, signs you in to GitHub in
a browser, and sets up the knowledge domains your account has access to. About
five minutes, and you only do it once.

**On Windows**, ask whoever sent you here for `Install-Ruliax-Wiki.cmd` and
double-click it instead.

## Why this repository is public

Only so that the line above works. macOS quarantines anything downloaded
through a browser and Gatekeeper then refuses to run it, so a downloaded
installer cannot simply be double-clicked. Piping into `bash` opens nothing,
so there is nothing to block — and that needs a URL reachable before you have
any credentials.

**There is nothing sensitive here.** This script holds no tokens and no
company content. Everything it downloads lives in a private repository, and
without a GitHub account that has been granted access it does precisely
nothing beyond installing three well-known open source programs.

## What it does, in order

1. Installs `git` — Apple Command Line Tools on macOS, your package manager on Linux
2. Installs the GitHub CLI into `~/.local/bin`, straight from its own release

   Deliberately not via Homebrew: on a Mac without it, that would mean a
   multi-gigabyte Xcode download before the first note is read.
3. Installs Obsidian, from Obsidian's own release
4. Signs you in to GitHub with the browser code flow
5. Clones the private control repository into `~/RuliaxWiki`
6. Runs that repository's own `setup.sh`, which does the rest

It is safe to run again at any time. Re-running is also how a change to your
access reaches your machine.

## Reading it first

Sensible, and encouraged — piping a script from the internet into a shell is
worth being careful about. The whole thing is one file:

```bash
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | less
```

Everything that does anything lives inside `main()`, called on the very last
line, so that a download cut off halfway executes nothing at all rather than
half an installer.

## Where it comes from

`install.sh` is generated from `install/Install-Ruliax-Wiki.command` in the
private `Ruliax-AI/RuliaxWiki` repository, and pushed here by that repository's
`release` command. **Edit it there, not here** - anything changed here is
overwritten on the next release. This README is not synced, and can be edited
freely.

Note that `raw.githubusercontent.com` caches for about five minutes, so a
freshly published change is not instantly what the one-liner serves.
