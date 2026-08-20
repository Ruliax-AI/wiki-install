# Getting set up

This puts the company's notes on your computer. About five minutes, once.

You need the GitHub account you were asked to create. Nothing else — it
installs everything it needs.

---

# Mac

## 1. Open Terminal

Press **⌘ + Space**. A search box appears in the middle of the screen. Type:

```
terminal
```

Press **Return**. A window opens with white or black text and a blinking
cursor. This is Terminal. Nothing you do here can break your computer.

## 2. Paste one line

Copy the line below — all of it, it is one line even if it wraps on screen:

```
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | bash
```

Click into the Terminal window, press **⌘ + V** to paste, then press
**Return**.

You should see:

```
  Ruliax Wiki
  Setting up this computer. It takes about five minutes.
```

If nothing happens when you paste, click once inside the Terminal window
first — it needs to be the active window.

## 3. If a "Command Line Tools" box appears

Only on a Mac that has never had developer tools installed. A grey box appears
saying *"The 'git' command requires the command line developer tools."*

Click **Install**, then **Agree**. It downloads in the background — a few
minutes. Terminal shows `waiting....` with dots appearing. Leave both windows
alone until it continues by itself.

## 4. Sign in to GitHub

Terminal will show something like:

```
! First copy your one-time code: A1B2-C3D4
Press Enter to open github.com in your browser...
```

- **Select the code** (`A1B2-C3D4`) with your mouse and copy it with **⌘ + C**
- Press **Return**. Your browser opens GitHub
- Sign in if it asks
- Paste the code with **⌘ + V** and click **Continue**
- Click **Authorize github**
- Go back to Terminal

You may be asked for your Mac password at some point. That is macOS, not us —
type it and press Return. **The cursor will not move and no dots appear.** That
is normal; it is still receiving what you type.

## 5. Wait for the finish

When it is done you will see:

```
== done ======================================================
  [ok]   This computer is ready.
```

It then asks **Open Obsidian now? [Y/n]** — press **Return** for yes.

You can close Terminal. You will not need it again.

## If you would rather not use Terminal

There is a file on the release page, `Install-Ruliax-Wiki-Mac.zip`, containing
exactly the same script. Unzip it, then **right-click** the file inside and
choose **Open**, then **Open** again.

Right-click, not double-click: macOS refuses to run anything downloaded from
the internet unless the developer paid Apple for a certificate, and we have
not. On the newest macOS even right-click may not offer it, and you would have
to go to **System Settings → Privacy & Security** and click **Open Anyway**
near the bottom.

That is why the Terminal line above is the recommended route — nothing is
"opened", so there is nothing for macOS to block.

---

# Linux

Open a terminal and run:

```
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | bash
```

It installs git through your distribution's package manager, so it will ask
for your password once. Obsidian comes from Obsidian's own release — the `.deb`
on Debian and Ubuntu, otherwise their official tarball unpacked into
`~/.local/share/obsidian`, with a menu entry and icon.

Then follow steps 4 and 5 from the Mac instructions above; they are identical.

Tested on Debian/Ubuntu, Fedora, Arch, openSUSE and Alpine by inspection only —
if something breaks, the message will say what, and it is safe to re-run.

---

# Windows

1. Double-click **Install-Ruliax-Wiki.cmd**
2. If Windows says *"Windows protected your PC"*, click **More info** →
   **Run anyway**
3. If it asks permission to install something, click **Yes**
4. A browser opens. Sign in to GitHub and paste the code shown in the window
5. Wait. When it says *This computer is ready*, you are done

---

# What happens next

The installer prints where your notes are before it finishes. It looks like
this, and it is worth reading rather than closing:

```
  Your notes are here:
      C:\Users\you\RuliaxWiki\vaults

      product    Building and operating the actual product
      research   Exploratory technical work
      business   Company operating knowledge, non-confidential
      people     Team context, onboarding, company history
      direction  High-signal company direction
      founders   Privileged founder knowledge
```

You will see only the areas you have been given. The rest are not on your
computer at all.

### Finding them in Obsidian

Each of those folders is a **vault**, and the installer has already added them
to Obsidian's list. Obsidian opens one vault at a time.

To move between them, use the **vault switcher** — the icon at the bottom of
the narrow strip down the left-hand side of the window.

If the list looks empty, quit Obsidian completely, run the installer once more,
then open Obsidian afterwards. Obsidian rewrites that list when it closes, so a
change made while it is open gets discarded.

Failing that, **Open folder as vault** and point it at one of the folders
above. Nothing is lost either way — the notes are ordinary files on your disk.

### Which one first

**people.** It holds onboarding and company history, and is written for
somebody who has just arrived. Then `direction`, for what the company is
trying to do.

That is the whole thing. Your notes save and sync by themselves. You never
press save, and you never need to know anything about git.

---

# If something goes wrong

**"Could not download..."** — your GitHub account has not been added yet.
Message whoever sent you this, then run it again.

**Only some areas appeared** — that is correct. You get the ones you have been
given; the rest do not appear at all.

**"command not found: curl"** — rare, and only on Linux. Install curl with your
package manager and run it again.

**Anything else** — run it again. It is safe to run as many times as you like:
it picks up where it left off and never touches work you have already done.

**Later on**, if your access changes, run it once more. That is also what adds
a new area when you are given one.

---

# For the suspicious

Pasting a command from the internet into a terminal deserves a second look, and
you are right to want one. Read the whole thing first:

```
curl -fsSL https://raw.githubusercontent.com/Ruliax-AI/wiki-install/main/install.sh | less
```

Press **q** to quit when you are done reading.

It installs three well-known open source programs — git, the GitHub CLI and
Obsidian — each downloaded from its own official release, then clones the
company repository into your home folder. It contains no passwords, and without
a GitHub account that has been granted access it does nothing at all.
