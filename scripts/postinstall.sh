#!/bin/bash
# Post-install script — run by dpkg after package installation
# This file is referenced in package.json under build.deb.afterInstall

# Add the installing user to the dialout and plugdev groups for serial/USB access
if [ -n "$SUDO_USER" ]; then
  usermod -a -G dialout "$SUDO_USER" 2>/dev/null || true
  usermod -a -G plugdev "$SUDO_USER" 2>/dev/null || true
fi

# Refresh the desktop application database so the app appears in the menu
update-desktop-database /usr/share/applications/ 2>/dev/null || true

# Refresh icon cache
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true
fi

exit 0
