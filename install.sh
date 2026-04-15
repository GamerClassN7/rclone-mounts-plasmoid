#!/usr/bin/env bash
# ============================================================
# install.sh – Instalátor Rclone Mounts Plasmoidu (Plasma 6)
# ============================================================
set -euo pipefail

PLASMOID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_ID="org.kde.plasma.rclone-mounts"

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
MOUNT_BASE="$HOME/mnt/rclone"
mkdir -p "$MOUNT_BASE"
echo "   📁 Mount directory: $MOUNT_BASE"

# ── Systemd user service pro RC daemon ───────────────────────────────────────
echo ""
echo "🔧 Configuring rclone RC daemon autostart..."

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
    echo "   ✅ RC daemon started and enabled at login"
else
    echo "   ⚠️  Daemon failed to start - check: systemctl --user status rclone-rc"
fi

# ── Restart Plasma shellu ─────────────────────────────────────────────────────
echo ""
echo "🔄 Restarting Plasma shell (widget will load in a moment)..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
kstart6 plasmashell &>/dev/null &
systemctl --user restart plasma-plasmashell.service

echo ""
echo "================================================="
echo "✅ Done!"
echo "================================================="
echo ""
echo "Add widget: right-click desktop -> Add Widgets -> 'Rclone'"
echo ""
echo "RC daemon status: systemctl --user status rclone-rc"
echo ""
