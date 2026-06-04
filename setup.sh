#!/bin/bash
# ============================================================
#  Setup Script — Keyboard Monitor (Bahria University OS Project)
#  Installs required dependencies on Fedora
# ============================================================

echo "================================================"
echo "  Keyboard Monitor — Dependency Setup (Fedora)"
echo "================================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Please run as root: sudo ./setup.sh"
    exit 1
fi

echo "[*] Updating package list..."
dnf check-update -q

echo "[*] Installing required packages..."
dnf install -y zenity evtest xdotool xclip 2>/dev/null

# notify-send is part of libnotify-tools on Fedora
dnf install -y libnotify 2>/dev/null

echo ""
echo "[*] Making scripts executable..."
chmod +x keylogger.sh
chmod +x decode_keycodes.sh

echo ""
echo "================================================"
echo "  Setup complete!"
echo ""
echo "  Run the app with:"
echo "    sudo ./keylogger.sh"
echo ""
echo "  Decode a log file with:"
echo "    python3 decode_keycodes.py logs/<filename>.log"
echo "================================================"
