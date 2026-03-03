#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Coyote Controller — Raspberry Pi Installer
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/coyote-controller/main/install.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -e

# ── Config ────────────────────────────────────────────────────────────────────
REPO="YOUR_USERNAME/coyote-controller"   # ← Update this before publishing
APP_NAME="Coyote Controller"
TMP_DEB="/tmp/coyote-controller.deb"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}→${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Coyote Controller Installer        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Architecture check ────────────────────────────────────────────────────────
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  DEB_ARCH="arm64"
  info "Detected: ARM64 (Raspberry Pi 5 / Pi 4 64-bit)"
elif [[ "$ARCH" == "armv7l" || "$ARCH" == "armhf" ]]; then
  DEB_ARCH="armv7l"
  warn "32-bit ARM detected. Using x64 build as fallback — consider upgrading to 64-bit Pi OS."
  DEB_ARCH="x64"
elif [[ "$ARCH" == "x86_64" ]]; then
  DEB_ARCH="x64"
  info "Detected: x86_64"
else
  error "Unsupported architecture: $ARCH"
fi

# ── Check for required tools, install if missing ──────────────────────────────
info "Checking dependencies..."
for cmd in curl wget dpkg; do
  if ! command -v "$cmd" &>/dev/null; then
    info "Installing $cmd..."
    sudo apt-get install -y "$cmd" -qq
  fi
done

# ── Fetch latest release from GitHub ─────────────────────────────────────────
info "Fetching latest release from GitHub..."

RELEASE_JSON=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null) \
  || error "Could not reach GitHub. Check your internet connection and that the repo exists:\n  https://github.com/${REPO}"

LATEST_URL=$(echo "$RELEASE_JSON" \
  | grep "browser_download_url" \
  | grep "${DEB_ARCH}\.deb" \
  | head -1 \
  | cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
  error "No ${DEB_ARCH}.deb found in the latest release.\nCheck releases at: https://github.com/${REPO}/releases"
fi

LATEST_TAG=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | cut -d '"' -f 4)
info "Downloading ${APP_NAME} ${LATEST_TAG}..."

wget -q --show-progress -O "$TMP_DEB" "$LATEST_URL" \
  || error "Download failed. Try again or download manually from:\n  https://github.com/${REPO}/releases"

# ── Install the .deb ──────────────────────────────────────────────────────────
info "Installing ${APP_NAME}..."
sudo dpkg -i "$TMP_DEB" 2>/dev/null || true
# Fix any unmet dependencies
sudo apt-get install -f -y -qq

# ── USB & Serial permissions ──────────────────────────────────────────────────
info "Configuring USB and serial port permissions..."
sudo usermod -a -G dialout "$USER" 2>/dev/null || true
sudo usermod -a -G plugdev "$USER" 2>/dev/null || true

# ── udev rules for DG-LAB Coyote devices ─────────────────────────────────────
info "Installing udev rules for Coyote USB devices..."
sudo tee /etc/udev/rules.d/99-coyote-controller.rules > /dev/null <<'UDEV'
# DG-LAB Coyote E-Stim Device — USB Serial (CH340/CH341 chip)
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", MODE="0666", GROUP="dialout", SYMLINK+="coyote%n"
# CP2102 / CP210x (alternate chip variant)
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", MODE="0666", GROUP="dialout", SYMLINK+="coyote%n"
# STM32 DFU (firmware update mode)
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", MODE="0666", GROUP="plugdev"
# Generic USB Audio — ensure non-root access
SUBSYSTEM=="sound", MODE="0666"
UDEV

sudo udevadm control --reload-rules
sudo udevadm trigger

# ── USB Audio: ensure ALSA sees USB DACs ─────────────────────────────────────
info "Checking audio subsystem..."
if ! dpkg -l alsa-utils &>/dev/null 2>&1; then
  sudo apt-get install -y alsa-utils -qq
fi

# ── Clean up ──────────────────────────────────────────────────────────────────
rm -f "$TMP_DEB"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "${APP_NAME} ${LATEST_TAG} installed successfully!"
echo ""
echo -e "  ${BOLD}Launch options:${NC}"
echo -e "  • Application menu  →  ${CYAN}Accessories → Coyote Controller${NC}"
echo -e "  • Terminal          →  ${CYAN}coyote-controller${NC}"
echo ""
echo -e "  ${BOLD}USB tips:${NC}"
echo -e "  • Plug in USB DACs before launching — each appears as a selectable audio output"
echo -e "  • Coyote devices connect as serial ports (auto-detected)"
echo ""
warn "Log out and back in (or reboot) for USB/serial permissions to take full effect."
echo ""
