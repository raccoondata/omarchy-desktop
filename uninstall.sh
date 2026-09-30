#!/usr/bin/env bash
set -euo pipefail

# Take omarchy-desktop out again (`omarchy-desktop uninstall`): Omarchy as it
# was, apart from your settings files (taskbar pins etc., harmless without it)
# and the packages it installed (listed at the end, to remove if you like).
# The desktop's files are moved to ~/.local/state/omarchy-desktop/backups/,
# not deleted.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
omarchy="$HOME/.config/omarchy"
state="$HOME/.local/state/omarchy-desktop"
bold=$'\e[1m' off=$'\e[0m'

echo "${bold}Uninstall omarchy-desktop${off}"
echo "Puts Omarchy's own bar, keys and menus back. Your settings files stay."
read -r -p "Go ahead? [y/N] " a || true
[[ $a == [yY]* ]] || exit 0
sudo -v

# Remote access first (it needs the desktop's script).
if grep -qx 'remote=on' "$omarchy/desktop.conf" 2>/dev/null; then
  OMARCHY_DESKTOP_INSTALL=1 "$omarchy/setup-remote" --off || true
fi

echo "- services"
for u in config-history.timer hyprland-safe-mode-agents.service lock-guard.service remote-screen.service; do
  systemctl --user disable --now "$u" >/dev/null 2>&1 || true
done

echo "- hooks into Omarchy"
hl="$HOME/.config/hypr/hyprland.lua"
sed -i '/^-- The taskbar\/Super-menu desktop (omarchy-desktop)/d; /^require("hypr.desktop")$/d' "$hl"
shell="$omarchy/shell.json"
if [[ -f $shell ]]; then
  tmp="$(mktemp)"
  jq '.bar.layout |= with_entries(.value |= map(select(.id != "taskbar" and .id != "nowplaying")))' "$shell" > "$tmp" && mv "$tmp" "$shell"
fi
menu="$omarchy/extensions/omarchy-menu.jsonc"
[[ -f $menu ]] && sed -i -E '/^\s*"(system\.lock|system\.reboot-windows|setup\.hotcorners|setup\.taskbar|update\.desktop)":/d' "$menu"
# The rescue console block in ~/.bashrc (from its comment to its fi).
[[ -f $HOME/.bashrc ]] && python3 - "$HOME/.bashrc" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n*# Text console 3 \(Ctrl\+Alt\+Delete.*?\nfi\n", "\n", s, flags=re.S)
open(p, "w").write(s)
PY
# Agent notifications back to the agents' own.
cs="$HOME/.claude/settings.json"
if [[ -f $cs ]] && grep -q agent-notify "$cs"; then
  tmp="$(mktemp)"
  jq 'def keep: map(select(all(.hooks[]?; (.command // "") | contains("agent-notify") | not)));
      (if .hooks.Stop then .hooks.Stop |= keep else . end)
      | (if .hooks.Notification then .hooks.Notification |= keep else . end)
      | (if (.hooks.Stop // [1]) == [] then del(.hooks.Stop) else . end)
      | (if (.hooks.Notification // [1]) == [] then del(.hooks.Notification) else . end)
      | (if .hooks == {} then del(.hooks) else . end)
      | del(.preferredNotifChannel)' "$cs" > "$tmp" && mv "$tmp" "$cs"
fi
cc="$HOME/.codex/config.toml"
if [[ -f $cc ]]; then
  sed -i '/^notify = \[".*agent-notify", "codex"\]$/d; /^notifications = \["approval-requested"\]$/d' "$cc"
  # A [tui] table left empty (it added it) goes too.
  python3 - "$cc" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n*\[tui\]\n(?=\s*(\[|$))", "\n", s)
open(p, "w").write(s.rstrip("\n") + "\n")
PY
fi
gc="$HOME/.grok/config.toml"
[[ -f $gc ]] && sed -i '/^\[ui.notifications\]$/{N;/\ncondition = "never"$/d}' "$gc"

echo "- the desktop's files"
backup="$state/backups/uninstalled-$(date +%F-%H%M%S)"
if [[ -f $state/installed-files ]]; then
  while read -r f; do
    [[ -e $HOME/$f ]] || continue
    mkdir -p "$backup/$(dirname "$f")"
    mv "$HOME/$f" "$backup/$f"
  done < "$state/installed-files"
  rm -f "$state/installed-files"
fi
rmdir "$HOME/.config/hypr/desktop" 2>/dev/null || true
rm -f "$HOME/.local/lib/hyprland/libhyprdragevents.so" "$HOME/.local/lib/hyprland/libhyprbars-fixed.so" "$state/plugins-built"
rm -f "$HOME/.local/bin/omarchy-desktop"
systemctl --user daemon-reload

echo "- system files"
sudo rm -f /etc/omarchy-rescue.issue "/etc/systemd/system/getty@tty3.service.d/rescue-issue.conf" \
  /etc/sudoers.d/50-chvt /etc/sudoers.d/50-reboot-to-windows
sudo systemctl daemon-reload

hyprctl reload >/dev/null 2>&1 || true
omarchy-restart-shell >/dev/null 2>&1 || true
nautilus -q >/dev/null 2>&1 || true

echo
echo "${bold}Done.${off} Log out and back in to finish (the plugins stay loaded until then)."
echo "Its files are in ${backup/#$HOME/\~}; its source folder ($repo) you can delete."
echo "Packages it installed, if you want them gone too:"
echo "  yay -R hyprland-plugin-hyprbars    (the others, like hyprlock and jq, are harmless)"
