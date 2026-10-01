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

// Terminal windows: the terminals Omarchy installs (omarchy-install-terminal:
// Alacritty, foot, Ghostty, kitty), its own terminal apps (org.omarchy.*,
// TUI.*), and other common ones. Terminals retitle freely (a shell prompt can
// end in "(2)"), so they never report unread counts.
var terminalClass = /^(com\.mitchellh\.ghostty|org\.omarchy\.|TUI\.|Alacritty|kitty|foot|org\.wezfurlong\.wezterm|org\.kde\.konsole|org\.gnome\.(Console|Terminal|Ptyxis)|dev\.warp\.Warp|XTerm|URxvt|st-256color|Rio|com\.raggesilver\.BlackBox)/

function isTerminalClass(windowClass) {
  return terminalClass.test(String(windowClass || ""))
}

function unreadCount(title, windowClass) {
  if (terminalClass.test(String(windowClass || ""))) return 0
  var text = String(title || "")
  var match = text.match(/^\((\d+)\)\s/) || text.match(/\s\((\d+)\)$/)
  return match ? parseInt(match[1], 10) : 0
}

// Title without the agent spinner, for labels and cards.
function cleanTitle(title) {
  return String(title || "").replace(/^[◐◓◑◒✳⠀-⣿]\s*/, "")
}
