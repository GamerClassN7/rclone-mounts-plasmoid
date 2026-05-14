#!/usr/bin/env bash
# ============================================================
# install.sh – Instalátor Rclone Mounts Plasmoidu (Plasma 6)
# Spusť BEZ sudo: bash install.sh
# ============================================================
set -euo pipefail

# ── Ochrana: nespouštět jako root ────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo "❌ Nespouštěj tento skript jako root / sudo!"
    echo "   Spusť normálně: bash install.sh"
    echo ""
    echo "   NM dispatcher (WiFi reconnect) se nainstaluje automaticky"
    echo "   a vyžádá si sudo heslo jen pro ten jeden příkaz."
    exit 1
fi

PLASMOID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_ID="org.kde.plasma.rclone-mounts"
REAL_USER="$USER"
REAL_HOME="$HOME"
REAL_UID="$(id -u)"

echo "================================================="
echo "  Rclone Mounts Plasmoid - Installer"
echo "================================================="
echo ""

# Kontrola rclone
if ! command -v rclone &>/dev/null; then
    echo "❌ rclone not found! Install it from: https://rclone.org/install/"
    exit 1
fi
echo "✅ $(rclone --version | head -1)"

# ── Instalace / upgrade plasmoidu ────────────────────────────────────────────
echo ""
echo "📦 Installing plasmoid..."
if kpackagetool6 --list --type Plasma/Applet 2>/dev/null | grep -q "$PLASMOID_ID"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$PLASMOID_DIR"
    echo "   ♻️  Plasmoid upgraded (settings preserved)"
else
    kpackagetool6 --type Plasma/Applet --install "$PLASMOID_DIR"
    echo "   ✅ Plasmoid installed"
fi

# ── Adresář pro mounty ────────────────────────────────────────────────────────
MOUNT_BASE="$REAL_HOME/mnt/rclone"
mkdir -p "$MOUNT_BASE"
echo "   📁 Mount directory: $MOUNT_BASE"

# ── Systemd user service pro RC daemon ───────────────────────────────────────
echo ""
echo "🔧 Configuring rclone RC daemon autostart..."

SYSTEMD_DIR="$REAL_HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/rclone-rc.service" << 'EOF'
[Unit]
Description=Rclone RC Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone rcd --rc-addr=localhost:5572 --rc-no-auth
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable rclone-rc.service
systemctl --user start rclone-rc.service

if systemctl --user is-active --quiet rclone-rc.service; then
    echo "   ✅ RC daemon started and enabled at login"
else
    echo "   ⚠️  Daemon failed to start - check: systemctl --user status rclone-rc"
fi

# ── Auto-mount při připojení sítě ────────────────────────────────────────────
echo ""
echo "🔧 Configuring auto-mount on network connect..."

AM_CONF_DIR="$REAL_HOME/.config/rclone-plasmoid"
AM_CONF="$AM_CONF_DIR/automount.conf"
AM_SCRIPT="$REAL_HOME/.local/bin/rclone-automount.sh"

mkdir -p "$AM_CONF_DIR"
mkdir -p "$REAL_HOME/.local/bin"

# Konfigurační soubor se seznamem remotů (pokud ještě neexistuje)
if [ ! -f "$AM_CONF" ]; then
    cat > "$AM_CONF" << 'CONF'
# Rclone Auto-Mount – seznam remotů připojovaných při startu sítě
# Jeden remote na řádek, přesně tak jak ho vrací "rclone listremotes"
# Příklad:
#   gdrive:
#   dropbox:
#   mysftp:
CONF
    echo "   📄 Config created: $AM_CONF"
else
    echo "   📄 Config exists: $AM_CONF"
fi

# Mount skript
cat > "$AM_SCRIPT" << 'SCRIPT'
#!/usr/bin/env bash
# rclone-automount.sh – připojí remoty ze seznamu, jakmile je RC daemon dostupný
set -euo pipefail

CONF="$HOME/.config/rclone-plasmoid/automount.conf"
RC_ADDR="localhost:5572"
MOUNT_BASE="$HOME/mnt/rclone"

# Počkej max 60s na RC daemon
echo "[rclone-automount] Čekám na RC daemon na $RC_ADDR..."
for i in $(seq 60); do
    rclone rc mount/listmounts --rc-addr="$RC_ADDR" --rc-no-auth &>/dev/null && break
    sleep 1
