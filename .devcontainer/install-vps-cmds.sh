#!/bin/bash
# Installs vps-start / vps-tunnel / vps-stop into /usr/local/bin on the box.
CF_BLOCK='
CF=$(command -v cloudflared 2>/dev/null || echo /tmp/cloudflared)
if [ ! -x "$CF" ]; then
  cd /tmp
  curl -fL -o cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" >/dev/null 2>&1 || echo "cloudflared download failed"
  sudo dpkg -i /tmp/cloudflared.deb >/dev/null 2>&1 || true
  CF=$(command -v cloudflared 2>/dev/null || echo /tmp/cloudflared)
  [ -x "$CF" ] || { echo "cloudflared not found"; exit 1; }
fi
'

cat > /tmp/vps-start-body <<BODY_END
#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export DISPLAY=:1
echo "=== bringing up desktop stack (idempotent) ==="
bash /workspaces/github-vps/.devcontainer/ensure-vps.sh 2>/dev/null || true
echo "=== cloudflare tunnel ==="
$CF_BLOCK
if ! pgrep -f "cloudflared tunnel --url http://localhost:6080" >/dev/null 2>&1; then
  setsid nohup "$CF" tunnel --url http://localhost:6080 --no-autoupdate > /tmp/cloudflared.log 2>&1 < /dev/null &
  echo "tunnel starting..."
else
  echo "tunnel already running"
fi
U=""
for i in \$(seq 1 40); do
  U=\$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" /tmp/cloudflared.log 2>/dev/null | head -1)
  [ -n "\$U" ] && break
  sleep 2
done
echo "=============================================="
echo "  VPS URL:  \${U:-NOT_FOUND_YET}"
if [ -n "\$U" ]; then echo "  Open:     \$U/vnc.html"; fi
echo "  RustDesk: run 'rustdesk --get-id' via ssh"
echo "=============================================="
BODY_END

cat > /tmp/vps-tunnel-body <<BODY_END
#!/bin/bash
$CF_BLOCK
if ! pgrep -f "cloudflared tunnel --url http://localhost:6080" >/dev/null 2>&1; then
  setsid nohup "$CF" tunnel --url http://localhost:6080 --no-autoupdate > /tmp/cloudflared.log 2>&1 < /dev/null &
fi
U=""
for i in \$(seq 1 40); do
  U=\$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" /tmp/cloudflared.log 2>/dev/null | head -1)
  [ -n "\$U" ] && break
  sleep 2
done
if [ -n "\$U" ]; then
  echo "VPS URL: \$U"
  echo "Open:    \$U/vnc.html"
else
  echo "VPS URL: NOT_FOUND_YET"
fi
BODY_END

sudo cp /tmp/vps-start-body /usr/local/bin/vps-start
sudo cp /tmp/vps-tunnel-body /usr/local/bin/vps-tunnel

sudo tee /usr/local/bin/vps-stop >/dev/null <<'EOF3'
#!/bin/bash
pkill -f "cloudflared tunnel" 2>/dev/null && echo "tunnel stopped" || echo "no tunnel running"
EOF3

sudo chmod +x /usr/local/bin/vps-start /usr/local/bin/vps-tunnel /usr/local/bin/vps-stop
rm -f /tmp/vps-start-body /tmp/vps-tunnel-body
echo "installed:"
ls -l /usr/local/bin/vps-*