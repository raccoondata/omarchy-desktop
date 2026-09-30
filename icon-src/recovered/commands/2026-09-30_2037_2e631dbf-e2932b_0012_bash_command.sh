D=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/a; cd $D
P='<path d="M7 3.5h7.5l5 5V19a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/>'
echo "$P"'<path d="M8.5 10.5h7M8.5 13.8h7M8.5 17.1h4.5"/>' > writer.svgbody
echo "$P"'<path d="M5.5 11.5h14M5.5 16h14M11 11.5v9"/>' > calc_b.svgbody
echo "$P"'<rect x="8" y="10" width="8.6" height="8" rx="1"/><path d="M12.3 10v8M8 14h8.6"/>' > calc_c.svgbody
echo "$P"'<path d="M9 17.5v-2.5M12.5 17.5v-5.5M16 17.5v-8"/>' > impress.svgbody
echo "$P"'<circle cx="9.8" cy="11.6" r="2.3"/><path d="M14.4 13.2l2.8 4.8h-5.6z"/>' > draw.svgbody
echo "$P"'<path d="M7.8 14.2h1.5l1.9 3.8 2.8-8h3.3"/>' > math.svgbody
echo "$P"'<ellipse cx="12.5" cy="10.5" rx="4" ry="1.6"/><path d="M8.5 10.5v6.2c0 .9 1.8 1.6 4 1.6s4-.7 4-1.6v-6.2"/>' > base_b.svgbody
echo "$P"'<ellipse cx="12.5" cy="10" rx="4" ry="1.5"/><path d="M8.5 10v7c0 .85 1.8 1.5 4 1.5s4-.65 4-1.5v-7M8.5 13.5c0 .85 1.8 1.5 4 1.5s4-.65 4-1.5"/>' > base_c.svgbody
echo '<path d="M13.4 3.2L18.3 9.4l-1 9.2-4.6 2.5-6.3-4.8 1.8-8.7z"/><path d="M13.4 3.2l-2.6 9.8 1.9 8.1"/>' > obsidian.svgbody
echo '<path d="M6 13.8V4.5a1 1 0 0 1 1-1h7l4 4v6.3"/><path d="M9 8h4M9 10.8h6"/><circle cx="8.6" cy="17.3" r="2.7"/><circle cx="15.4" cy="17.3" r="2.7"/><path d="M11.3 17c.45-.4 .95-.6 .7-.6s.25.2.7.6"/>' > pdf.svgbody
S=~/.claude/skills/taskbar-icons/scripts/icon-preview
$S p3.png writer.svgbody calc_b.svgbody calc_c.svgbody impress.svgbody draw.svgbody math.svgbody base_b.svgbody base_c.svgbody obsidian.svgbody pdf.svgbody
