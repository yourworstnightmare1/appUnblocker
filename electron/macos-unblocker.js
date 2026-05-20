const fs = require("fs");
const path = require("path");
const { execFile, execFileSync } = require("child_process");
const { promisify } = require("util");
const { randomUUID } = require("crypto");

const execFileAsync = promisify(execFile);

/** @typedef {'info' | 'success' | 'warn' | 'error' | 'cmd'} LogLevel */
/** @typedef {(message: string, level?: LogLevel) => void} LogFn */

/** @param {LogFn | undefined} log */
function emit(log, message, level = "info") {
  if (log) log(message, level);
}

/** If the user picked the nested .app inside a wrapper, use the outer wrapper path. */
function normalizeAppSelection(appPath) {
  const resolved = path.resolve(appPath);
  const base = path.basename(resolved);
  const parent = path.dirname(resolved);
  const plist = path.join(resolved, "Contents", "Info.plist");
  if (path.basename(parent) === base && fs.existsSync(plist)) {
    return parent;
  }
  return resolved;
}

/** @returns {string} Nested .app when already wrapped, else the bundle itself. */
function patchAppPath(appPath) {
  const resolved = path.resolve(appPath);
  const appName = path.basename(resolved);
  const nested = path.join(resolved, appName);
  const nestedPlist = path.join(nested, "Contents", "Info.plist");
  if (fs.existsSync(nestedPlist)) return nested;
  return resolved;
}

function isWrappedApp(appPath) {
  return patchAppPath(appPath) !== path.resolve(appPath);
}

async function readPlistKey(plistPath, key) {
  try {
    const { stdout } = await execFileAsync("/usr/libexec/PlistBuddy", ["-c", `Print :${key}`, plistPath]);
    const value = stdout.trim();
    return value.length > 0 ? value : null;
  } catch {
    return null;
  }
}

async function launchShortcutName(nestedAppPath) {
  const plistPath = path.join(nestedAppPath, "Contents", "Info.plist");
  const fallback = path.basename(nestedAppPath, ".app");
  const displayName =
    (await readPlistKey(plistPath, "CFBundleDisplayName")) ||
    (await readPlistKey(plistPath, "CFBundleName")) ||
    fallback;
  return `Launch ${displayName}.app`;
}

function isVolumeReadOnly(targetPath) {
  try {
    const dfLine = execFileSync("df", [targetPath], { encoding: "utf8" }).trim().split("\n")[1];
    if (!dfLine) return false;
    const volumePath = dfLine.trim().split(/\s+/).pop();
    const mounts = execFileSync("mount", { encoding: "utf8" });
    const mountLine = mounts.split("\n").find((line) => line.includes(` on ${volumePath} `));
    return mountLine ? /\bread-only\b/.test(mountLine) : false;
  } catch {
    return false;
  }
}

/** @param {LogFn | undefined} log */
function validateWritableBundle(selectionPath, log) {
  const patchApp = patchAppPath(selectionPath);
  const contentsDir = path.join(patchApp, "Contents");

  emit(log, "Checking app bundle…", "info");

  if (!fs.existsSync(patchApp) || !fs.statSync(patchApp).isDirectory()) {
    throw new Error("The selected .app bundle could not be found.");
  }
  if (!fs.existsSync(contentsDir)) {
    throw new Error("The selected path is not a valid .app bundle.");
  }
  if (path.extname(patchApp).toLowerCase() !== ".app") {
    throw new Error("Select a .app bundle.");
  }

  emit(log, `Resolved app: ${selectionPath}`, "info");
  if (isWrappedApp(selectionPath)) {
    emit(log, `Detected appUnblocker wrapper. Nested app: ${patchApp}`, "warn");
  }

  if (isVolumeReadOnly(contentsDir)) {
    emit(log, "FAIL: App is on a read-only volume.", "error");
    throw new Error(
      "This is a read-only volume. Move the app off the disk image to a folder such as Downloads, then try again."
    );
  }

  const testFile = path.join(contentsDir, ".appunblocker_write_test");
  try {
    fs.writeFileSync(testFile, "");
    fs.unlinkSync(testFile);
    emit(log, "PASS: App location is writable.", "success");
  } catch {
    emit(log, `FAIL: The app is not writable at ${selectionPath}`, "error");
    throw new Error(
      `The app is not writable at ${selectionPath}. Copy it to a writable folder (for example ~/Downloads) and try again.`
    );
  }
}

/** @param {LogFn | undefined} log */
async function createLaunchShortcut(parentDir, nestedAppPath, log) {
  const shortcutName = await launchShortcutName(nestedAppPath);
  const shortcutPath = path.join(parentDir, shortcutName);

  emit(log, `appUnblocker: Creating launch shortcut at ${shortcutPath}`, "cmd");
  if (fs.existsSync(shortcutPath)) {
    fs.unlinkSync(shortcutPath);
  }

  fs.symlinkSync(nestedAppPath, shortcutPath);
  if (!fs.lstatSync(shortcutPath).isSymbolicLink()) {
    throw new Error("Failed to create launch shortcut.");
  }

  emit(log, `PASS: Launch shortcut created at ${shortcutPath}`, "success");
  return shortcutPath;
}

