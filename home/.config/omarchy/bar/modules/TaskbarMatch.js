.pragma library

// Which icon a window, program or launcher entry gets: the taskbar's
// matching rules, shared by the taskbar, window previews and switcher, the
// Super menu and now playing. Icons themselves: taskbar-icons.js.
//
// Order of checks: your own rules (~/.config/omarchy/taskbar-icons.json
// "programs" and "classes", loaded by taskbar.qml through setUser()), then
// programIcons for a terminal's foreground program, then classIcons by
// window class, first match wins.

// Terminal programs -> icon. A terminal at a plain prompt shows "terminal".
var programIcons = {
  claude: "claude", codex: "codex",
  // The other coding agents Omarchy knows (~/.config/omarchy/agents).
  grok: "grok", gemini: "gemini", opencode: "opencode", copilot: "copilot",
  "cursor-agent": "cursor", crush: "crush", pi: "pi", omp: "omp",
  hermes: "hermes", muse: "muse", openclaw: "openclaw",
  nvim: "neovim", vim: "neovim",
  btop: "btop", htop: "htop", top: "monitor",
  docker: "docker", lazydocker: "lazydocker", "omarchy-launch-docker-tui": "lazydocker",
  lazygit: "lazygit", git: "git",
  // Omarchy's own terminal tools (audio, Wi-Fi, Bluetooth, About, disk use).
  wiremix: "wiremix", impala: "impala", bluetui: "bluetui",
  fastfetch: "fastfetch", dua: "dua", uuctl: "uuctl",
  "limine-snapper-restore": "restore",
  python: "python", python3: "python", ipython: "python",
  node: "node", bun: "node", deno: "node",
  ssh: "server", mosh: "server",
  man: "document", less: "document", bat: "document",
  tmux: "tmux", zellij: "tmux",
  yazi: "folder", ranger: "folder", lf: "folder",
  cliamp: "cliamp", spotify_player: "music", ncspot: "music"
}

// Window class -> icon, first match wins: specific rules above general ones.
var classIcons = [
  // Super+C C / Super+V V agent windows (own classes, own Ghostty process).
  [/^org\.omarchy\.claude$/, "claude"],
  [/^org\.omarchy\.codex$/, "codex"],
  // Other agents started from the ask card / Files (./agents launch).
  [/^org\.omarchy\.grok$/, "grok"],
  [/^org\.omarchy\.gemini$/, "gemini"],
  [/^org\.omarchy\.opencode$/, "opencode"],
  [/^org\.omarchy\.copilot$/, "copilot"],
  [/^org\.omarchy\.cursor_agent$/, "cursor"],
  [/^org\.omarchy\.crush$/, "crush"],
  [/^org\.omarchy\.pi$/, "pi"],
  [/^org\.omarchy\.omp$/, "omp"],
  [/^org\.omarchy\.hermes$/, "hermes"],
  [/^org\.omarchy\.muse$/, "muse"],
  [/^org\.omarchy\.openclaw$/, "openclaw"],
  // Omarchy's TUI and agent windows run in Ghostty too.
  [/^(com\.mitchellh\.ghostty|org\.omarchy\.|TUI\.)/, "ghostty"],
  [/^(Alacritty|kitty|foot)/, "terminal"],
  // Omarchy web apps are chrome-<site>__<path>-<profile> windows (msedge-/
  // brave- when the default browser is Edge/Brave); known sites
  // get their own mark, any other site keeps the globe.
  [/^(chrome|msedge|brave)-(www\.)?youtube\.com/i, "youtube"],
  [/^(chrome|msedge|brave)-music\.youtube\.com/i, "youtubemusic"],
  [/^(chrome|msedge|brave)-(x|twitter)\.com/i, "x"],
  [/^(chrome|msedge|brave)-web\.whatsapp\.com/i, "whatsapp"],
  [/^(chrome|msedge|brave)-discord\.com/i, "discord"],
  [/^(chrome|msedge|brave)-web\.telegram\.org/i, "telegram"],
  [/^(chrome|msedge|brave)-teams\.(microsoft|live)\.com/i, "teams"],
  [/^(chrome|msedge|brave)-(launchpad\.37signals|3\.basecamp)\.com/i, "basecamp"],
  [/^(chrome|msedge|brave)-chatgpt\.com/i, "chatgpt"],
  [/^(chrome|msedge|brave)-github\.com/i, "github"],
  [/^(chrome|msedge|brave)-app\.zoom\.us/i, "zoom"],
  [/^(chrome|msedge|brave)-grok\.com/i, "grok"],
  [/^(chrome|msedge|brave)-app\.hey\.com__calendar/i, "calendar"],
  [/^(chrome|msedge|brave)-app\.hey\.com/i, "mail"],
  [/^(chrome|msedge|brave)-messages\.google\.com/i, "messages"],
  [/^(chrome|msedge|brave)-photos\.google\.com/i, "photos"],
  [/^(chrome|msedge|brave)-maps\.google\.com/i, "maps"],
  [/^(chrome|msedge|brave)-contacts\.google\.com/i, "contacts"],
  // The browser itself gets its mark.
  [/^(chromium|chromium-browser|google-chrome|google-chrome-stable)$/i, "chrome"],
  [/^microsoft-edge/i, "edge"],
  [/^(chrome-|msedge-|firefox|zen|brave)/i, "browser"],
  [/^(com\.microsoft\.vscode|code|code-oss|code-url-handler|visual-studio-code)$/i, "vscode"],
  [/^(cursor|dev\.zed)/i, "code"],
  [/^(org\.gnome\.nautilus|nautilus|thunar)/i, "folder"],
  [/^dev\.tensaku\.Tensaku$/i, "tensaku"],
  [/^(rustdesk|com\.carriez\.flutter_hbb)$/i, "rustdesk"],
  [/^discord/i, "discord"],
  [/^(org\.telegram\.desktop|telegramdesktop)$/i, "telegram"],
  [/^(signal|slack)/i, "chat"],
  [/^zoom/i, "zoom"],
  [/^mpv$/i, "mpv"],
  [/^imv/i, "imv"],
  [/xournalpp/i, "xournal"],
  [/pinta/i, "pinta"],
  [/kdenlive/i, "kdenlive"],
  [/^(obs|com\.obsproject\.studio)$/i, "obs"],
  [/moonlight/i, "moonlight"],
  // Omarchy's own apps and system tools.
  [/^omacalc$/i, "omacalc"],
  [/^omacut$/i, "omacut"],
  [/aether/i, "aether"],
  [/^(org\.gnome\.diskutility|gnome-disks)$/i, "disks"],
  [/system-config-printer/i, "printer"],
  [/fcitx/i, "keyboard"],
  [/limine-snapper/i, "restore"],
  [/^(avahi-discover|bssh|bvnc)/i, "network"],
  [/uuctl/i, "uuctl"],
  [/^omawrite$/i, "omawrite"],
  [/libreoffice-writer/i, "writer"],
  [/libreoffice-calc/i, "calc"],
  [/libreoffice-impress/i, "impress"],
  [/libreoffice-draw/i, "draw"],
  [/libreoffice-math/i, "math"],
  [/libreoffice-base/i, "base"],
  [/(libreoffice|soffice)/i, "libreoffice"],
  [/obsidian/i, "obsidian"],
  [/^(org\.gnome\.(evince|papers)|evince|papers)$/i, "pdf"],
  [/typora/i, "document"],
  [/localsend/i, "localsend"],
  [/^spotify/i, "music"],
  // The Steam client, and games it launches (steam_app_<id> windows).
  [/^(steam|steam_app_\d+)$/i, "steam"]
]

