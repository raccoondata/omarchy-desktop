#!/usr/bin/env bash
set -euo pipefail

# omarchy-desktop: a taskbar, Super menu and Windows-style window handling for
# Omarchy, plus screenshots and coding agents built in. See README.md.
#
#   ./install.sh            install (or repair); asks about the optional parts
#   ./install.sh --update   what `omarchy-desktop update` runs after pulling:
#                           the same, without questions
#
# Safe to run again. It only touches:
#   - the desktop's own files (listed in ./manifest); the ones it replaces are
#     kept in ~/.local/state/omarchy-desktop/backups/
#   - defaults for its settings files, only where you have none (./templates)
#   - one line each in ~/.config/hypr/hyprland.lua, ~/.bashrc and your agents'
#     settings, the taskbar widgets in ~/.config/omarchy/shell.json and a few
#     entries in Omarchy's menu (extensions/omarchy-menu.jsonc)
#   - system files (setup-system: asks for your password)
# Your own monitors, input, keybindings, theme and apps stay yours.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
omarchy="$HOME/.config/omarchy"
state="$HOME/.local/state/omarchy-desktop"
conf="$omarchy/desktop.conf"
update=false
[[ ${1:-} == --update ]] && update=true
bold=$'\e[1m' dim=$'\e[2m' off=$'\e[0m'
failed=()
steps=8

step() { echo; echo "${bold}[$1/$steps] $2${off}"; }
warn() { echo "  ! $*"; failed+=("$*"); }
ask() {  # ask <question>  (default no)
  local a
  read -r -p "  $1 [y/N] " a
  [[ $a == [yY]* ]]
}
conf_get() { sed -n "s/^$1=//p" "$conf" 2>/dev/null | tail -1; }
conf_set() {
  local tmp
  mkdir -p "$(dirname "$conf")"
  tmp="$(mktemp)"
  { [[ -f $conf ]] && grep -v "^$1=" "$conf" || true; echo "$1=$2"; } > "$tmp"
  mv "$tmp" "$conf"
}

# --- before anything -----------------------------------------------------------
command -v omarchy >/dev/null || { echo "This needs Omarchy (https://omarchy.org): install it first."; exit 1; }
if [[ ! -f /usr/share/omarchy/default/hypr/bootstrap.lua || ! -f $HOME/.config/hypr/hyprland.lua ]]; then
  echo "This needs an Omarchy with the Lua Hyprland config (~/.config/hypr/hyprland.lua)."
  echo "Update Omarchy first (Super+Alt+Space > Update > Omarchy)."
  exit 1
fi
[[ $EUID -ne 0 ]] || { echo "Run this as yourself, not root (it asks for your password when it needs it)."; exit 1; }
command -v yay >/dev/null || { echo "This needs yay (part of Omarchy)."; exit 1; }
if ! curl -fsI --max-time 8 https://aur.archlinux.org >/dev/null 2>&1; then
  echo "Can't reach the internet (aur.archlinux.org); it's needed for packages. Connect, then run this again."
  exit 1
fi
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || echo "${dim}(Not in a Hyprland session: it'll take effect at your next login.)${off}"
export OMARCHY_DESKTOP_INSTALL=1   # setup scripts skip their "Press Enter" pause

# Everything it prints also goes to a log, for when something goes wrong.
mkdir -p "$state"
log="$state/install.log"
echo "=== $(date '+%F %T') install.sh ${1:-} ($(git -C "$repo" rev-parse --short HEAD 2>/dev/null))" >> "$log"
exec > >(tee -a "$log") 2>&1

if $update; then
  echo "${bold}Updating omarchy-desktop${off} ${dim}($(git -C "$repo" log -1 --format='%h, %cd' --date=short 2>/dev/null))${off}"
else
  echo "${bold}Installing omarchy-desktop${off}"
  echo "A taskbar, Super menu and Windows-style window handling for Omarchy. Your own"
  echo "monitors, keybindings, theme and apps are left alone."
fi
sudo -v

