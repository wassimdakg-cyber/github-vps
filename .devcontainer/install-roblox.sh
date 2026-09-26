#!/bin/bash
set -e
# Installs the Roblox Windows player into a clean wine prefix.
# NOTE: Hyperion anti-cheat blocks the player from launching under Wine
# (by design). This only provisions the game files + launcher entry.
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export DISPLAY=:1
export WINEPREFIX=/home/codespace/.wine-roblox
export WINEARCH=win64
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml="

echo "=== wine32:libwine:i386 already in image; init prefix ==="
sudo chown -R codespace:codespace $WINEPREFIX 2>/dev/null || true
mkdir -p $WINEPREFIX
timeout 240 wineboot --init >/tmp/rb-init.log 2>&1 || true

echo "=== resolve player + launcher ==="
VER=$(timeout 60 curl -fsSL "https://clientsettingscdn.roblox.com/v2/client-version/WindowsPlayer")
V=$(python3 -c "import json,sys; print(json.load(sys.stdin)['clientVersionUpload'])" <<<"$VER")
G="$V"
echo "GUID=$G"
BASE="https://setup.rbxcdn.com"
cd /tmp
curl -fLso /tmp/RobloxPlayerLauncher.exe -A "Mozilla/5.0" "$BASE/RobloxPlayerLauncher.exe" || true

VERDIR="$WINEPREFIX/drive_c/users/codespace/AppData/Local/Roblox/Versions/$G"
mkdir -p "$VERDIR"
curl -fsS -A "Mozilla/5.0" "$BASE/$G-rbxPkgManifest.txt" -o /tmp/man.txt
python3 - "$VERDIR" "$G" <<'EOF'
import zipfile, os, shutil, sys
dst=sys.argv[1]; os.makedirs(dst,exist_ok=True)
g=sys.argv[2]
packages=[]
block=[]
for ln in open('/tmp/man.txt'):
    ln=ln.strip()
    if not ln: continue
    block.append(ln)
    if len(block)==4:
        packages.append(tuple(block)); block=[]
print(len(packages),"packages")
for p in packages:
    name,md5,s1,s2=p
    code=os.system(f"curl -fsS -A 'Mozilla/5.0' -o /tmp/rbdl.zip 'https://setup.rbxcdn.com/{g}-{name}' --max-time 600")
    if code!=0: print("DL FAIL",name); continue
    got=__import__('hashlib').md5(open('/tmp/rbdl.zip','rb').read()).hexdigest()
    if got!=md5: print("MD5 MISMATCH",name); continue
    zf=zipfile.ZipFile('/tmp/rbdl.zip')
    n=0
    for m in zf.infolist():
        fn=m.filename.replace(chr(92),"/").lstrip("/")
        if not fn: continue
        tgt=os.path.normpath(os.path.join(dst,fn))
        if not tgt.startswith(os.path.normpath(dst)): continue
        if m.is_dir() or fn.endswith("/"):
            try: os.makedirs(tgt,exist_ok=True)
            except FileExistsError: pass
            continue
        if os.path.exists(tgt): continue
        try:
            os.makedirs(os.path.dirname(tgt),exist_ok=True)
            with zf.open(m) as s, open(tgt,"wb") as o: shutil.copyfileobj(s,o)
            n+=1
        except Exception: pass
    print("extracted",name,n,"files")
EOF
echo "=== wrapper + desktop entry ==="
sudo tee /usr/local/bin/roblox >/dev/null <<'EOF2'
#!/bin/bash
[ -f /tmp/dbus.env ] && source /tmp/dbus.env
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export DISPLAY=:1
export WINEPREFIX=/home/codespace/.wine-roblox
export WINEDEBUG=-all
export WINEDLLOVERRIDES=mscoree,mshtml=
V="$(ls -d /home/codespace/.wine-roblox/drive_c/users/codespace/AppData/Local/Roblox/Versions/version-*/ 2>/dev/null | tail -1)"
[ -n "$V" ] && cd "$V" && exec /usr/bin/wine "$V/RobloxPlayerBeta.exe" "$@"
EOF2
sudo chmod +x /usr/local/bin/roblox

mkdir -p /home/codespace/.local/share/applications
cat >/home/codespace/.local/share/applications/roblox.desktop <<'EOF3'
[Desktop Entry]
Type=Application
Name=Roblox
Comment=Roblox Player (blocked by Hyperion under Wine)
Exec=/usr/local/bin/roblox
Icon=applications-games
Terminal=false
Categories=Game;
StartupNotify=false
EOF3

echo "ROBLOX_INSTALL_DONE BETA=$([ -f "$VERDIR/RobloxPlayerBeta.exe" ] && echo 1 || echo 0)"