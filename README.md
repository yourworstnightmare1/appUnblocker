<p align="center">
<img width="512" alt="appunblocker_icn" src="https://github.com/user-attachments/assets/9b6aaedf-32a5-4fb5-84e9-b97c1f49d138" />
</p>

# appUnblocker
Open (almost) any executable file without administrator.

# How it works
## Windows
We abuse an oversight in the `set __COMPAT_LAYER` command that allows us to execute apps with elevated permissions without actually being on an administrator account.

## macOS
macOS actually has 2 different exploits:
- **Gatekeeper Bypass** - We can bypass the unidentified developer popup by using a command that tells macOS to ignore the app and execute anyways despite the app being unsigned. This is a more permanent solution, although if you're looking for an easier and more removable solution...

- **Folder Manipulation** - By using a trick with folders, we can trick macOS into believing that the app that is being ran is actually from a signed developer. This is done by making a folder with the same name as the target app. Then, we drag the target app into that folder. Then, we rename the folder to have `.app` at the end. Once we do this, we right-click (or control-click) the "app" and select "Show Package Contents". The real app should be inside, and you'll be able to launch it. Why this works? I don't know, I just find the exploits.

# Compatibility
## Windows
appUnblocker should run on **all Windows 10/11** devices that are **x86/x64/ARM64**. If you are using the CLI, you need **PowerShell 5.1 or newer**. It is very lightweight, so you shouldn't have to worry about hardware restrictions.

## macOS
appUnblocker's GUI edition requires **macOS 14.6 or higher**, and should run on **x86/x64/ARM64**.
The CLI edition requires **macOS 10.13 or higher**, and should run on **x86/x64/ARM64**, with **PowerShell 7 or later** installed.
Just like Windows, it is very lightweight, so you shouldn't have to worry about hardware restrictions.

# GUI (Electron)

A cross-platform desktop UI lives in the `electron/` folder.

## Run from source

```bash
cd electron
npm install
npm start
```

## Build release zips (Windows x64)

From the repo root (requires [Node.js](https://nodejs.org)):

```powershell
.\build-release.ps1
```

This writes:

- `release/appunblocker-v4.0-x86_64-cli.zip` — `appunblocker.ps1`, `LICENSE`, `README.md`
- `release/appunblocker-v4.0-x86_64-gui.zip` — packaged Electron app (run `appUnblocker.exe` inside the zip after extracting)

Optional parameters: `-Version v4.0`, `-Arch x86_64`, `-OutputDir release`.

GUI-only or manual build:

```powershell
cd electron
npm install
npm run dist
```

Built artifacts are written to `electron/dist/`. Run the Windows build on Windows for the `RunAsInvoker` launch path.

On macOS, use the **method** menu next to **Start** to pick **Folder Manipulation**, **Gatekeeper Bypass**, or **Both** (same options as the PowerShell CLI), then run.

From the menu bar, **appUnblocker → Launch CLI** (⌘⇧L) opens Terminal and runs `appunblocker.ps1`.

## CLI (PowerShell)

One script replaces the old `appunblocker.ps1` + `exploit.bat` pair. Works on **Windows** (PowerShell 5.1+) and **macOS** (PowerShell 7+).

```powershell
# Windows — RunAsInvoker launch
.\appunblocker.ps1 -Path "C:\Path\To\app.exe"

# macOS — folder manipulation (same as GUI / packageSpoofer)
.\appunblocker.ps1 -Path "/Applications/MyApp.app"

# macOS — Gatekeeper quarantine removal only
.\appunblocker.ps1 -Path "/Applications/MyApp.app" -MacMethod Gatekeeper

# macOS — both methods, then launch
.\appunblocker.ps1 -Path "/Applications/MyApp.app" -MacMethod Both

# Prompt for path interactively (Windows: empty path opens cmd.exe)
.\appunblocker.ps1
```

| Parameter | Description |
|-----------|-------------|
| `-Path` | `.exe` (Windows) or `.app` (macOS) |
| `-MacMethod` | `Folder` (default), `Gatekeeper`, or `Both` |
| `-NoLaunch` | Patch only, do not open the app |
| `-NoConfirm` | Skip the pre-run confirmation pause |
| `-SkipBanner` | Skip ASCII banner |

On Windows, `exploit.bat` still works and forwards to `appunblocker.ps1`.