# --- 1 files -----------------------------------------------------------------
step 1 "Desktop files"
mapfile -t owned < <(sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$repo/manifest")
backup="$state/backups/$(date +%F-%H%M%S)"
mkdir -p "$state"
list_new="$state/installed-files.new"
: > "$list_new"
for p in "${owned[@]}"; do
  p="${p%/}"
  src="$repo/home/$p"
  if [[ -d $src ]]; then
    mkdir -p "$HOME/$p"
    rsync -a --backup --backup-dir="$backup/$p" "$src/" "$HOME/$p/"
    (cd "$src" && find . -type f -printf "$p/%P\n") >> "$list_new"
  elif [[ -f $src ]]; then
    mkdir -p "$(dirname "$HOME/$p")"
    rsync -a --backup --backup-dir="$backup/$(dirname "$p")" "$src" "$HOME/$p"
    echo "$p" >> "$list_new"
  fi
done
# Files an earlier version installed that this one dropped (moved aside, not
# deleted). Only ours: anything else in those folders is yours.
if [[ -f $state/installed-files ]]; then
  while read -r f; do
    [[ -f $HOME/$f ]] || continue
    mkdir -p "$backup/$(dirname "$f")"
    mv "$HOME/$f" "$backup/$f"
    echo "  removed $f (no longer part of the desktop)"
  done < <(comm -23 <(sort -u "$state/installed-files") <(sort -u "$list_new"))
fi
mv "$list_new" "$state/installed-files"
# Settings files the desktop reads, only where there are none yet.
(cd "$repo/templates" && find . -type f -printf '%P\n') | while read -r f; do
  [[ -e $HOME/$f ]] && continue
  mkdir -p "$(dirname "$HOME/$f")"
  cp "$repo/templates/$f" "$HOME/$f"
  echo "  default $f"
done
mkdir -p "$HOME/.local/bin"
ln -sfn "$repo/bin/omarchy-desktop" "$HOME/.local/bin/omarchy-desktop"
conf_set repo "$repo"
if [[ -d $backup ]]; then
  echo "  done; files it replaced are in ${backup/#$HOME/\~}"
else
  echo "  done"
fi

# --- 2 keybindings ------------------------------------------------------------
step 2 "Keybindings"
if [[ -n "$(conf_get keys)" ]]; then
  echo "  $(conf_get keys) ${dim}(change: omarchy-desktop keys all|new|off)${off}"
elif $update; then
  conf_set keys all
else
  cat <<EOF
  ${bold}New${off} (no Omarchy key changes)
    Super, twice             the Super menu: apps, search, now playing, ask an agent
    Super+Alt+A              ask an agent about the selected text
    Super+C, twice           your first coding agent   (once: copy, as before)
    Super+V, twice           your second coding agent  (once: paste, as before)
    Super+Q, twice           close the window
    Super+Ctrl+L             lock, with a backup lock screen   (same key)
EOF
  "$omarchy/reboot-to-windows" --check && \
  echo "    Super+Shift+Esc, twice   restart into Windows"
  cat <<EOF
  ${bold}Windows-style${off} (these change Omarchy's keys)
    Super+W / A / S / D      focus the window up / left / down / right
                             ${dim}was: W close window (now Super+Q twice), S scratchpad${off}
    Super+Up / Down          maximize, restore, minimize     ${dim}was: focus up / down${off}
    Super+Left / Right       dock to the left / right half   ${dim}was: focus left / right${off}
    Super+Shift+Up / Down    restore all / minimize all      ${dim}was: swap window up / down${off}
    Super+Alt+S              minimize                        ${dim}was: to the scratchpad${off}
    Super+Tab                window switcher                 ${dim}was: next workspace${off}
    Print Screen             screenshot, then the editor with the ask panel
                             ${dim}was: Omarchy's screenshot (picker, saved, copied)${off}
    Ctrl+Alt+Delete          rescue console                  ${dim}was: close all windows${off}
    Super+G, twice           a terminal in this folder       ${dim}once: grouping, as before${off}
    Super+Return, twice      another window of this app      ${dim}once: terminal, as before${off}
    Caps Lock                a second Super key              ${dim}was: Compose (now Right Alt);
                             real Caps Lock: both Shifts${off}
  Mouse (always): middle-drag a window by its top to move it; Shift+click a
  taskbar icon for a new window.
EOF
  read -r -p "  Install [a]ll, only the [n]ew ones, or [s]kip? [A/n/s] " a
  case "$a" in
    [nN]*) conf_set keys new ;;
    [sS]*) conf_set keys off ;;
    *) conf_set keys all ;;
  esac
  echo "  keybindings: $(conf_get keys) ${dim}(change any time: omarchy-desktop keys all|new|off)${off}"
