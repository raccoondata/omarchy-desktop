SP=/tmp/claude-1000/-home-user-Work/2e631dbf-6b6a-4eb9-8346-4759cc1800bc/scratchpad; cd $SP
cat > edgeA.svg <<'EOF'
<path d="M20.978 11.372a9 9 0 1 0 -1.593 5.773"/>
<path d="M20.978 11.372c.21 2.993 -5.034 2.413 -6.913 1.486c1.392 -1.6 .402 -4.038 -2.274 -3.851c-1.745 .122 -2.927 1.157 -2.784 3.202c.28 3.99 4.444 6.205 10.36 4.79"/>
<path d="M3.022 12.628c-.283 -4.043 8.717 -7.228 11.248 -2.688"/>
<path d="M12.628 20.978c-2.993 -.21 -5.162 -4.725 -3.567 -9.748"/>
EOF
cat > edgeB.svg <<'EOF'
<path d="M20.9 11.4a9 9 0 1 0 -1.6 5.8"/>
<path d="M20.9 11.4c.2 3 -5 2.4 -6.9 1.5c1.4 -1.6 .4 -4 -2.3 -3.9c-1.7 .1 -2.9 1.2 -2.8 3.2c.3 4 4.4 6.2 10.4 4.8"/>
<path d="M3 12.6c-.3 -4 8.7 -7.2 11.3 -2.7"/>
EOF
cat > edgeC.svg <<'EOF'
<path d="M20.9 11.4a9 9 0 1 0 -1.6 5.8"/>
<path d="M20.9 11.4c.2 3 -5 2.4 -6.9 1.5c1.4 -1.6 .4 -4 -2.3 -3.9c-1.7 .1 -2.9 1.2 -2.8 3.2c.3 4 4.4 6.2 10.4 4.8"/>
EOF
~/.claude/skills/taskbar-icons/scripts/icon-preview $SP/edge2.png edgeA.svg edgeB.svg edgeC.svg >/dev/null && echo ok
