'use strict';

// ── Preload script ────────────────────────────────────────────────────────────
// Runs in the renderer context BEFORE the page loads, with access to both
// Node.js APIs and the DOM. We use contextBridge to safely expose a minimal
// API surface to the renderer without enabling full nodeIntegration.

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  // Platform info (useful for platform-specific UI tweaks)
  platform: process.platform,
  isElectron: true,

  // App version
  getVersion: () => ipcRenderer.invoke('get-version'),

  // Utility: open a native error dialog (used for critical failures)
  // Not exposed directly — keep renderer/main boundary clean
});

// ── Suppress Electron's default keyboard shortcuts that conflict with the app ──
// (Electron enables F12 for devtools and Ctrl+R for reload by default in dev)
// These are already removed in production builds; this is just a safety guard.
window.addEventListener('keydown', (e) => {
  // Block F5 / Ctrl+R reload in production (prevents accidental resets mid-session)
  if (e.key === 'F5' || (e.ctrlKey && e.key === 'r')) {
    e.preventDefault();
  }
  // Block Ctrl+W / Cmd+W closing the window accidentally
  if ((e.ctrlKey || e.metaKey) && e.key === 'w') {
    e.preventDefault();
  }
}, true);
