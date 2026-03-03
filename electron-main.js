'use strict';

const { app, BrowserWindow, session, ipcMain, dialog } = require('electron');
const path = require('path');

// ── Keep a global reference to prevent garbage collection ────────────────────
let mainWindow = null;

// ── Prevent multiple instances ────────────────────────────────────────────────
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}

// ── Create the main window ────────────────────────────────────────────────────
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'Coyote Controller',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    backgroundColor: '#0d0d0d',
    // Hide the default menu bar (File/Edit/View etc.) — not needed for this app
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      // Required for Web Serial API and other experimental APIs
      experimentalFeatures: true,
      // Allow autoplay without user gesture (needed for Web Audio to start cleanly)
      autoplayPolicy: 'no-user-gesture-required',
    },
  });

  // Load the app
  mainWindow.loadFile(path.join(__dirname, 'web', 'index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ── App ready ─────────────────────────────────────────────────────────────────
app.whenReady().then(() => {
  setupPermissions();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  // On non-macOS, quit when all windows close
  if (process.platform !== 'darwin') app.quit();
});

// ── Permission & device handling ──────────────────────────────────────────────
function setupPermissions() {
  const ses = session.defaultSession;

  // Grant media, serial, usb, and notifications permissions without prompting
  ses.setPermissionRequestHandler((webContents, permission, callback) => {
    const allowed = new Set(['media', 'serial', 'usb', 'notifications', 'fullscreen']);
    callback(allowed.has(permission));
  });

  ses.setPermissionCheckHandler((_webContents, permission) => {
    const allowed = new Set(['media', 'serial', 'usb', 'notifications', 'fullscreen']);
    return allowed.has(permission);
  });

  // ── Web Serial: auto-grant all port requests ──────────────────────────────
  // When navigator.serial.requestPort() is called in the renderer, Electron
  // fires this event instead of showing a browser picker dialog.
  // We pass all available ports back to the renderer so the app can present
  // its own selection UI (or auto-select by VID/PID).
  ses.on('select-serial-port', (event, portList, webContents, callback) => {
    event.preventDefault();

    if (portList.length === 0) {
      callback(''); // No ports available
      return;
    }

    // Try to auto-select a DG-LAB Coyote device by known vendor IDs.
    // DG-LAB devices commonly appear on CH340/CH341 USB-serial chips (VID 1a86)
    // or CP210x (VID 10c4). Adjust if your hardware differs.
    const COYOTE_VIDS = new Set(['1a86', '10c4', '0483', '1d50']);
    const coyotePort = portList.find(p =>
      p.vendorId && COYOTE_VIDS.has(p.vendorId.toLowerCase().replace('0x', '').padStart(4, '0'))
    );

    if (coyotePort) {
      callback(coyotePort.portId);
    } else {
      // Fall back to first available port — the app UI handles which slot it goes to
      callback(portList[0].portId);
    }
  });

  // Grant serial port access without user confirmation prompts
  ses.on('serial-port-added', (event, port) => {
    event.preventDefault();
  });

  ses.on('serial-port-removed', (event, port) => {
    event.preventDefault();
  });

  // Grant device permissions (serial + USB) automatically
  ses.setDevicePermissionHandler((details) => {
    if (details.deviceType === 'serial') return true;
    if (details.deviceType === 'usb')    return true;
    return false;
  });

  // ── USB HID: auto-grant for known device classes ──────────────────────────
  ses.on('select-hid-device', (event, details, callback) => {
    event.preventDefault();
    if (details.deviceList.length > 0) {
      callback(details.deviceList[0].deviceId);
    } else {
      callback('');
    }
  });

  ses.setPermissionCheckHandler((webContents, permission, requestingOrigin, details) => {
    return true; // Allow all permission checks from local app
  });
}

// ── IPC: utility helpers exposed to renderer via preload ──────────────────────
ipcMain.handle('get-version', () => app.getVersion());

ipcMain.handle('get-platform', () => process.platform);

// Renderer can ask to list serial ports (useful for port selection UI)
ipcMain.handle('list-serial-ports', async () => {
  // Electron doesn't expose a direct API to list serial ports from main process
  // without the serialport npm package. The renderer uses navigator.serial instead.
  // This handler is a placeholder for future native serial support if needed.
  return [];
});