/** @param {LogFn | undefined} log */
async function createWrapper(appPath, log) {
  const resolved = path.resolve(appPath);
  const parentDir = path.dirname(resolved);
  const appFileName = path.basename(resolved);
  const tempFolder = path.join(parentDir, `appUnblocker-${randomUUID()}`);
  const tempNested = path.join(tempFolder, appFileName);

  emit(log, "[Post-Patch] Applying appUnblocker…", "info");
  emit(log, `appUnblocker: Creating folder at ${tempFolder}`, "cmd");
  fs.mkdirSync(tempFolder);

  try {
    emit(log, `appUnblocker: Moving app into wrapper…`, "cmd");
    emit(log, `mv ${resolved} → ${tempNested}`, "cmd");
    fs.renameSync(resolved, tempNested);
    emit(log, `appUnblocker: Finalizing wrapper at ${resolved}`, "cmd");
    fs.renameSync(tempFolder, resolved);
  } catch (err) {
    try {
      if (fs.existsSync(tempFolder)) fs.rmSync(tempFolder, { recursive: true, force: true });
    } catch {
      /* ignore cleanup errors */
    }
    emit(log, `FAIL: ${err.message || "Failed to create appUnblocker wrapper."}`, "error");
    throw new Error(err.message || "Failed to create appUnblocker wrapper.");
  }

  const nestedApp = path.join(resolved, appFileName);
  emit(log, `PASS: Created wrapper at ${resolved}`, "success");

  const shortcutPath = await createLaunchShortcut(parentDir, nestedApp, log);

  return {
    wrapperPath: resolved,
    nestedApp,
    shortcutPath,
    wrapped: true,
  };
}

/** @param {LogFn | undefined} log */
async function refreshWrapper(wrapperPath, log) {
  const nestedApp = patchAppPath(wrapperPath);
  const parentDir = path.dirname(path.resolve(wrapperPath));

  emit(log, "[Post-Patch] Applying appUnblocker…", "info");
  emit(log, "appUnblocker: Wrapper already exists; refreshing launch shortcut only.", "warn");

  const shortcutPath = await createLaunchShortcut(parentDir, nestedApp, log);

  emit(log, `PASS: Refreshed wrapper at ${path.resolve(wrapperPath)}`, "success");

  return {
    wrapperPath: path.resolve(wrapperPath),
    nestedApp,
    shortcutPath,
    wrapped: true,
  };
}

/** @param {LogFn | undefined} log */
async function gatekeeperBypass(appBundlePath, log) {
  emit(log, "[Gatekeeper] Removing quarantine extended attribute…", "info");
  emit(log, `xattr -rd com.apple.quarantine "${appBundlePath}"`, "cmd");
  try {
    await execFileAsync("xattr", ["-rd", "com.apple.quarantine", appBundlePath]);
    emit(log, "PASS: Gatekeeper quarantine cleared.", "success");
  } catch (err) {
    emit(log, "WARN: xattr returned an error (attribute may already be absent).", "warn");
    if (err.stderr) emit(log, String(err.stderr).trim(), "warn");
  }
}

/**
 * @param {string} appPath
 * @param {'folder' | 'gatekeeper' | 'both'} method
 * @param {LogFn | undefined} log
 */
async function applyMacUnblock(appPath, method, log) {
  const resolved = normalizeAppSelection(appPath);

  if (!resolved.toLowerCase().endsWith(".app")) {
    throw new Error("Select a .app bundle.");
  }

  validateWritableBundle(resolved, log);
  emit(log, `macOS method: ${method}`, "info");

  const patchApp = patchAppPath(resolved);
  let launchTarget = resolved;
  let shortcutPath = null;
  let wrapperPath = resolved;

  if (method === "gatekeeper" || method === "both") {
    await gatekeeperBypass(patchApp, log);
    launchTarget = patchApp;
  }

  if (method === "folder" || method === "both") {
    emit(log, "[Folder Manipulation] Applying appUnblocker wrapper…", "info");
    const wrapperResult = isWrappedApp(resolved)
      ? await refreshWrapper(resolved, log)
      : await createWrapper(resolved, log);
    shortcutPath = wrapperResult.shortcutPath;
    wrapperPath = wrapperResult.wrapperPath;
    launchTarget = shortcutPath;
  }

  return {
    launchTarget,
    shortcutPath,
    wrapperPath,
    nestedApp: patchAppPath(wrapperPath),
    method,
  };
}

/** @deprecated Use applyMacUnblock */
async function applyAppUnblocker(appPath, log) {
  return applyMacUnblock(appPath, "folder", log);
}

module.exports = {
  applyMacUnblock,
  applyAppUnblocker,
  patchAppPath,
  isWrappedApp,
};