fi

# --- 3 hook up -------------------------------------------------------------------
step 3 "Hooking into Omarchy"
# Hyprland: hypr/desktop.lua after your own files.
hl="$HOME/.config/hypr/hyprland.lua"
if ! grep -q 'require("hypr.desktop")' "$hl"; then
  cp "$hl" "$hl.bak.$(date +%s)"
  line='-- The taskbar/Super-menu desktop (omarchy-desktop): hypr/desktop.lua.\nrequire("hypr.desktop")'
  if grep -q '^require("default.hypr.toggles")' "$hl"; then
    sed -i "s|^require(\"default.hypr.toggles\")|$line\nrequire(\"default.hypr.toggles\")|" "$hl"
  else
    printf '\n%b\n' "$line" >> "$hl"
  fi
  echo "  hyprland.lua loads hypr/desktop.lua"
fi

# The bar: the taskbar after the workspaces, now-playing after the clock (in
# place of Omarchy's media widget).
shell="$omarchy/shell.json"
[[ -f $shell ]] || cp /usr/share/omarchy/config/omarchy/shell.json "$shell"
tmp="$(mktemp)"
jq '
  def has_id($id): any(.bar.layout[][]?; .id == $id);
  def after($side; $prev; $entry):
    .bar.layout[$side] = (.bar.layout[$side] // [] | (map(.id) | index($prev)) as $i
      | if $i == null then . + [$entry] else .[:$i+1] + [$entry] + .[$i+1:] end);
  .bar.layout |= with_entries(.value |= map(select(.id != "omarchy.media")))
  | if has_id("taskbar") then . else after("left"; "omarchy.workspaces"; {"id": "taskbar", "type": "qml"}) end
  | if has_id("nowplaying") then . else after("center"; "omarchy.clock"; {"id": "nowplaying", "type": "qml"}) end
' "$shell" > "$tmp" && if ! cmp -s "$tmp" "$shell"; then
  cp "$shell" "$shell.bak.$(date +%s)"
  mv "$tmp" "$shell"
  echo "  taskbar and now-playing on the bar"
else
  rm -f "$tmp"
fi

