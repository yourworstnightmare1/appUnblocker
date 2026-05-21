const { app, BrowserWindow, ipcMain, dialog, nativeImage, Menu } = require("electron");
const path = require("path");
const { spawn } = require("child_process");
const fs = require("fs");
const { applyMacUnblock } = require("./macos-unblocker");

const isWindows = process.platform === "win32";
const isMac = process.platform === "darwin";

function getCliScriptPath() {
  const devPath = path.join(__dirname, "..", "appunblocker.ps1");
  const bundledPath = path.join(process.resourcesPath, "appunblocker.ps1");
  if (app.isPackaged && fs.existsSync(bundledPath)) return bundledPath;
  if (fs.existsSync(devPath)) return devPath;
  if (fs.existsSync(bundledPath)) return bundledPath;
  return devPath;
}

function shellSingleQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function launchMacCli() {
  const scriptPath = getCliScriptPath();
  if (!fs.existsSync(scriptPath)) {
    dialog.showErrorBox("CLI not found", `Could not find appunblocker.ps1 at:\n${scriptPath}`);
    return;
  }

  const dir = path.dirname(scriptPath);
  const launcher = path.join(app.getPath("temp"), "appunblocker-launch.command");
  const content = `#!/bin/bash
cd ${shellSingleQuote(dir)}
if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -File ${shellSingleQuote(scriptPath)}
elif command -v powershell >/dev/null 2>&1; then
  exec powershell -NoProfile -File ${shellSingleQuote(scriptPath)}
else
  echo "PowerShell is required. Install from https://aka.ms/powershell"
  read -r -p "Press Enter to close..."
fi
`;

  fs.writeFileSync(launcher, content, { mode: 0o755 });
  spawn("open", [launcher], { detached: true, stdio: "ignore" }).unref();
}

function setupMacApplicationMenu() {
  const template = [
    {
      label: app.name,
      submenu: [
        { role: "about" },
        { type: "separator" },
        {
          label: "Launch CLI",
          accelerator: "Command+Shift+L",
          click: () => launchMacCli(),
        },
        { type: "separator" },
        { role: "services" },
        { type: "separator" },
        { role: "hide" },
        { role: "hideOthers" },
        { role: "unhide" },
        { type: "separator" },
        { role: "quit" },
      ],
    },
    {
      label: "Edit",
      submenu: [
        { role: "undo" },
        { role: "redo" },
        { type: "separator" },
        { role: "cut" },
        { role: "copy" },
        { role: "paste" },
        { role: "selectAll" },
      ],
    },
    {
      label: "Window",
      submenu: [{ role: "minimize" }, { role: "zoom" }, { type: "separator" }, { role: "front" }],
    },
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

/** @param {import('electron').WebContents} sender */
function createLogger(sender) {
  return (message, level = "info") => {
    if (!sender.isDestroyed()) {
      sender.send("launch-log", { message, level });
    }
  };
}

function createWindow() {
  const iconPath = path.join(__dirname, "assets", "icon.png");
  const icon = fs.existsSync(iconPath) ? nativeImage.createFromPath(iconPath) : undefined;

  const win = new BrowserWindow({
    width: 500,
    height: 560,
    resizable: true,
    minWidth: 460,
    minHeight: 480,
    icon,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setMenuBarVisibility(false);
  win.loadFile(path.join(__dirname, "renderer", "index.html"));
}

function launchWindows(targetPath, log) {
  return new Promise((resolve, reject) => {
    log("Preparing…", "info");
    log(`Got application: ${targetPath}`, "info");
    log("Setting compatibility layer and opening app…", "cmd");
    log("set __COMPAT_LAYER=RunAsInvoker", "cmd");

    // Match appunblocker.ps1 (env + Start-Process). cmd.exe "start" can hang
    // waiting on some installers, which left the GUI stuck on "Start".
    const psCommand = `$env:__COMPAT_LAYER='RunAsInvoker'; Start-Process -FilePath ${JSON.stringify(targetPath)}`;
    const child = spawn("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", psCommand], {
      stdio: "ignore",
      windowsHide: true,
    });

    child.on("error", (err) => {
      log(`FAIL: ${err.message}`, "error");
      reject(err);
    });
    child.on("close", (code) => {
      if (code === 0) {
        log("PASS: Application launched.", "success");
        resolve();
      } else {
        log(`FAIL: Launch failed (exit code ${code}).`, "error");
        reject(new Error(`Launch failed (exit code ${code})`));
      }
    });
  });
}

function openPath(targetPath, log) {
  return new Promise((resolve, reject) => {
    log(`open ${targetPath}`, "cmd");
    const child = spawn("open", [targetPath], { detached: true, stdio: "ignore" });
    child.on("error", (err) => {
      log(`FAIL: ${err.message}`, "error");
      reject(err);
    });
    child.on("close", (code) => {
      if (code === 0) {
        log("PASS: Opened launch shortcut.", "success");
        resolve();
      } else {
        log(`FAIL: Failed to open app (exit code ${code}).`, "error");
        reject(new Error(`Failed to open app (exit code ${code}).`));
      }
    });
    child.unref();
  });
}

async function launchMac(targetPath, macMethod, log) {
  const valid = new Set(["folder", "gatekeeper", "both"]);
  const method = valid.has(macMethod) ? macMethod : "folder";
  const result = await applyMacUnblock(targetPath, method, log);
  log(`Opening: ${result.launchTarget}`, "info");
  await openPath(result.launchTarget, log);
  return result;
}

ipcMain.handle("select-file", async () => {
  const filters = isWindows
    ? [{ name: "Executables", extensions: ["exe", "msi", "bat", "cmd", "com"] }, { name: "All files", extensions: ["*"] }]
    : [{ name: "Applications", extensions: ["app"] }, { name: "All files", extensions: ["*"] }];

  const result = await dialog.showOpenDialog({
    properties: isMac ? ["openFile", "openDirectory"] : ["openFile"],
    filters,
  });

  if (result.canceled || result.filePaths.length === 0) return null;
  return result.filePaths[0];
});

ipcMain.handle("launch-app", async (event, targetPath, macMethod) => {
  const log = createLogger(event.sender);

  if (!targetPath || !fs.existsSync(targetPath)) {
    log("FAIL: File not found.", "error");
    throw new Error("File not found.");
  }

  log("///////////////////////////////////", "info");
  log("////// appUnblocker loader //////", "info");
  log("///////////////////////////////////", "info");
  log("Starting actions…", "info");
  log(`App directory: ${targetPath}`, "info");

  try {
    if (isWindows) {
      await launchWindows(targetPath, log);
      log("Successfully finished running appUnblocker.", "success");
      return { platform: "windows" };
    }

    if (isMac) {
      const result = await launchMac(targetPath, macMethod, log);
      log("Successfully finished running appUnblocker.", "success");
      return {
        platform: "macos",
        shortcutPath: result.shortcutPath,
        wrapperPath: result.wrapperPath,
        wrapped: result.wrapped,
      };
    }

    log("FAIL: Unsupported platform.", "error");
    throw new Error("Unsupported platform.");
  } catch (err) {
    log(`Failed: ${err.message}`, "error");
    throw err;
  }
});

ipcMain.handle("get-platform", () => ({
  isWindows,
  isMac,
  platform: process.platform,
}));

app.whenReady().then(() => {
  if (isMac) {
    app.setName("appUnblocker");
    setupMacApplicationMenu();
  }

  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
