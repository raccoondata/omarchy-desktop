D=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad/icons/a; cd $D
mv calc_b.svgbody calc.svgbody; mv base_c.svgbody base.svgbody; rm -f calc_c.svgbody base_b.svgbody
echo '<path d="M14 3.2l4.6 5.9-1 8.2-5.4 3.6-6.2-4.6 2.4-8.3z"/><path d="M14 3.2l-3.1 9.3-4.9 3.8"/>' > obs_b.svgbody
echo '<path d="M14 3.2l4.6 5.9-1 8.2-5.4 3.6-6.2-4.6 2.4-8.3z"/><path d="M14 3.2l-3.1 9.3 1.3 8.3"/>' > obs_c.svgbody
echo '<path d="M14 3.2l4.6 5.9-1 8.2-5.4 3.6-6.2-4.6 2.4-8.3z"/><path d="M8.4 8l2.5 4.5 7.7-3.4M10.9 12.5l1.3 8.3"/>' > obs_d.svgbody
echo '<path d="M7 3.5h6.5l5 5V19a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/><path d="M8.5 8h4"/><rect x="7" y="12.3" width="4.3" height="4" rx="1.4"/><rect x="12.7" y="12.3" width="4.3" height="4" rx="1.4"/><path d="M11.3 13.3h1.4"/>' > pdf_b.svgbody
echo '<path d="M6 13.8V4.5a1 1 0 0 1 1-1h7l4 4v6.3"/><path d="M9 8h4M9 10.8h6"/><circle cx="8.6" cy="17.3" r="2.7"/><circle cx="15.4" cy="17.3" r="2.7"/><path d="M11.3 16.6h1.4"/>' > pdf_c.svgbody
S=~/.claude/skills/taskbar-icons/scripts/icon-preview
$S p4.png obs_b.svgbody obs_c.svgbody obs_d.svgbody pdf.svgbody pdf_b.svgbody pdf_c.svgbody
