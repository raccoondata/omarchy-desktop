.pragma library

// What a window's title says about it (taskbar.qml, WindowCard.qml).
//
// Agents put a spinner at the front of their terminal title while they work:
// Claude Code cycles ◐◓◑◒ and shows ✳ when it's waiting for you, Codex uses a
// braille spinner and shows just the project name when idle.
// Chat apps put an unread count in brackets: "Telegram (21)", "(33) Chat | …".

var agentPrograms = { claude: true, codex: true }
var claudeSpinner = "◐◓◑◒"

// "working", "idle", or "" for anything that isn't an agent.
function agentState(title, program) {
  if (!agentPrograms[program]) return ""
  var first = String(title || "").charAt(0)
  if (claudeSpinner.indexOf(first) !== -1) return "working"
  var code = first.charCodeAt(0)
  if (code >= 0x2800 && code <= 0x28ff) return "working"
  return "idle"
}

// Coding agents, by the program a terminal runs them as: the ones Omarchy
// sets up (omarchy-default-agent) and a few other common ones.
var agentIds = ["pi", "omp", "opencode", "claude", "codex", "crush", "grok", "gemini", "openclaw", "hermes",
                "copilot", "cursor-agent", "muse", "aider", "amp", "goose", "qwen", "droid", "kimi", "auggie"]

function isAgentProgram(program) {
  return agentIds.indexOf(String(program || "")) !== -1
}

// An agent's own window: Omarchy's agent windows (org.omarchy.agent) and
// the desktop's per-agent ones (org.omarchy.claude, Super+C C).
function isAgentClass(windowClass) {
  var m = /^org\.omarchy\.(.+)$/.exec(String(windowClass || ""))
  return !!m && (m[1] === "agent" || isAgentProgram(m[1].replace(/_/g, "-")))
}

// Terminal windows, by kind (Taskbar & Desktop > Windows chooses which
// ones gather with agents): the terminals Omarchy installs
// (omarchy-install-terminal: Alacritty, foot, Ghostty, kitty), other common
// ones, and Omarchy's own tool windows (org.omarchy.<program>, TUI.*: btop,
// package installs, About; mostly floating popups, so off by default).
// "bins" are the commands that show a terminal is installed.
var terminalKinds = [
  { id: "ghostty", label: "Ghostty", match: /^com\.mitchellh\.ghostty/, bins: ["ghostty"] },
  { id: "alacritty", label: "Alacritty", match: /^Alacritty/, bins: ["alacritty"] },
  { id: "kitty", label: "kitty", match: /^kitty/, bins: ["kitty"] },
  { id: "foot", label: "foot", match: /^(foot|footclient|org\.codeberg\.dnkl\.foot)/, bins: ["foot"] },
  { id: "wezterm", label: "WezTerm", match: /^org\.wezfurlong\.wezterm/, bins: ["wezterm"] },
  { id: "konsole", label: "Konsole", match: /^org\.kde\.konsole/, bins: ["konsole"] },
  { id: "gnome-console", label: "GNOME Console", match: /^org\.gnome\.Console/, bins: ["kgx"] },
  { id: "gnome-terminal", label: "GNOME Terminal", match: /^org\.gnome\.Terminal/, bins: ["gnome-terminal"] },
  { id: "ptyxis", label: "Ptyxis", match: /^org\.gnome\.Ptyxis/, bins: ["ptyxis"] },
  { id: "warp", label: "Warp", match: /^dev\.warp\.Warp/, bins: ["warp-terminal"] },
  { id: "xterm", label: "XTerm", match: /^(XTerm|UXTerm|xterm)/, bins: ["xterm"] },
  { id: "urxvt", label: "URxvt", match: /^URxvt/, bins: ["urxvt"] },
  { id: "st", label: "st", match: /^st-256color/, bins: ["st"] },
  { id: "rio", label: "Rio", match: /^[Rr]io$/, bins: ["rio"] },
  { id: "blackbox", label: "Black Box", match: /^com\.raggesilver\.BlackBox/, bins: ["blackbox", "blackbox-terminal"] },
  { id: "omarchy", label: "Omarchy's tool windows", match: /^(org\.omarchy\.|TUI\.)/, bins: [] }
]
// Any other window with a program in a terminal's foreground: "other".
var otherTerminals = { id: "other", label: "Other terminals" }
var terminalsOffByDefault = ["omarchy"]

// Windows that are never gathered: Omarchy's screensaver.
function neverGathered(windowClass) {
  return /^org\.omarchy\.screensaver/.test(String(windowClass || ""))
}

// A window class's terminal kind id, or "" (agents' own windows aren't one).
function terminalKindOf(windowClass) {
  var c = String(windowClass || "")
  if (isAgentClass(c) || neverGathered(c)) return ""
  for (var i = 0; i < terminalKinds.length; i++) if (terminalKinds[i].match.test(c)) return terminalKinds[i].id
  return ""
}

// Terminals retitle freely (a shell prompt can end in "(2)"), so they never
// report unread counts.
function isTerminalClass(windowClass) {
  var c = String(windowClass || "")
  for (var i = 0; i < terminalKinds.length; i++) if (terminalKinds[i].match.test(c)) return true
  return false
}

function unreadCount(title, windowClass) {
  if (isTerminalClass(windowClass)) return 0
  var text = String(title || "")
  var match = text.match(/^\((\d+)\)\s/) || text.match(/\s\((\d+)\)$/)
  return match ? parseInt(match[1], 10) : 0
}

// Title without the agent spinner, for labels and cards.
function cleanTitle(title) {
  return String(title || "").replace(/^[◐◓◑◒✳⠀-⣿]\s*/, "")
}