# Omarchy's menu: lock (with the backup lock), Restart into Windows (only
# with Windows), the settings window, and updating this desktop.
menu="$omarchy/extensions/omarchy-menu.jsonc"
[[ -f $menu ]] || { mkdir -p "$(dirname "$menu")"; cp /usr/share/omarchy/config/omarchy/extensions/omarchy-menu.jsonc "$menu"; }
entries=(
  '"system.lock": {"icon": "", "label": "Lock", "action": "$HOME/.config/omarchy/lock"},'
  '"system.reboot-windows": {"when":"\"$HOME/.config/omarchy/reboot-to-windows\" --check","icon":"","label":"Reboot to Windows","description":"Boot Windows once, then back to Omarchy","action":"$HOME/.config/omarchy/reboot-to-windows"},'
  '"setup.hotcorners": {"icon": "", "label": "Hot Corners", "description": "what pushing the pointer into a screen corner does", "action": "omarchy-shell -q taskbar settings corners"},'
  '"setup.taskbar": {"icon": "", "label": "Taskbar & Desktop", "description": "taskbar, windows, agents, effects, hot corners, title bars, now playing, screenshots, mouse", "action": "omarchy-shell -q taskbar settings taskbar"},'
  '"update.desktop": {"icon": "", "label": "Desktop", "description": "omarchy-desktop: taskbar, Super menu, windows", "action": "omarchy-launch-floating-terminal-with-presentation omarchy-desktop update"},'
)
added=0
for e in "${entries[@]}"; do
  key="$(sed -E 's/^"([^"]+)".*/\1/' <<<"$e")"
  grep -q "\"$key\"" "$menu" && continue
  # Before the file's last closing brace.
  python3 - "$menu" "$e" <<'PY'
import sys
p, entry = sys.argv[1], sys.argv[2]
s = open(p).read()
i = s.rstrip().rfind('}')
s = s[:i].rstrip() + ('' if s[:i].rstrip().endswith((',', '{')) else ',') + '\n  ' + entry + '\n' + s[i:]
open(p, 'w').write(s)
PY
  added=$((added + 1))
done
(( added )) && echo "  $added entries in Omarchy's menu"

# The rescue console (Ctrl+Alt+Delete): its menu opens on login at tty3.
if ! grep -q 'RESCUE_SHOWN' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'EOF'

# Text console 3 (Ctrl+Alt+Delete / Ctrl+Alt+F3) is the rescue console: log in
# and the rescue menu opens (q = plain shell, d = back to the desktop).
if [[ $(tty) == /dev/tty3 && -z ${RESCUE_SHOWN-} ]] && command -v rescue &> /dev/null; then
  export RESCUE_SHOWN=1
  rescue
fi
EOF
  echo "  rescue console menu (~/.bashrc)"
fi

# Agent notifications (finished / needs you) through the taskbar, instead of
# each agent's own.
notify="$omarchy/agent-notify"
if command -v claude >/dev/null || [[ -d $HOME/.claude ]]; then
  cs="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  [[ -s $cs ]] || echo '{}' > "$cs"
  if ! grep -q 'agent-notify' "$cs"; then
    tmp="$(mktemp)"
    jq --arg cmd "$notify claude" '
      def hook: {"hooks": [{"type": "command", "command": $cmd, "timeout": 5}]};
      .hooks.Stop = ((.hooks.Stop // []) + [hook])
      | .hooks.Notification = ((.hooks.Notification // []) + [hook])
      | .preferredNotifChannel = "notifications_disabled"
    ' "$cs" > "$tmp" && cp "$cs" "$cs.bak.$(date +%s)" && mv "$tmp" "$cs" && echo "  Claude Code notifications"
  fi
fi
if command -v codex >/dev/null || [[ -d $HOME/.codex ]]; then
  cc="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex"
  [[ -f $cc ]] || : > "$cc"
  if ! grep -q '^notify' "$cc"; then
    # A top-level key: before the first [table].
    tmp="$(mktemp)"
    awk -v line="notify = [\"$notify\", \"codex\"]" 'BEGIN{done=0} /^\[/ && !done {print line; done=1} {print} END{if(!done) print line}' "$cc" > "$tmp" && mv "$tmp" "$cc"
    echo "  Codex notifications"
  fi
  if ! grep -q '^notifications' "$cc"; then
    if grep -q '^\[tui\]' "$cc"; then
      sed -i 's/^\[tui\]/[tui]\nnotifications = ["approval-requested"]/' "$cc"
    else
      printf '\n[tui]\nnotifications = ["approval-requested"]\n' >> "$cc"
    fi
  fi
fi
if command -v grok >/dev/null || [[ -d $HOME/.grok ]]; then
  # Grok runs Claude Code's hooks (above); its own notifications would double them.
  gc="$HOME/.grok/config.toml"
  mkdir -p "$HOME/.grok"
  [[ -f $gc ]] || : > "$gc"
  if ! grep -q '^\[ui.notifications\]' "$gc"; then
    printf '\n[ui.notifications]\ncondition = "never"\n' >> "$gc"
    echo "  Grok: notifications through the taskbar"
  fi
fi

# --- 4 system ------------------------------------------------------------------
step 4 "System setup (packages, rescue console)"
"$omarchy/setup-system" || warn "setup-system failed; run ~/.config/omarchy/setup-system"

# --- 5 plugins -----------------------------------------------------------------
step 5 "Hyprland plugins (title bars, window drag events)"
stamp="$(hyprctl version -j 2>/dev/null | jq -r .commit)-$(cat "$omarchy"/hyprland-plugins/{build,hyprbars-commit,hyprbars-fixes.patch} "$omarchy"/hyprland-plugins/dragevents/* 2>/dev/null | md5sum | cut -c1-12)"
if [[ "$(cat "$state/plugins-built" 2>/dev/null)" == "$stamp" && -f $HOME/.local/lib/hyprland/libhyprdragevents.so ]]; then
  echo "  up to date"
elif "$omarchy/hyprland-plugins/build"; then
  echo "$stamp" > "$state/plugins-built"
else
  warn "plugin build failed (title bars fall back to off; window drops on workspaces don't work)"
fi

# --- 6 services ------------------------------------------------------------------
step 6 "Background services"
chmod +x "$HOME/.local/bin/rescue" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now config-history.timer >/dev/null 2>&1 || warn "couldn't start the config history timer"
systemctl --user enable hyprland-safe-mode-agents.service >/dev/null 2>&1 || warn "couldn't enable the safe-mode agents"
systemctl --user enable --now lock-guard.service >/dev/null 2>&1 || warn "couldn't start the lock guard"
[[ "$(conf_get remote)" == on ]] && systemctl --user restart remote-screen.service 2>/dev/null
echo "  config history (local undo), crash helper, backup lock guard"

# --- 7 optional ------------------------------------------------------------------
step 7 "Optional"
if [[ "$(conf_get remote)" == on ]]; then
  # Re-applied on a full install (only restarts RustDesk if something changed).
  $update || "$omarchy/setup-remote" || warn "setup-remote failed; run ~/.config/omarchy/setup-remote"
  echo "  remote access (RustDesk): on ${dim}(omarchy-desktop remote off to undo)${off}"
elif $update || [[ "$(conf_get remote)" == off ]]; then
  echo "  remote access (RustDesk): off ${dim}(omarchy-desktop remote on)${off}"
else
  echo "  Remote access: reach this PC from your phone or another PC with RustDesk,"
  echo "  even after a reboot or with the monitor off. It also logs you in"
  echo "  automatically after a reboot (then locks the screen at once)."
  if ask "Set up remote access?"; then
    "$omarchy/setup-remote" || warn "setup-remote failed; run ~/.config/omarchy/setup-remote"
  else
    conf_set remote off
    echo "  ${dim}skipped; omarchy-desktop remote on, any time${off}"
  fi
fi

# --- 8 reload ---------------------------------------------------------------------
step 8 "Reloading"
if hyprctl version >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 && echo "  Hyprland config reloaded"
  omarchy-restart-shell >/dev/null 2>&1 && echo "  shell restarted"
  nautilus -q >/dev/null 2>&1 || true
fi
conf_set version "$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"

echo
if (( ${#failed[@]} )); then
  echo "${bold}Finished with problems:${off}"
  printf '  - %s\n' "${failed[@]}"
else
  echo "${bold}Done.${off}"
fi
$update && exit 0
if [[ "$(conf_get keys)" == off ]]; then
  keys_line="Keybindings: none added (omarchy-desktop keys new, for the Super menu and more)."
else
  keys_line="Double-tap Super: the Super menu. Super+K: every keybinding."
fi
cat <<EOF

${bold}Next${off}
  1. Log out and back in (loads the title bars and window drag plugins).
  2. $keys_line
     Settings: Super+Alt+Space > Setup > Taskbar & Desktop.
  3. Updates: omarchy-desktop update (or Super+Alt+Space > Update > Desktop).
  4. Something off? omarchy-desktop check. To remove it all: omarchy-desktop uninstall
  (What it printed is in ${log/#$HOME/\~}.)
EOF
