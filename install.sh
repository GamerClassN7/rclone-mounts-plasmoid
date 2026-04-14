#!/usr/bin/env bash
# ============================================================
# install.sh – Instalátor Rclone Mounts Plasmoidu (Plasma 6)
# ============================================================
set -euo pipefail

PLASMOID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_ID="org.kde.plasma.rclone-mounts"

echo "================================================="
echo "  Rclone Mounts Plasmoid – Instalátor"
echo "================================================="
echo ""

# Kontrola rclone
if ! command -v rclone &>/dev/null; then
    echo "❌ rclone nenalezen! Nainstaluj: https://rclone.org/install/"
    exit 1
fi
echo "✅ $(rclone --version | head -1)"

# ── Odinstaluj starou verzi ───────────────────────────────────────────────────
echo ""
echo "📦 Instaluji plasmoid..."
if kpackagetool6 --list --type Plasma/Applet 2>/dev/null | grep -q "$PLASMOID_ID"; then
    kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null || true
    echo "   ♻️  Stará verze odstraněna"
fi

# Instalace
kpackagetool6 --type Plasma/Applet --install "$PLASMOID_DIR"
echo "   ✅ Plasmoid nainstalován"

# ── Adresář pro mounty ────────────────────────────────────────────────────────
MOUNT_BASE="$HOME/mnt/rclone"
mkdir -p "$MOUNT_BASE"
echo "   📁 Adresář pro mounty: $MOUNT_BASE"

# ── Systemd user service pro RC daemon ───────────────────────────────────────
echo ""
echo "🔧 Nastavuji autostart rclone RC daemon..."

SYSTEMD_DIR="$HOME/.config/systemd/user"
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
    echo "   ✅ RC Daemon spuštěn a nastaven na autostart"
else
    echo "   ⚠️  Daemon se nespustil – zkontroluj: systemctl --user status rclone-rc"
fi

# ── Restart Plasma shellu ─────────────────────────────────────────────────────
echo ""
echo "🔄 Restartuji Plasma shell (widget se načte za chvíli)..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
kstart6 plasmashell &>/dev/null &

echo ""
echo "================================================="
echo "✅ Hotovo!"
echo "================================================="
echo ""
echo "Přidej widget: pravý klik na plochu → Přidat widget → 'Rclone'"
echo ""
echo "Stav RC daemona: systemctl --user status rclone-rc"
echo ""