done

if ! rclone rc mount/listmounts --rc-addr="$RC_ADDR" --rc-no-auth &>/dev/null; then
    echo "[rclone-automount] ⚠️  RC daemon nedostupný po 60s, přeskakuji."
    exit 0
fi

[ ! -f "$CONF" ] && { echo "[rclone-automount] Žádný config ($CONF), přeskakuji."; exit 0; }

while IFS= read -r remote; do
    [[ -z "$remote" || "$remote" =~ ^[[:space:]]*# ]] && continue
    remote="${remote// /}"
    name="${remote%%:}"
    mp="$MOUNT_BASE/$name"

    # Zkontroluj jestli již je namountováno
    if rclone rc mount/listmounts --rc-addr="$RC_ADDR" --rc-no-auth 2>/dev/null \
        | python3 -c "import sys,json; mps=[m['MountPoint'] for m in json.load(sys.stdin).get('mountPoints',[])]; exit(0 if '$mp' in mps else 1)" 2>/dev/null; then
        echo "[rclone-automount] ✓ Přeskakuji $remote – už namountováno"
        continue
    fi

    mkdir -p "$mp"
    if rclone rc mount/mount fs="$remote" mountPoint="$mp" \
        --rc-addr="$RC_ADDR" --rc-no-auth 2>/dev/null; then
        echo "[rclone-automount] ✅ $remote → $mp"
    else
        echo "[rclone-automount] ❌ Selhalo: $remote"
    fi
done < "$CONF"
SCRIPT

chmod +x "$AM_SCRIPT"

# systemd user service
cat > "$SYSTEMD_DIR/rclone-automount.service" << 'EOF'
[Unit]
Description=Rclone Auto-Mount (on network)
After=network.target rclone-rc.service
Wants=rclone-rc.service

[Service]
Type=oneshot
ExecStart=%h/.local/bin/rclone-automount.sh
RemainAfterExit=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable rclone-automount.service
echo "   ✅ Auto-mount service enabled (runs at login)"

# NetworkManager dispatcher – volá jen sudo pro jeden soubor, zbytek bežel jako user
NM_DISPATCHER_DIR="/etc/NetworkManager/dispatcher.d"
NM_SCRIPT="$NM_DISPATCHER_DIR/99-rclone-automount"

if [ -d "$NM_DISPATCHER_DIR" ]; then
    echo ""
    echo "🌐 Nastavuji NM dispatcher (automount při WiFi reconnect)..."
    echo "   (bude vyžadováno sudo heslo pro zápis do /etc/NetworkManager/)"

    sudo bash -c "cat > '$NM_SCRIPT'" << NMSCRIPT
#!/usr/bin/env bash
# Spustí rclone-automount při každém připojení sítě / VPN
[ "\$2" = "up" ] || [ "\$2" = "vpn-up" ] || exit 0
sleep 2
XDG_RUNTIME_DIR=/run/user/${REAL_UID} \
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${REAL_UID}/bus \
HOME=${REAL_HOME} \
su -s /bin/bash -c "${REAL_HOME}/.local/bin/rclone-automount.sh" ${REAL_USER} &
NMSCRIPT

    sudo chmod +x "$NM_SCRIPT"
    echo "   ✅ NM dispatcher nastaven – auto-mount při každém připojení WiFi/VPN"
else
    echo "   ℹ️  NetworkManager dispatcher přeskočen (adresář $NM_DISPATCHER_DIR neexistuje)"
fi

# ── Restart Plasma shellu ─────────────────────────────────────────────────────
echo ""
echo "🔄 Restarting Plasma shell..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
kstart6 plasmashell &>/dev/null &
systemctl --user restart plasma-plasmashell.service 2>/dev/null || true

echo ""
echo "================================================="
echo "✅ Done!"
echo "================================================="
echo ""
echo "Add widget: right-click desktop -> Add Widgets -> 'Rclone'"
echo ""
echo "RC daemon status:    systemctl --user status rclone-rc"
echo "Auto-mount config:   ~/.config/rclone-plasmoid/automount.conf"
echo "Auto-mount log:      journalctl --user -u rclone-automount"
echo ""
echo "💡 Tip: V plasmoidu klikni na ikonu sítě u remotu pro zapnutí auto-mountu"
echo ""
