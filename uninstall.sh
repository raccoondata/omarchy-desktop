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
for u in config-history.timer lock-guard.service remote-screen.service; do
  systemctl --user disable --now "$u" >/dev/null 2>&1 || true
done

echo "- hooks into Omarchy"
hl="$HOME/.config/hypr/hyprland.lua"
sed -i '/^-- The taskbar\/Super-menu desktop (omarchy-desktop)/d; /^require("hypr.desktop")$/d' "$hl"
shell="$omarchy/shell.json"
if [[ -f $shell ]]; then
  tmp="$(mktemp)"
  jq '.bar.layout |= with_entries(.value |= map(select(.id != "taskbar" and .id != "nowplaying" and .id != "now-playing")))' "$shell" > "$tmp" && mv "$tmp" "$shell"
fi
menu="$omarchy/extensions/omarchy-menu.jsonc"
[[ -f $menu ]] && sed -i -E '/^\s*"(system\.lock|system\.reboot-windows|setup\.taskbar|update\.desktop)":/d' "$menu"
# The rescue console block in ~/.bashrc (from its comment to its fi).
[[ -f $HOME/.bashrc ]] && python3 - "$HOME/.bashrc" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n*# Text console 3 \(Ctrl\+Alt\+Delete.*?\nfi\n", "\n", s, flags=re.S)
open(p, "w").write(s)
PY
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
# The desktop's plugins: removed if the desktop added them; ones you added
# yourself stay.
for id in agent-tools hot-corners super-menu now-playing line-icons desktop-core; do
  dir="$HOME/.config/omarchy/plugins/$id"
  key="plugin_${id//-/_}"
  mark="$(sed -n "s/^$key=//p" "$HOME/.config/omarchy/desktop.conf" 2>/dev/null | tail -1)"
  [[ $id == line-icons && -z $mark ]] && mark="$(sed -n 's/^line_icons=//p' "$HOME/.config/omarchy/desktop.conf" 2>/dev/null | tail -1)"
  if [[ $mark == added && -d $dir && ! -L $dir ]]; then
    "$dir/bin/teardown" >/dev/null 2>&1 || true
    omarchy-plugin-disable "$id" >/dev/null 2>&1 || true
    omarchy-plugin-remove "$id" --yes >/dev/null 2>&1 && echo "  removed the $id plugin (the desktop added it)"
  elif [[ -d $dir ]]; then
    echo "  (the $id plugin stays, you added it: $dir/bin/teardown, then omarchy plugin remove $id)"
  fi
done
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
