#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Piyote Controller — Raspberry Pi Installer
# Usage: curl -sSL https://raw.githubusercontent.com/maple204/Piyote-Controller/main/install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -e

REPO="maple204/Piyote-Controller"
APP_NAME="Piyote Controller"
INSTALL_DIR="/opt/piyote-controller"
TMP_TAR="/tmp/piyote-controller.tar.gz"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}→${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        Piyote Controller Installer       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Architecture check ────────────────────────────────────────────────────────
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  TAR_ARCH="arm64"
  APP_DIR="piyote-controller-linux-arm64"
  info "Detected: ARM64 (Raspberry Pi 5 / Pi 4 64-bit)"
elif [[ "$ARCH" == "x86_64" ]]; then
  TAR_ARCH="x64"
  APP_DIR="piyote-controller-linux-x64"
  info "Detected: x86_64"
else
  error "Unsupported architecture: $ARCH"
fi

# ── Check dependencies ────────────────────────────────────────────────────────
info "Checking dependencies..."
for cmd in curl wget tar; do
  if ! command -v "$cmd" &>/dev/null; then
    sudo apt-get install -y "$cmd" -qq
  fi
done

# ── Fetch latest release ──────────────────────────────────────────────────────
info "Fetching latest release from GitHub..."
RELEASE_JSON=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest") \
  || error "Could not reach GitHub. Check your internet connection."

LATEST_URL=$(echo "$RELEASE_JSON" \
  | grep "browser_download_url" \
  | grep "${TAR_ARCH}\.tar\.gz" \
  | head -1 \
  | cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
  error "No ${TAR_ARCH} release found at https://github.com/${REPO}/releases"
fi

LATEST_TAG=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | cut -d '"' -f 4)
info "Downloading ${APP_NAME} ${LATEST_TAG}..."
wget -q --show-progress -O "$TMP_TAR" "$LATEST_URL" \
  || error "Download failed."

# ── Install ───────────────────────────────────────────────────────────────────
info "Installing to ${INSTALL_DIR}..."
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$TMP_TAR" -C "$INSTALL_DIR" --strip-components=1
sudo chmod +x "${INSTALL_DIR}/piyote-controller"

# ── Symlink for terminal launch ───────────────────────────────────────────────
sudo ln -sf "${INSTALL_DIR}/piyote-controller" /usr/local/bin/piyote-controller

# ── Desktop entry (shows in Pi OS app menu) ───────────────────────────────────
info "Creating desktop entry..."
ICON_PATH="${INSTALL_DIR}/resources/app/assets/icon.png"
sudo tee /usr/share/applications/piyote-controller.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Piyote Controller
Comment=DG-LAB Coyote E-Stim Device Controller
Exec=${INSTALL_DIR}/piyote-controller
Icon=${ICON_PATH}
Type=Application
Categories=Utility;
Keywords=estim;coyote;audio;dac;
StartupNotify=true
EOF

# ── USB & Serial permissions ──────────────────────────────────────────────────
info "Configuring USB and serial port permissions..."
sudo usermod -a -G dialout "$USER" 2>/dev/null || true
sudo usermod -a -G plugdev "$USER" 2>/dev/null || true

# ── udev rules ────────────────────────────────────────────────────────────────
info "Installing udev rules for Coyote USB devices..."
sudo tee /etc/udev/rules.d/99-coyote-controller.rules > /dev/null <<'UDEV'
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", MODE="0666", GROUP="dialout", SYMLINK+="coyote%n"
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", MODE="0666", GROUP="dialout", SYMLINK+="coyote%n"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="sound", MODE="0666"
UDEV
sudo udevadm control --reload-rules
sudo udevadm trigger

# ── Update desktop database ───────────────────────────────────────────────────
update-desktop-database /usr/share/applications/ 2>/dev/null || true

# ── Clean up ──────────────────────────────────────────────────────────────────
rm -f "$TMP_TAR"

echo ""
success "${APP_NAME} ${LATEST_TAG} installed!"
echo ""
echo -e "  ${BOLD}Launch:${NC}"
echo -e "  • App menu  →  ${CYAN}Accessories → Piyote Controller${NC}"
echo -e "  • Terminal  →  ${CYAN}piyote-controller${NC}"
echo ""
warn "Log out and back in for USB/serial permissions to take effect."
echo ""
