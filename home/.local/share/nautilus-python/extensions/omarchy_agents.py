# Files (Nautilus) right-click menu for coding agents (~/.config/omarchy/agents:
# the installed ones, two primaries, the rest under "More Agents"), all under
# one Agents ▸ submenu, or at the top of the menu (Taskbar & Desktop > Agents >
# Files right-click: filesAgentMenu "grouped" (default) | "flat"):
#
#   files:              Ask <primary>… (x2)   Send to Session ▸   More Agents ▸
#   a folder:           Open <primary> Here (x2)   Send to Session ▸   More Agents ▸
#   the folder's empty space:  Open <primary> Here (x2)   More Agents ▸
#
# "Ask …" opens the taskbar's ask card with the files attached (type a
# question, pick a new or an open session). "Send to Session" drops the paths
# into an open session's input (no question, nothing sent). "Open … Here"
# starts a session in that folder. Needs nautilus-python; Files loads it at
# start (nautilus -q to restart Files).

import json
import os
import subprocess

from gi.repository import GObject, Nautilus

HOME = os.path.expanduser("~")
OMARCHY = os.path.join(HOME, ".config", "omarchy")
AGENTS = os.path.join(OMARCHY, "agents")
ASK = os.path.join(OMARCHY, "ask-agent")
SETTINGS = os.path.join(OMARCHY, "taskbar-settings.json")


def grouped():
    """Agent items under one Agents submenu (the default), or flat."""
    try:
        with open(SETTINGS) as f:
            return json.load(f).get("filesAgentMenu", "grouped") != "flat"
    except Exception:
        return True


def run_json(args, fallback):
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=3).stdout
        return json.loads(out) if out.strip() else fallback
    except Exception:
        return fallback


def spawn(args):
    try:
        subprocess.Popen(args, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def path_of(info):
    location = info.get_location()
    path = location.get_path() if location else None
    if path and info.is_directory():
        path = path.rstrip("/") + "/"
    return path


class OmarchyAgentsMenu(GObject.GObject, Nautilus.MenuProvider):
    def _item(self, key, label, tip, callback, *args):
        item = Nautilus.MenuItem(name="OmarchyAgents::" + key, label=label, tip=tip)
        item.connect("activate", lambda _item: callback(*args))
        return item

    def _submenu(self, key, label, items):
        parent = Nautilus.MenuItem(name="OmarchyAgents::" + key, label=label)
        menu = Nautilus.Menu()
        for item in items:
            menu.append_item(item)
        parent.set_submenu(menu)
        return parent

    # --- actions -----------------------------------------------------------
    def ask(self, agent, paths):
        spawn(["omarchy-shell", "-q", "taskbar", "askFiles", agent, "\n".join(paths)])

    def attach(self, address, paths):
        spawn([ASK, "files", address, ""] + paths)

    def open_here(self, agent, folder):
        spawn([AGENTS, "launch", agent, "--cwd", folder.rstrip("/") or "/"])

    # --- menus -------------------------------------------------------------
    def _agents(self):
        agents = run_json([AGENTS, "list"], [])
        return [a for a in agents if a.get("primary")], [a for a in agents if not a.get("primary")]

    def _session_items(self, paths):
        sessions = run_json([AGENTS, "sessions"], [])
        items = []
        for i, s in enumerate(sessions):
            label = "%s: %s" % (s.get("name", "Agent"), s.get("title", "") or "session")
            items.append(self._item("send-%d" % i, label[:60],
                                    "Add the path%s to what you're typing there" % ("s" if len(paths) > 1 else ""),
                                    self.attach, s["address"], paths))
        return items

    def get_file_items(self, *args):
        files = args[-1]
        paths = [p for p in (path_of(f) for f in files) if p]
        if not paths:
            return []
        primaries, others = self._agents()
        if not primaries:
            return []
        folder = paths[0] if len(paths) == 1 and paths[0].endswith("/") else None
        top, more = [], []

        if folder:
            for a in primaries:
                top.append(self._item("open-" + a["id"], "Open %s Here" % a["name"],
                                      "Start a %s session in this folder" % a["name"], self.open_here, a["id"], folder))
            for a in primaries + others:
                more.append(self._item("ask-" + a["id"], "Ask %s About It…" % a["name"],
                                       "Ask %s about this folder" % a["name"], self.ask, a["id"], paths))
            for a in others:
                more.append(self._item("open-" + a["id"], "Open %s Here" % a["name"],
                                       "Start a %s session in this folder" % a["name"], self.open_here, a["id"], folder))
        else:
            for a in primaries:
                top.append(self._item("ask-" + a["id"], "Ask %s…" % a["name"],
                                      "Ask %s about %s" % (a["name"], "these" if len(paths) > 1 else "this"),
                                      self.ask, a["id"], paths))
            for a in others:
                more.append(self._item("ask-" + a["id"], "Ask %s…" % a["name"],
                                       "Ask %s about %s" % (a["name"], "these" if len(paths) > 1 else "this"),
                                       self.ask, a["id"], paths))

        sessions = self._session_items(paths)
        if sessions:
            top.append(self._submenu("sessions", "Send to Session", sessions))
        if more:
            top.append(self._submenu("more", "More Agents", more))
        return [self._submenu("agents", "Agents", top)] if grouped() else top

    def get_background_items(self, *args):
        folder_info = args[-1]
        folder = path_of(folder_info)
        if not folder:
            return []
        primaries, others = self._agents()
        items = [self._item("bg-open-" + a["id"], "Open %s Here" % a["name"],
                            "Start a %s session in this folder" % a["name"], self.open_here, a["id"], folder)
                 for a in primaries]
        if others:
            items.append(self._submenu("bg-more", "More Agents",
                                       [self._item("bg-open-" + a["id"], "Open %s Here" % a["name"],
                                                   "Start a %s session in this folder" % a["name"],
                                                   self.open_here, a["id"], folder) for a in others]))
        return [self._submenu("bg-agents", "Agents", items)] if grouped() and items else items
