.pragma library

// Taskbar icon set: Omarchy-style line icons on a 24px grid. "%C" is the
// draw colour, filled in at runtime so one drawing serves dark and light
// themes and every state (active, inactive, minimized).
var icons = {
  "terminal": "<rect x=\"3\" y=\"4.5\" width=\"18\" height=\"15\" rx=\"3\"/><path d=\"M7.5 9.5l2.5 2.5-2.5 2.5M12.5 15h4\"/>",
  "claude": "<path d=\"M12.00 12.00L12.00 3.00M12.00 12.00L16.22 6.54M12.00 12.00L19.27 8.21M12.00 12.00L19.23 13.56M12.00 12.00L18.85 17.53M12.00 12.00L13.19 18.49M12.00 12.00L10.18 20.30M12.00 12.00L6.40 16.36M12.00 12.00L3.21 13.42M12.00 12.00L6.08 8.65M12.00 12.00L7.39 5.59\"/>",
  "codex": "<path d=\"M14.79 5.26A3.05 3.05 0 0 1 18.74 9.21A3.05 3.05 0 0 1 18.74 14.79A3.05 3.05 0 0 1 14.79 18.74A3.05 3.05 0 0 1 9.21 18.74A3.05 3.05 0 0 1 5.26 14.79A3.05 3.05 0 0 1 5.26 9.21A3.05 3.05 0 0 1 9.21 5.26A3.05 3.05 0 0 1 14.79 5.26Z\"/><path d=\"M9.3 10l2 2-2 2M12.9 14.3h2.2\"/>",
  "neovim": "<path d=\"M7 18V6l10 12V6\"/>",
  "monitor": "<rect x=\"3\" y=\"4.5\" width=\"18\" height=\"15\" rx=\"3\"/><path d=\"M6.5 13h2.3l1.7-4.2 3 7.4 1.7-4.2h2.3\"/>",
  "docker": "<rect x=\"5.4\" y=\"9\" width=\"3.4\" height=\"3.2\" rx=\".6\"/><rect x=\"9.8\" y=\"9\" width=\"3.4\" height=\"3.2\" rx=\".6\"/><rect x=\"14.2\" y=\"9\" width=\"3.4\" height=\"3.2\" rx=\".6\"/><rect x=\"9.8\" y=\"4.8\" width=\"3.4\" height=\"3.2\" rx=\".6\"/><path d=\"M3 14.5h18c-1 3.5-4.2 5.5-9 5.5s-8-2-9-5.5z\"/>",
  "git": "<circle cx=\"6.5\" cy=\"6\" r=\"2.2\"/><circle cx=\"6.5\" cy=\"18\" r=\"2.2\"/><circle cx=\"17.5\" cy=\"7.5\" r=\"2.2\"/><path d=\"M6.5 8.2v7.6M17.5 9.7c0 4.3-5 4-9.3 6.9\"/>",
  "python": "<path d=\"M12 8.5H8V6.5C8 4.5 9.5 3 12 3s4 1.5 4 3.5v4c0 1.1-.9 2-2 2h-4c-1.1 0-2 .9-2 2v3c0 2 1.5 3.5 4 3.5s4-1.5 4-3.5v-2h-4\"/><path d=\"M8 8.5H6.5C4.6 8.5 3.5 10 3.5 12s1.1 3.5 3 3.5H8M16 8.5h1.5c1.9 0 3 1.5 3 3.5s-1.1 3.5-3 3.5H16\"/><circle cx=\"10.4\" cy=\"5.7\" r=\"0.8\" fill=\"%C\" stroke=\"none\"/><circle cx=\"13.6\" cy=\"18.3\" r=\"0.8\" fill=\"%C\" stroke=\"none\"/>",
  "node": "<path d=\"M12 3l7.8 4.5v9L12 21l-7.8-4.5v-9z\"/><path d=\"M9.6 15.5v-3.6a2.4 2.4 0 0 1 4.8 0v3.6\"/>",
  "server": "<rect x=\"4\" y=\"4.5\" width=\"16\" height=\"6.5\" rx=\"2\"/><rect x=\"4\" y=\"13\" width=\"16\" height=\"6.5\" rx=\"2\"/><path d=\"M11 7.75h5.5M11 16.25h5.5\"/><circle cx=\"7.5\" cy=\"7.75\" r=\"0.95\" fill=\"%C\" stroke=\"none\"/><circle cx=\"7.5\" cy=\"16.25\" r=\"0.95\" fill=\"%C\" stroke=\"none\"/>",
  "document": "<path d=\"M6.5 3.5h7l4 4v13h-11z\"/><path d=\"M13.5 3.5v4h4M9 12h6M9 15.5h6\"/>",
  "tmux": "<rect x=\"3\" y=\"4.5\" width=\"18\" height=\"15\" rx=\"3\"/><path d=\"M12 4.5v15M12 12h9\"/>",
  "folder": "<path d=\"M3.5 7.5a2 2 0 0 1 2-2h3.8l2 2.2h7.2a2 2 0 0 1 2 2v7.8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z\"/>",
  "music": "<path d=\"M9 17.5V6.5l10-2v11\"/><circle cx=\"6.8\" cy=\"17.5\" r=\"2.2\"/><circle cx=\"16.8\" cy=\"15.5\" r=\"2.2\"/>",
  "browser": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><ellipse cx=\"12\" cy=\"12\" rx=\"3.8\" ry=\"8.5\"/><path d=\"M3.5 12h17\"/>",
  "chrome": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><circle cx=\"12\" cy=\"12\" r=\"3.2\"/><path d=\"M12.00 8.80L19.87 8.80M14.77 13.60L10.83 20.42M9.23 13.60L5.29 6.78\"/>",
  "code": "<path d=\"M8.5 7.5L4 12l4.5 4.5M15.5 7.5L20 12l-4.5 4.5M13.2 5.5l-2.4 13\"/>",
  "vscode": "<path d=\"M16 3v18l4-2.5v-13z\"/><path d=\"M9.17 13.9L5 17.5l-2-1 4.33-4.5m1.74-1.8L16 3v5l-4.8 4.14\"/><path d=\"M16 16.5l-11-10-2 1L16 21\"/>",
  "chat": "<path d=\"M4.5 6.5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-7l-4 3.5v-3.5a2 2 0 0 1-2-2z\"/>",
  "video": "<rect x=\"3\" y=\"7\" width=\"12.5\" height=\"10\" rx=\"2.2\"/><path d=\"M15.5 10.5l5-2.8v8.6l-5-2.8\"/>",
  "play": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M10.2 8.8l5 3.2-5 3.2z\"/>",
  "image": "<rect x=\"3.5\" y=\"4.5\" width=\"17\" height=\"15\" rx=\"2.5\"/><circle cx=\"9\" cy=\"9.5\" r=\"1.6\"/><path d=\"M20.5 15.5L16 11l-8 8.5\"/>",
  "pen": "<path d=\"M15.5 4.5l4 4L9 19H5v-4z\"/><path d=\"M13.5 6.5l4 4\"/>",
  "send": "<path d=\"M20.5 3.5l-17 7 7 2.8 2.8 7z\"/><path d=\"M20.5 3.5l-10 9.8\"/>",
  "app": "<rect x=\"3.5\" y=\"4.5\" width=\"17\" height=\"15\" rx=\"2.5\"/><path d=\"M3.5 8.5h17\"/><circle cx=\"6\" cy=\"6.5\" r=\"0.6\" fill=\"%C\" stroke=\"none\"/><circle cx=\"8\" cy=\"6.5\" r=\"0.6\" fill=\"%C\" stroke=\"none\"/>",
  "youtube": "<rect x=\"2.8\" y=\"5.5\" width=\"18.4\" height=\"13\" rx=\"4\"/><path d=\"M10.2 9.4l4.6 2.6-4.6 2.6z\"/>",
  "x": "<path d=\"M4.3 4h4.4l11 16h-4.4z\"/><path d=\"M19.5 4l-6.4 7.1M10.9 12.9L4.5 20\"/>",
  "whatsapp": "<path d=\"M4.3 19.7l1.25-3.9a8.1 8.1 0 1 1 2.9 2.7z\"/><path d=\"M9.4 8.9c.35 2.8 2.9 5.35 5.7 5.7l1-1.45-1.95-1-1 .75a4.6 4.6 0 0 1-2-2l.75-1-1-1.95z\"/>",
  "discord": "<path d=\"M8.7 7.2c-1.6.3-3 .9-4.3 1.7-1.4 3-1.8 6-1.4 9 1.4 1.1 3 1.8 4.6 2.2l1.1-1.8M15.3 7.2c1.6.3 3 .9 4.3 1.7 1.4 3 1.8 6 1.4 9-1.4 1.1-3 1.8-4.6 2.2l-1.1-1.8M7.6 16.9c2.9 1.3 5.9 1.3 8.8 0M8.6 8.7c2.3-.6 4.5-.6 6.8 0\"/><circle cx=\"9.4\" cy=\"13.2\" r=\"1.15\" fill=\"%C\" stroke=\"none\"/><circle cx=\"14.6\" cy=\"13.2\" r=\"1.15\" fill=\"%C\" stroke=\"none\"/>",
  "teams": "<rect x=\"3\" y=\"6.5\" width=\"12\" height=\"11.5\" rx=\"2.5\"/><path d=\"M6.4 9.9h5.2M9 9.9v5.3\"/><circle cx=\"18.2\" cy=\"7.2\" r=\"1.9\"/><path d=\"M15 10.8h4.6c.8 0 1.4.6 1.4 1.4v2.6a3.4 3.4 0 0 1-5.4 2.8\"/>",
  "basecamp": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M4.1 14.8c2.3-2.9 4.2-4.9 5.8-4.9 1.8 0 2.3 3.2 4.1 3.2 1.3 0 2.6-1.2 5.8-4.4\"/>",
  "chatgpt": "<rect x=\"8.6\" y=\"3.3\" width=\"6.8\" height=\"17.4\" rx=\"3.4\" transform=\"rotate(0 12 12)\"/><rect x=\"8.6\" y=\"3.3\" width=\"6.8\" height=\"17.4\" rx=\"3.4\" transform=\"rotate(60 12 12)\"/><rect x=\"8.6\" y=\"3.3\" width=\"6.8\" height=\"17.4\" rx=\"3.4\" transform=\"rotate(120 12 12)\"/>",
  "grok": "<path d=\"M17.3 6.1A7.6 7.6 0 1 0 19 15.6\"/><path d=\"M5 20.4L20.4 4.9\"/>",
  "mail": "<rect x=\"3.2\" y=\"5.5\" width=\"17.6\" height=\"13\" rx=\"2.5\"/><path d=\"M4 7.3l8 5.9 8-5.9\"/>",
  "calendar": "<rect x=\"3.5\" y=\"5\" width=\"17\" height=\"15\" rx=\"2.5\"/><path d=\"M3.5 9.5h17M8 3v4M16 3v4\"/><circle cx=\"8.3\" cy=\"14\" r=\"0.95\" fill=\"%C\" stroke=\"none\"/><circle cx=\"12\" cy=\"14\" r=\"0.95\" fill=\"%C\" stroke=\"none\"/><circle cx=\"15.7\" cy=\"14\" r=\"0.95\" fill=\"%C\" stroke=\"none\"/>",
  "messages": "<path d=\"M4.5 6.5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-7l-4 3.5v-3.5a2 2 0 0 1-2-2z\"/><path d=\"M8.3 9h7.4M8.3 12h4.6\"/>",
  "photos": "<path d=\"M12 12L12.00 4.20A3.9 3.9 0 0 0 12 12ZM12 12L19.80 12.00A3.9 3.9 0 0 0 12 12ZM12 12L12.00 19.80A3.9 3.9 0 0 0 12 12ZM12 12L4.20 12.00A3.9 3.9 0 0 0 12 12Z\"/>",
  "maps": "<path d=\"M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z\"/><circle cx=\"12\" cy=\"10\" r=\"2.3\"/>",
  "contacts": "<circle cx=\"12\" cy=\"8.8\" r=\"3.3\"/><path d=\"M5.5 19.5c.9-3 3.4-5 6.5-5s5.6 2 6.5 5\"/>",
  "ghostty": "<path d=\"M5.5 20.5V11a6.5 6.5 0 0 1 13 0v9.5l-2.17-1.5-2.16 1.5-2.17-1.5-2.17 1.5-2.16-1.5z\"/><path d=\"M8.9 10l1.9 1.4-1.9 1.4M12.9 12.8h2.3\"/>",
  "steam": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><circle cx=\"15.2\" cy=\"9.3\" r=\"2.7\"/><circle cx=\"8.4\" cy=\"15.1\" r=\"1.7\"/><path d=\"M13.2 11.1l-3.5 2.9M3.8 13.4l3.1 1.2\"/>",
  "telegram": "<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M6.1 11.9l11.2-4.6-1.8 9.6-5.3-3.6z\"/><path d=\"M10.2 13.3l4-3.4\"/>",
  "youtubemusic": "<circle cx=\"12\" cy=\"12\" r=\"9\" stroke-width=\"1.4\"/><circle cx=\"12\" cy=\"12\" r=\"6\" stroke-width=\"1.4\"/><path d=\"M10.2 9.1l5 2.9-5 2.9z\" fill=\"%C\" stroke=\"none\"/>",
  "edge": "<path d=\"M20.9 11.4a9 9 0 1 0 -1.6 5.8\"/>\n<path d=\"M20.9 11.4c.2 3 -5 2.4 -6.9 1.5c1.4 -1.6 .4 -4 -2.3 -3.9c-1.7 .1 -2.9 1.2 -2.8 3.2c.3 4 4.4 6.2 10.4 4.8\"/>\n<path d=\"M3 12.6c-.3 -4 8.7 -7.2 11.3 -2.7\"/>",
  "tensaku": "<path d=\"M10.3 4.9C13.7 3.75 17.6 5.8 18.9 9.6C20.1 13.1 18.4 17.25 14.8 18.6C11.1 19.9 6.6 18 5.25 14.25C4.1 10.9 5.6 6.75 9.4 5.25C11.6 4.5 14.1 4.7 15.9 5.6C16.9 6 18 5.4 19.1 4.3\"/>",
  "rustdesk": "<path d=\"M4.82 16.40A7.6 7.6 0 0 1 15.20 6.02\"/><path d=\"M19.18 7.60A7.6 7.6 0 0 1 8.80 17.98\"/>",
  "gemini": "<path d=\"M12 3.2C12.4 8.2 15.8 11.6 20.8 12C15.8 12.4 12.4 15.8 12 20.8C11.6 15.8 8.2 12.4 3.2 12C8.2 11.6 11.6 8.2 12 3.2Z\"/>",
  "copilot": "<path d=\"M4.5 12.5C4.5 7.8 7.6 5 12 5C16.4 5 19.5 7.8 19.5 12.5V15.2C19.5 17.8 16.4 19.5 12 19.5C7.6 19.5 4.5 17.8 4.5 15.2Z\"/><rect x=\"6.2\" y=\"8\" width=\"5.2\" height=\"4.4\" rx=\"2\"/><rect x=\"12.6\" y=\"8\" width=\"5.2\" height=\"4.4\" rx=\"2\"/><circle cx=\"10\" cy=\"15.6\" r=\".9\" fill=\"%C\" stroke=\"none\"/><circle cx=\"14\" cy=\"15.6\" r=\".9\" fill=\"%C\" stroke=\"none\"/>",
  "cursor": "<path d=\"M12 3.2L19.6 7.6V16.4L12 20.8L4.4 16.4V7.6Z\"/><path d=\"M4.4 7.6L12 12L19.6 7.6M12 12V20.8\"/>",
  "opencode": "<rect x=\"5\" y=\"4\" width=\"14\" height=\"16\" rx=\"1.2\"/><rect x=\"9\" y=\"8\" width=\"6\" height=\"8\" rx=\".6\"/>",
  "crush": "<path d=\"M12 19.2C7.2 16 4.2 13.2 4.2 9.8C4.2 7.4 6 5.6 8.3 5.6C9.8 5.6 11.2 6.4 12 7.7C12.8 6.4 14.2 5.6 15.7 5.6C18 5.6 19.8 7.4 19.8 9.8C19.8 13.2 16.8 16 12 19.2Z\"/>",
  "pi": "<path d=\"M4.6 9C4.9 7.9 5.8 7.4 7.2 7.4H19.4M9.4 7.4C9.4 12 8.8 15.4 7.4 18.4M15 7.4V15.6C15 17.4 16 18 17.8 17.4\"/>",
  "omp": "<circle cx=\"12\" cy=\"12\" r=\"8.6\"/><path d=\"M8 9.4H16.2M10.3 9.4C10.3 12 10 14 9.2 15.6M13.8 9.4V14.2C13.8 15.4 14.4 15.8 15.6 15.4\"/>",
  "hermes": "<path d=\"M4 16C6.6 11.4 11.4 7.8 20.2 5.8C17 8.4 15.4 9.8 14.2 11\"/><path d=\"M4 16C7.4 14.2 11.6 12.8 18 12.2C15.6 13.8 13.6 15 12.2 15.6\"/><path d=\"M4 16C6.8 16.8 10 17.4 14.6 17.2C12.2 18.6 9.4 19.2 7 19\"/>",
  "muse": "<path d=\"M12 12C10.1 8.7 8.6 7.2 6.7 7.2C4.6 7.2 3.2 9.4 3.2 12C3.2 14.6 4.6 16.8 6.7 16.8C8.6 16.8 10.1 15.3 12 12C13.9 8.7 15.4 7.2 17.3 7.2C19.4 7.2 20.8 9.4 20.8 12C20.8 14.6 19.4 16.8 17.3 16.8C15.4 16.8 13.9 15.3 12 12Z\"/>",
  "openclaw": "<path d=\"M7 20.2C6.2 15.6 6.8 11.4 9.4 8.2C11.8 5.4 15.4 4 19.4 4.4C17.6 6 16.4 7.6 15.8 9.6C17.6 9.2 19.4 9.6 20.6 10.6C18.4 13 15.2 14 12.2 13.4C10.8 15.4 10.2 17.6 10.4 20.2\"/>"
}

function svg(name, color) {
  var body = (icons[name] || icons.app).split("%C").join(color)
  return "data:image/svg+xml;utf8," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + color +
    '" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>')
}

// The same icon with a thicker stroke, for a knockout "halo" drawn in the bar's
// background colour behind the real icon (keeps it crisp over the audio
// equalizer).
function halo(name, color, strokeWidth) {
  var body = (icons[name] || icons.app).split("%C").join(color)
  return "data:image/svg+xml;utf8," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + color +
    '" stroke-width="' + strokeWidth + '" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>')
}
