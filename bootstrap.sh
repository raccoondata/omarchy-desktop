#!/usr/bin/env bash
# Sets up omarchy-desktop on an Omarchy PC, from nothing, in one go:
#
#   curl -fsSL <this file's raw URL> | bash
#
# 1. installs GitHub's command-line tool (github-cli)
# 2. signs you in to GitHub in the browser (the desktop's repo is private)
# 3. accepts your invite to the repo, if it's waiting
# 4. downloads the desktop and runs its installer
# Running it again just brings everything up to date.
#
# Kept in omarchy-desktop as bootstrap.sh; published as a public gist.

set -uo pipefail

main() {
  local repo="raccoondata/omarchy-desktop"
  local dest="$HOME/.local/share/omarchy-desktop/src"
  local bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' red=$'\e[31m' off=$'\e[0m'

  say()  { echo; echo "${bold}$*${off}"; }
  tell() { echo "  $*"; }
  fail() { echo; echo "${red}${bold}Stopped:${off} $*"; echo "  Send a screenshot of this window to whoever gave you this."; exit 1; }
  wait_enter() { read -r -p "  $1 " _; }

  echo "${bold}omarchy-desktop setup${off}"
  tell "This sets up the new taskbar and desktop. It takes a few minutes, and"
  tell "it'll ask you a few simple questions along the way."

  [[ $EUID -ne 0 ]] || fail "run this in a normal terminal, not as root (no sudo in front)."
  command -v omarchy >/dev/null || fail "this computer doesn't have Omarchy."
  curl -fsI --max-time 10 https://github.com >/dev/null 2>&1 || fail "can't reach the internet. Connect to Wi-Fi or a cable, then run it again."

  # --- 1 -----------------------------------------------------------------------
  say "Step 1 of 4: GitHub's tool"
  if command -v gh >/dev/null; then
    tell "${green}already installed${off}"
  else
    tell "When it asks for your ${bold}password${off}, type the one you log in to"
    tell "this computer with and press Enter. ${dim}(Nothing shows while you type. That's normal.)${off}"
    yay -S --needed --noconfirm github-cli || fail "couldn't install github-cli."
    command -v gh >/dev/null || fail "github-cli didn't install."
  fi

  # --- 2 -----------------------------------------------------------------------
  say "Step 2 of 4: Sign in to GitHub"
  if gh auth status -h github.com >/dev/null 2>&1; then
    tell "${green}already signed in${off} as $(gh api user -q .login 2>/dev/null)"
  else
    tell "Next, a code gets copied for you and GitHub opens in your browser."
    tell "In the browser:"
    tell "  1. sign in to GitHub (or make a free account) if it asks"
    tell "  2. click in the code box and press ${bold}Ctrl+V${off} to paste the code"
    tell "  3. click ${bold}Continue${off}, then ${bold}Authorize${off}"
    tell "Then come back to this window."
    wait_enter "Press Enter when you're ready."
    gh auth login -h github.com --web --clipboard --git-protocol https \
      || fail "the GitHub sign-in didn't finish. Run this again to retry."
  fi
  gh auth setup-git -h github.com >/dev/null 2>&1 || true

  # --- 3 -----------------------------------------------------------------------
  say "Step 3 of 4: Access to the desktop"
  local invite
  invite="$(gh api user/repository_invitations --jq ".[] | select(.repository.full_name == \"$repo\") | .id" 2>/dev/null | head -1)"
  if [[ -n $invite ]]; then
    gh api -X PATCH "user/repository_invitations/$invite" >/dev/null 2>&1 \
      && tell "${green}accepted your invite${off}" \
      || tell "couldn't accept the invite by itself; carrying on"
  fi
  until gh api "repos/$repo" >/dev/null 2>&1; do
    tell "${red}This GitHub account ($(gh api user -q .login 2>/dev/null)) can't see the desktop yet.${off}"
    tell "Ask whoever sent you this to invite that name. If they already did,"
    tell "open the invite email from GitHub and click ${bold}Accept${off}."
    wait_enter "Press Enter to check again (or close this window to stop)."
    invite="$(gh api user/repository_invitations --jq ".[] | select(.repository.full_name == \"$repo\") | .id" 2>/dev/null | head -1)"
    [[ -n $invite ]] && gh api -X PATCH "user/repository_invitations/$invite" >/dev/null 2>&1
  done
  tell "${green}you have access${off}"

  # --- 4 -----------------------------------------------------------------------
  say "Step 4 of 4: Download and install"
  if [[ -d $dest/.git ]]; then
    tell "already downloaded; getting the newest version"
    # The released branch (an older download may be on main): when it's clean.
    if [[ -z "$(git -C "$dest" status --porcelain)" ]] && git -C "$dest" fetch -q origin stable 2>/dev/null; then
      git -C "$dest" checkout -q stable 2>/dev/null || git -C "$dest" checkout -q -b stable --track origin/stable 2>/dev/null || true
    fi
    git -C "$dest" pull -q --ff-only || tell "${dim}(couldn't update it; installing what's there)${off}"
  else
    mkdir -p "$(dirname "$dest")"
    gh repo clone "$repo" "$dest" -- -q || fail "couldn't download the desktop."
    # The released branch (what updates follow), whatever the repo's default.
    git -C "$dest" checkout -q stable 2>/dev/null || true
  fi
  tell "Starting the installer. When it asks a question, the suggested answer"
  tell "is fine: just press Enter."
  "$dest/install.sh"
}

# Read answers from the keyboard even when this arrives through a pipe
# (curl ... | bash): bash has read the whole function by the time it gets here.
if [[ -t 0 ]]; then
  main "$@"
elif { : </dev/tty; } 2>/dev/null; then
  main "$@" </dev/tty
else
  main "$@"
fi
