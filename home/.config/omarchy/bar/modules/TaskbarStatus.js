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

// Terminals retitle freely (a shell prompt can end in "(2)"), so they never
// report unread counts.
var terminalClass = /^(com\.mitchellh\.ghostty|org\.omarchy\.|TUI\.|Alacritty|kitty|foot)/

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