var userPrograms = {}
var userClasses = []

function setUser(programs, classes) {
  userPrograms = programs || {}
  userClasses = classes || []
}

// A window: its foreground program (terminals) and class.
function forWindow(program, windowClass) {
  if (program && userPrograms[program]) return userPrograms[program]
  for (var u = 0; u < userClasses.length; u++) {
    if (userClasses[u][0].test(windowClass)) return userClasses[u][1]
  }
  if (program && programIcons[program]) return programIcons[program]
  for (var i = 0; i < classIcons.length; i++) {
    if (classIcons[i][0].test(windowClass)) return classIcons[i][1]
  }
  return "app"
}

// A launcher entry (Quickshell DesktopEntry): its program, a web app's
// site, its window class or id. "" when it would only get a generic icon.
function forEntry(entry) {
  if (!entry) return ""
  var exec = String(entry.execString || "")
  var cmd = entry.command || []
  var prog = cmd.length ? String(cmd[0]).replace(/^.*\//, "") : ""
  if (userPrograms[prog]) return userPrograms[prog]
  if (programIcons[prog]) return programIcons[prog]
  // A terminal launcher (xdg-terminal-exec ... -e dua i /, bash -c "..."):
  // the program it runs.
  var words = exec.replace(/["']/g, " ").split(/\s+/)
  for (var w = 1; w < words.length; w++) {
    var word = words[w].replace(/^.*\//, "")
    if (userPrograms[word]) return userPrograms[word]
    if (programIcons[word]) return programIcons[word]
  }
  var handlers = { hey: "mail", zoom: "zoom" }
  var handler = /omarchy-webapp-handler-(\w+)/.exec(exec)
  if (handler && handlers[handler[1]]) return handlers[handler[1]]
  var candidates = []
  var site = /omarchy-launch-webapp\s+["']?https?:\/\/(?:www\.)?([^\/\s"']+)/.exec(exec)
  if (site) candidates.push("chrome-" + site[1] + "__-Default")
  if (entry.startupClass) candidates.push(String(entry.startupClass))
  if (entry.id) candidates.push(String(entry.id))
  if (/localhost:631\b/.test(exec)) return "printer"  // CUPS in the browser
  for (var c = 0; c < candidates.length; c++) {
    var name = forWindow("", candidates[c])
    if (name !== "app") return name === "browser" ? "" : name
  }
  return ""
}

// An app known only by the names an audio stream or media player gives
// (now playing's mixer): its icon name, app name and process, e.g.
// "microsoft-edge", "Microsoft Edge", "msedge". "" when only generic.
var processAliases = { msedge: "edge", "microsoft-edge-stable": "edge", chrome: "chrome", "google-chrome": "chrome",
  chromium: "chrome", "telegram-desktop": "telegram", spotify: "music", firefox: "browser" }
function forApp(iconName, appName, binary, entry) {
  // The stream's own identity first (its process, name and icon name): a
  // launcher found by guessing can be the wrong one, e.g. a web app for the
  // browser that hosts it ("msedge" -> YouTube Music).
  var bin = String(binary || "").replace(/^.*\//, "")
  if (userPrograms[bin]) return userPrograms[bin]
  if (processAliases[bin] && processAliases[bin] !== "browser") return processAliases[bin]
  if (programIcons[bin]) return programIcons[bin]
  var slug = String(appName || "").toLowerCase().trim().replace(/\s+/g, "-")
  var candidates = [String(iconName || ""), slug, bin]
  for (var c = 0; c < candidates.length; c++) {
    if (!candidates[c]) continue
    var name = forWindow("", candidates[c])
    if (name !== "app" && name !== "browser") return name
  }
  return forEntry(entry)
}
