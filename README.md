# Start here

This sets your computer up to work with the Ruliax knowledge base. About five
minutes, and you only do it once.

You need the GitHub account you were asked to create. Nothing else — it
installs everything it needs.

---

## Mac or Linux

Open Terminal — on a Mac, press **⌘ + Space**, type `terminal`, press Return —
then paste this one line and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | bash
```

## Windows

Download **[Install-Ruliax-Wiki.cmd](https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/Install-Ruliax-Wiki.cmd)**
and double-click it.

If Windows says *"Windows protected your PC"*, click **More info** →
**Run anyway**.

---

## Then what

A browser opens so you can sign in to GitHub. Follow the prompts — if it asks
for your computer password at some point, that is normal.

When it finishes it prints where your notes are and lists the areas you have
access to. Open **Obsidian** and start with the **people** vault; it is written
for somebody who has just arrived.

You will only see the areas you have been given. If one you expected is
missing, that is a permissions change on GitHub, not a problem with your
machine — ask whoever sent you here.

Your notes save and sync by themselves. **You never press save**, and you never
need to know anything about git.

**[Instructions.md](Instructions.md)** is the same thing step by step, with
what each screen looks like and what to do when something goes wrong.

---

## What it installs

Three well-known open source programs, each from its own official release:

- [git](https://git-scm.com)
- the [GitHub CLI](https://cli.github.com)
- [Obsidian](https://obsidian.md)

Then it downloads the knowledge repositories your GitHub account can read, and
sets Obsidian up to open them.

Safe to run again at any time. Re-running is also how a change to your access
reaches your machine.

---

## Why this repository is public

Only so the Mac line above works. macOS quarantines anything downloaded through
a browser, and Gatekeeper then refuses to run it unless the developer has paid
Apple for a certificate. Piping into `bash` opens nothing, so there is nothing
to block — but that needs a URL reachable *before* you have any credentials.

**There is nothing sensitive here.** These scripts hold no tokens and no
company content. Everything they download lives in a private repository, and
without a GitHub account that has been granted access they install three open
source programs and stop.

## Reading it before you run it

Sensible, and encouraged:

```bash
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | less
```

Press **q** to quit. Everything that does anything lives inside `main()`,
called on the very last line, so a download cut off halfway executes nothing at
all rather than half an installer.

## Where these come from

Generated from `install/` in the private `Ruliax-AI/RuliaxWiki` repository and
pushed here by its `release` command. **Edit them there, not here** — anything
changed here is overwritten on the next release. This README is not synced and
can be edited freely.

`raw.githubusercontent.com` caches for about five minutes, so a freshly
published change is not instantly what these links serve.
