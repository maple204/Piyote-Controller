# Piyote Controller

Multi-channel E-Stim controller for DG-LAB Coyote devices. Supports stereo USB DAC audio output across two devices (4 independent channels), Control / Biome / Synth modes, and direct USB serial connection to Coyote hardware.

---

## Install on Raspberry Pi (one-liner)

```bash
curl -sSL https://raw.githubusercontent.com/maple204/Piyote-Controller/main/install.sh | bash
```

After install, find it in **Application Menu → Accessories → Coyote Controller**, or run `coyote-controller` in a terminal.

> **First boot:** Log out and back in (or reboot) after install so USB/serial permissions take effect.

---

## Hardware Setup

**USB DACs** — Plug in one USB audio adapter per Coyote pair before launching:
- Primary DAC → drives CH1 (left) and CH2 (right)
- Secondary DAC → drives CH3 (left) and CH4 (right)

The app's DAC Settings panel will appear automatically when DACs are detected. Each USB DAC shows up as a separate audio output device.

**Coyote USB** — Connect Coyote devices via USB. They appear as serial ports (`/dev/coyote0`, `/dev/coyote1` etc. after udev rules install). Use the Connect buttons in the app header.

---

## Development

### Prerequisites
- Node.js 20+ and npm
- On Linux: `libasound2-dev` for audio (`sudo apt-get install libasound2-dev`)

### Run locally (any platform)
```bash
npm install
npm start
```

### Build .deb for Raspberry Pi (ARM64)
```bash
npm install
npm run build:arm64
# Output: dist/coyote-controller_1.0.0_arm64.deb
```

Cross-compilation works on any platform — `electron-builder` downloads the ARM64 Electron binary automatically. No QEMU or Pi needed to build.

### Build for x86 Linux
```bash
npm run build:x64
```

---

## Releasing a New Version

1. Update `"version"` in `package.json`
2. Commit and push
3. Create a git tag: `git tag v1.0.1 && git push origin v1.0.1`
4. GitHub Actions builds both ARM64 and x64 `.deb` files and attaches them to the release automatically

---

## Troubleshooting

**App doesn't appear in menu after install**
```bash
update-desktop-database ~/.local/share/applications/
```

**Serial port permission denied**
```bash
sudo usermod -a -G dialout $USER
# Then log out and back in
```

**No USB DAC audio output**
```bash
# List audio devices
aplay -l
# Set USB DAC as default (replace card number)
echo "defaults.pcm.card 1" >> ~/.asoundrc
echo "defaults.ctl.card 1" >> ~/.asoundrc
```

**Coyote device not detected**
```bash
# Check if device appears
ls /dev/ttyUSB* /dev/ttyACM* /dev/coyote* 2>/dev/null
# Check USB connection
dmesg | tail -20
```
