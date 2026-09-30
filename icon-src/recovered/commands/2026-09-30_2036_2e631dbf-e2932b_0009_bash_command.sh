D=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/a; cd $D
P='<path d="M7 3.5h7.5l5 5V19a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/>'
echo "$P"'<path d="M8.5 11h7M8.5 14h7M8.5 17h4"/>' > writer.svgbody
echo "$P"'<rect x="8.3" y="10.3" width="8" height="7.4" rx="1"/><path d="M12.3 10.3v7.4M8.3 14h8"/>' > calc.svgbody
echo "$P"'<path d="M9 17.5v-2.5M12.3 17.5v-5M15.6 17.5v-7"/>' > impress.svgbody
echo "$P"'<circle cx="10.3" cy="12" r="2.3"/><path d="M14 12.2l3 5.3h-6z"/>' > draw.svgbody
echo "$P"'<path d="M8 14h1.4l1.8 3.5 2.6-7.5h3"/>' > math.svgbody
echo "$P"'<ellipse cx="12.3" cy="11" rx="3.6" ry="1.4"/><path d="M8.7 11v5.4c0 .8 1.6 1.4 3.6 1.4s3.6-.6 3.6-1.4V11M8.7 13.7c0 .8 1.6 1.4 3.6 1.4s3.6-.6 3.6-1.4"/>' > base.svgbody
echo "$P" > libreoffice.svgbody
echo '<path d="M13.4 3.2L18.3 9.4l-1 9.2-4.6 2.5-6.3-4.8 1.8-8.7z"/><path d="M13.4 3.2l-2.6 9.8 1.9 8.1M7.9 16.3l2.9-3.3"/>' > obsidian.svgbody
echo '<path d="M6.5 13V4.5a1 1 0 0 1 1-1h6.5l3.5 3.5V13"/><path d="M9 7.5h3.5M9 10h5"/><circle cx="8.3" cy="17" r="2.5"/><circle cx="15.7" cy="17" r="2.5"/><path d="M10.8 16.8c.8-.6 1.6-.6 2.4 0"/>' > pdf.svgbody
echo '<rect x="3.5" y="3.5" width="17" height="17" rx="3.5"/><path d="M8 9h8M8 12h6M8 15h8"/>' > omawrite.svgbody
sed -n 's/^  "document": "\(.*\)",$/\1/p' ~/.config/omarchy/bar/modules/taskbar-icons.js | sed 's/\\"/"/g' > document.svgbody; cat document.svgbody
S=~/.claude/skills/taskbar-icons/scripts/icon-preview
$S p1.png writer.svgbody calc.svgbody impress.svgbody draw.svgbody math.svgbody && $S p2.png base.svgbody libreoffice.svgbody obsidian.svgbody pdf.svgbody omawrite.svgbody document.svgbody
