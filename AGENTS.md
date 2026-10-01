# omarchy-desktop: notes for agents

A desktop layer for Omarchy (taskbar, Super menu, window handling,
screenshots, agents, icons) that other people install and update. README.md
says what it is; this file says how to work on it.

## No personal information, ever

This repo is shared. Nothing in it may identify who wrote or changed it:

- **No names** of the maintainer, contributors or anyone else in files,
  comments, docs, commit messages or generated output. Not in "author"
  fields either (plugin metadata, package manifests, headers): use
  `omarchy-desktop`. Say "the maintainer" or "you" in prose.
- **No email addresses**, usernames or account handles, except the repo's
  own GitHub owner where a URL needs it (`raccoondata/omarchy-desktop`).
- **No home paths** (`/home/<someone>/...`): `$HOME`, `~` or
  `os.getenv("HOME")` in code, `~` in docs. No machine-specific paths,
  hostnames, IP addresses or serial numbers either.
- **Commit as the project**: this clone's git config is
  `omarchy-desktop <334392459+raccoondata@users.noreply.github.com>`. Don't
  commit with a personal identity; a contributor's own clone should use the
  same (`git config user.name omarchy-desktop`, `git config user.email ...`).
  A `Co-Authored-By:` line naming the AI model is fine; one naming a person
  is not.
- Copying from elsewhere (transcripts, logs, another repo, a user's config)?
  Scrub it first.

`omarchy-desktop release` refuses to publish if a tracked file contains a
home path, an email address or a name it knows about
(`bin/omarchy-desktop`, `privacy_check`). Run it any time:
`omarchy-desktop privacy`.

## How the repo works

- `home/` mirrors the home folder; `manifest` lists what the desktop owns.
  A new file only ships once it's in `manifest`. Everything else in someone's
  home is theirs: never overwrite it; hook in (see `install.sh` step 3).
- Portable by default: no assumptions about the user, the hardware or other
  installed software. Detect (`reboot-to-windows --check`) or make optional
  (`desktop.conf`, `setup-remote`) anything machine-specific.
- The maintainer edits the live files in `~/.config/...`; config-history
  copies them into `home/` and commits to `main`. Others get changes only
  through `omarchy-desktop release` (one commit on `stable`), which runs
  selfcheck and the privacy check first.
- The line icons are the Line Icons plugin's, its own repo
  (omarchy-line-icons, installed at `~/.config/omarchy/plugins/line-icons`):
  the modules import its `lib/` (LineIcons.js, IconMatch.js, IconColors.js).
  Draw icons with its `line-icons` skill; never edit its built files by hand.
  `install.sh` adds it before touching any file (no plugin, no install) and
  marks `line_icons=added` in desktop.conf; `uninstall.sh` removes it only then.
- Shell scripts: bash, `set -euo pipefail`, a header comment with usage.
  Python tools: a docstring with usage, `-h`, exit 0 ok / 1 failed / 2 usage.
  Comments explain why, in plain words.
