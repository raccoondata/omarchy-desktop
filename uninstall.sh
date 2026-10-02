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
# Whether the bundle added a plugin (desktop.conf plugin_<id>=added): only
# then does uninstall take it, and its system parts, out.
added() { [[ "$(sed -n "s/^plugin_${1//-/_}=//p" "$omarchy/desktop.conf" 2>/dev/null | tail -1)" == added ]]; }
bold=$'\e[1m' off=$'\e[0m'

echo "${bold}Uninstall omarchy-desktop${off}"
echo "Puts Omarchy's own bar, keys and menus back. Your settings files stay."
read -r -p "Go ahead? [y/N] " a || true
[[ $a == [yY]* ]] || exit 0
sudo -v

# Remote access first, when the bundle added it: its system parts (even a
# partial setup) and its own; not while a RustDesk connection is open (both
# refuse then), which stops the uninstall before anything is changed.
ra="$omarchy/plugins/remote-access"
if added remote-access && [[ -x $ra/bin/setup-system ]]; then
  "$ra/bin/setup-system" --off || { echo "Remote access couldn't be turned off (above); nothing was changed."; exit 1; }
  "$ra/bin/teardown" >/dev/null || { echo "Remote access couldn't be undone (above); nothing else was changed."; exit 1; }
fi

echo "- hooks into Omarchy"
hl="$HOME/.config/hypr/hyprland.lua"
sed -i '/^-- The taskbar\/Super-menu desktop (omarchy-desktop)/d; /^require("hypr.desktop")$/d' "$hl"
shell="$omarchy/shell.json"
if [[ -f $shell ]]; then
  tmp="$(mktemp)"
  # The bundle's widgets go; Omarchy's media widget comes back where it was.
  was="$(sed -n 's/^media_was=//p' "$omarchy/desktop.conf" 2>/dev/null | tail -1)"
  # An install from before that was noted: where Omarchy's default has it.
  [[ -z $was ]] && was=$(jq -r '.bar.layout | to_entries[] | .key as $side | .value | (map(.id) | index("omarchy.media")) as $i
    | select($i != null) | "\($side):\(if $i > 0 then .[$i-1].id else "" end)"' /usr/share/omarchy/config/omarchy/shell.json 2>/dev/null | head -1)
  jq --arg side "${was%%:*}" --arg prev "${was#*:}" '
    .bar.layout |= with_entries(.value |= map(select(.id != "taskbar" and .id != "nowplaying" and .id != "now-playing")))
    | if $side == "" or any(.bar.layout[][]?; .id == "omarchy.media") then .
      else .bar.layout[$side] = (.bar.layout[$side] // [] | (map(.id) | index($prev)) as $i
        | if $prev == "" then [{"id": "omarchy.media"}] + . elif $i == null then . + [{"id": "omarchy.media"}]
          else .[:$i+1] + [{"id": "omarchy.media"}] + .[$i+1:] end) end' "$shell" > "$tmp" && mv "$tmp" "$shell"
  # Noted once per install: the next install notes where it is then.
  sed -i '/^media_was=/d' "$omarchy/desktop.conf" 2>/dev/null || true
fi
menu="$omarchy/extensions/omarchy-menu.jsonc"
# Only the bundle's own entry (the plugins' are in their blocks; their
# teardown takes them), and an old version's entries by their exact actions.
[[ -f $menu ]] && sed -i -E '/^\s*"update\.desktop":/d; /"action": ?"\$HOME\/\.config\/omarchy\/(lock|reboot-to-windows)"/d' "$menu"
# The rescue console block in ~/.bashrc (from its comment to its fi), when
# the bundle added Rescue.
added rescue && [[ -f $HOME/.bashrc ]] && python3 - "$HOME/.bashrc" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n*# Text console 3 \(Ctrl\+Alt\+Esc.*?\nfi\n", "\n", s, flags=re.S)
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
added windows && rm -f "$HOME/.local/lib/hyprland/libhyprdragevents.so" "$HOME/.local/lib/hyprland/libhyprbars-fixed.so"
rm -f "$state/plugins-built"
[[ "$(readlink "$HOME/.local/bin/omarchy-desktop" 2>/dev/null)" == "$repo/bin/omarchy-desktop" ]] && rm -f "$HOME/.local/bin/omarchy-desktop"
# The desktop's plugins: removed if the desktop added them; ones you added
# yourself stay.
for id in remote-access taskbar windows rescue screenshots agent-tools hot-corners super-menu now-playing line-icons desktop-core; do
  dir="$HOME/.config/omarchy/plugins/$id"
  key="plugin_${id//-/_}"
  mark="$(sed -n "s/^$key=//p" "$HOME/.config/omarchy/desktop.conf" 2>/dev/null | tail -1)"
  [[ $id == line-icons && -z $mark ]] && mark="$(sed -n 's/^line_icons=//p' "$HOME/.config/omarchy/desktop.conf" 2>/dev/null | tail -1)"
  if [[ $mark == added && -d $dir && ! -L $dir ]]; then
    "$dir/bin/teardown" >/dev/null 2>&1 || true
    omarchy-plugin-disable "$id" >/dev/null 2>&1 || true
    omarchy-plugin-remove "$id" --yes >/dev/null 2>&1 || true
    if [[ -d $dir ]]; then
      # No shell to ask (not in a session): out of shell.json, the folder aside.
      tmp="$(mktemp)"
      jq --arg id "$id" '.plugins = ((.plugins // []) | map(select(.id != $id)))' "$omarchy/shell.json" > "$tmp" 2>/dev/null \
        && mv "$tmp" "$omarchy/shell.json" || rm -f "$tmp"
      mkdir -p "$backup/plugins" && mv "$dir" "$backup/plugins/$id"
    fi
    if [[ -d $dir ]]; then
      echo "  ! couldn't remove the $id plugin ($dir)"
    else
      echo "  removed the $id plugin (the desktop added it)"
      # No longer the bundle's: one you install yourself later stays yours.
      sed -i "/^plugin_${id//-/_}=/d" "$omarchy/desktop.conf" 2>/dev/null || true
    fi
  elif [[ -d $dir ]]; then
    echo "  (the $id plugin stays, you added it: $dir/bin/teardown, then omarchy plugin remove $id)"
  fi
done
systemctl --user daemon-reload 2>/dev/null || true

echo "- system files"
# Rescue's (only when the bundle added Rescue).
added rescue && sudo rm -f /etc/omarchy-rescue.issue "/etc/systemd/system/getty@tty3.service.d/rescue-issue.conf" \
  /etc/sudoers.d/50-chvt /etc/sudoers.d/50-reboot-to-windows /usr/local/lib/omarchy-rescue/bootnext
sudo systemctl daemon-reload

hyprctl reload >/dev/null 2>&1 || true
omarchy-restart-shell >/dev/null 2>&1 || true
nautilus -q >/dev/null 2>&1 || true

echo
echo "${bold}Done.${off} Log out and back in to finish (the plugins stay loaded until then)."
echo "Its files are in ${backup/#$HOME/\~}; its source folder ($repo) you can delete."
echo "Packages it installed, if you want them gone too:"
echo "  yay -R hyprland-plugin-hyprbars    (the others, like hyprlock and jq, are harmless)"
