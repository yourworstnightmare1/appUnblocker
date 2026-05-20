#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path,

    [ValidateSet('Folder', 'Gatekeeper', 'Both')]
    [string]$MacMethod = 'Folder',

    [switch]$NoLaunch,
    [switch]$NoConfirm,
    [switch]$SkipBanner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:Version = 'v4.0'
$Script:Build = '1'
$Script:OnWindows = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $env:OS -eq 'Windows_NT' }
$Script:OnMacOS = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsMacOS } else { $false }
if (-not $Script:OnWindows -and -not $Script:OnMacOS) {
    $uname = Get-Command uname -ErrorAction SilentlyContinue
    if ($uname) { $Script:OnMacOS = (& uname) -eq 'Darwin' }
}

function Write-Banner {
    if ($SkipBanner) { return }
    $icon = @"
          ==============================          
       ====================================       
      ======================================      
     ========================================     
    ===================-::-===================    
    ================:....... :================    
    =============:...:======:...:=============    
    ===========.  .============.  .-==========    
    =========- .-================-. :=========    
    =========- .-================-. :=========    
    ==========-.. :============:...-==========    
    ============-.  .:======-.. .-============    
    +=========-.. :-: ........-: ..-=========+    
    +++++++++: .-+++++=:..:-+++++-. -+++++++++    
    +++++++++: .-=++++++++++++++=-. -+++++++++    
    ++++++++++=...:=++++++++++=.. .=++++++++++    
    ++++++++++++=:. .-=++++=:...:=++++++++++++    
    +++++++++++++++=: ...... :=+++++++++++++++    
    ++++++++++++++++++=-::-=++++++++++++++++++    
     ++++++++++++++++++++++++++++++++++++++++     
      ++++++++++++++++++++++++++++++++++++++      
       ++++++++++++++++++++++++++++++++++++       
         ++++++++++++++++++++++++++++++
"@
    Write-Host $icon -ForegroundColor Red
    Write-Host ""
    Write-Host "Welcome to appUnblocker!" -ForegroundColor Red
    Write-Host "(c) 2024 yourworstnightmare1"
    Write-Host "Version: $Script:Version | Build: $Script:Build" -ForegroundColor Yellow
    Write-Host ""
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warn', 'Error', 'Cmd')]
        [string]$Level = 'Info'
    )
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warn'    { 'Yellow' }
        'Error'   { 'Red' }
        'Cmd'     { 'Cyan' }
        default   { 'White' }
    }
    Write-Host $Message -ForegroundColor $color
}

function Write-SectionHeader {
    Write-Log "///////////////////////////////////" -Level Info
    Write-Log "////// appUnblocker loader //////" -Level Info
    Write-Log "///////////////////////////////////" -Level Info
}

function Read-TargetPath {
    if ($Path) {
        return $Path.Trim().Trim('"').Trim("'")
    }

    if ($Script:OnWindows) {
        Write-Host ""
        Write-Host "Drag and drop your file here, or type the full path."
        Write-Host 'If the path has spaces, wrap it in quotes (e.g. "C:\Apps\My Game.exe").'
        Write-Host "Leave empty and press Enter to open a new Command Prompt instead."
        Write-Host ""
        $inputPath = Read-Host "Enter Directory"
        return $inputPath.Trim().Trim('"').Trim("'")
    }

    Write-Host ""
    Write-Host "Enter the path to a .app bundle (drag-and-drop or paste)."
    Write-Host ""
    return (Read-Host "Enter .app path").Trim().Trim('"').Trim("'")
}

function Confirm-Run {
    param([string]$TargetPath)

    if ($NoConfirm) { return }

    Write-Host ""
    Write-Log "Directory: $TargetPath" -Level Info
    Write-Host ""
    Write-Host "This is the path that will be used."
    if ($Script:OnMacOS) {
        Write-Host "macOS method: $MacMethod"
    }
    Write-Host ""
    $null = Read-Host "Press Enter to begin"
    Clear-Host
    Write-SectionHeader
}

# --- Windows ---

function Start-WindowsUnblock {
    param([string]$TargetPath)

    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        Write-Log "No path given — starting Command Prompt." -Level Warn
        Start-Process cmd.exe
        return
    }

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "File not found: $TargetPath"
    }

    Write-Log "Starting actions..." -Level Info
    Write-Log "App directory: $TargetPath" -Level Info
    Write-Log "Preparing..." -Level Info
    Write-Log "Got application: $TargetPath" -Level Info
    Write-Log "Setting compatibility layer and opening app..." -Level Cmd
    Write-Log "set __COMPAT_LAYER=RunAsInvoker" -Level Cmd

    $env:__COMPAT_LAYER = 'RunAsInvoker'
    try {
        Start-Process -FilePath $TargetPath
        Write-Log "PASS: Application launched." -Level Success
    }
    finally {
        Remove-Item Env:__COMPAT_LAYER -ErrorAction SilentlyContinue
    }

    Write-Log "Cleaning up..." -Level Info
    Write-Log "Successfully finished running appUnblocker." -Level Success
}

# --- macOS helpers ---

function Normalize-MacAppPath {
    param([string]$AppPath)

    $resolved = [System.IO.Path]::GetFullPath($AppPath)
    $base = [System.IO.Path]::GetFileName($resolved)
    $parent = [System.IO.Path]::GetDirectoryName($resolved)
    $plist = Join-Path $resolved 'Contents/Info.plist'

    if (([System.IO.Path]::GetFileName($parent) -eq $base) -and (Test-Path -LiteralPath $plist)) {
        return $parent
    }
    return $resolved
}

function Get-PatchMacAppPath {
    param([string]$AppPath)

    $resolved = [System.IO.Path]::GetFullPath($AppPath)
    $appName = [System.IO.Path]::GetFileName($resolved)
    $nested = Join-Path $resolved $appName
    $nestedPlist = Join-Path $nested 'Contents/Info.plist'

    if (Test-Path -LiteralPath $nestedPlist) { return $nested }
    return $resolved
}

function Test-MacAppWrapped {
    param([string]$AppPath)
    return (Get-PatchMacAppPath -AppPath $AppPath) -ne ([System.IO.Path]::GetFullPath($AppPath))
}

function Get-PlistString {
    param([string]$PlistPath, [string]$Key)

    try {
        $value = & /usr/libexec/PlistBuddy -c "Print :$Key" $PlistPath 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        $trimmed = "$value".Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }
        return $trimmed
    }
    catch {
        return $null
    }
}

function Get-MacLaunchShortcutName {
    param([string]$NestedAppPath)

    $plist = Join-Path $NestedAppPath 'Contents/Info.plist'
    $fallback = [System.IO.Path]::GetFileNameWithoutExtension($NestedAppPath)
    $display = Get-PlistString -PlistPath $plist -Key 'CFBundleDisplayName'
    if (-not $display) { $display = Get-PlistString -PlistPath $plist -Key 'CFBundleName' }
    if (-not $display) { $display = $fallback }
    return "Launch $display.app"
}

function Test-MacReadOnlyVolume {
    param([string]$TargetPath)

    $df = & df $TargetPath 2>$null
    if (-not $df -or $df.Count -lt 2) { return $false }

    $volumePath = ($df[1] -split '\s+')[-1]
    $mount = & mount 2>$null
    $line = $mount | Where-Object { $_ -match " on $([regex]::Escape($volumePath)) " }
    return ($line -match 'read-only')
}

function Test-MacWritableBundle {
    param([string]$SelectionPath)

    $patchApp = Get-PatchMacAppPath -AppPath $SelectionPath
    $contents = Join-Path $patchApp 'Contents'

    Write-Log "Checking app bundle..." -Level Info

    if (-not (Test-Path -LiteralPath $patchApp -PathType Container)) {
        throw "The selected .app bundle could not be found."
    }
    if (-not (Test-Path -LiteralPath $contents)) {
        throw "The selected path is not a valid .app bundle."
    }
    if (-not $patchApp.EndsWith('.app', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Select a .app bundle."
    }

    Write-Log "Resolved app: $SelectionPath" -Level Info
    if (Test-MacAppWrapped -AppPath $SelectionPath) {
        Write-Log "Detected appUnblocker wrapper. Nested app: $patchApp" -Level Warn
    }

    if (Test-MacReadOnlyVolume -TargetPath $contents) {
        Write-Log "FAIL: App is on a read-only volume." -Level Error
        throw "This is a read-only volume. Move the app off the disk image to Downloads (or similar), then try again."
    }

    $testFile = Join-Path $contents '.appunblocker_write_test'
    try {
        [System.IO.File]::WriteAllText($testFile, '')
        Remove-Item -LiteralPath $testFile -Force
        Write-Log "PASS: App location is writable." -Level Success
    }
    catch {
        Write-Log "FAIL: The app is not writable at $SelectionPath" -Level Error
        throw "The app is not writable. Copy it to ~/Downloads and try again."
    }

    return $patchApp
}

function Invoke-MacGatekeeperBypass {
    param([string]$AppBundlePath)

    Write-Log "[Gatekeeper] Removing quarantine extended attribute..." -Level Info
    Write-Log "xattr -rd com.apple.quarantine `"$AppBundlePath`"" -Level Cmd

    & xattr -rd com.apple.quarantine $AppBundlePath 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "WARN: xattr returned exit code $LASTEXITCODE (attribute may already be absent)." -Level Warn
    }
    else {
        Write-Log "PASS: Gatekeeper quarantine cleared." -Level Success
    }
}

function New-MacLaunchShortcut {
    param(
        [string]$ParentDir,
        [string]$NestedAppPath
    )

    $shortcutName = Get-MacLaunchShortcutName -NestedAppPath $NestedAppPath
    $shortcutPath = Join-Path $ParentDir $shortcutName

    Write-Log "appUnblocker: Creating launch shortcut at $shortcutPath" -Level Cmd
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }

    New-Item -ItemType SymbolicLink -Path $shortcutPath -Target $NestedAppPath -Force | Out-Null
    Write-Log "PASS: Launch shortcut created at $shortcutPath" -Level Success
    return $shortcutPath
}

function New-MacFolderWrapper {
    param([string]$AppPath)

    $resolved = [System.IO.Path]::GetFullPath($AppPath)
    $parentDir = [System.IO.Path]::GetDirectoryName($resolved)
    $appFileName = [System.IO.Path]::GetFileName($resolved)
    $tempFolder = Join-Path $parentDir "appUnblocker-$([guid]::NewGuid())"
    $tempNested = Join-Path $tempFolder $appFileName

    Write-Log "[Folder Manipulation] Applying appUnblocker wrapper..." -Level Info
    Write-Log "appUnblocker: Creating folder at $tempFolder" -Level Cmd

    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
    try {
        Write-Log "appUnblocker: Moving app into wrapper..." -Level Cmd
        Write-Log "mv $resolved -> $tempNested" -Level Cmd
        Move-Item -LiteralPath $resolved -Destination $tempNested
        Write-Log "appUnblocker: Finalizing wrapper at $resolved" -Level Cmd
        Move-Item -LiteralPath $tempFolder -Destination $resolved
    }
    catch {
        if (Test-Path -LiteralPath $tempFolder) {
            Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to create appUnblocker wrapper: $($_.Exception.Message)"
    }

    $nestedApp = Join-Path $resolved $appFileName
    Write-Log "PASS: Created wrapper at $resolved" -Level Success
    return @{
        WrapperPath  = $resolved
        NestedApp    = $nestedApp
        ParentDir    = $parentDir
    }
}

function Update-MacFolderWrapper {
    param([string]$WrapperPath)

    $nestedApp = Get-PatchMacAppPath -AppPath $WrapperPath
    $parentDir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($WrapperPath))

    Write-Log "[Folder Manipulation] Wrapper already exists; refreshing launch shortcut only." -Level Warn
    return @{
        WrapperPath = [System.IO.Path]::GetFullPath($WrapperPath)
        NestedApp   = $nestedApp
        ParentDir   = $parentDir
    }
}

function Start-MacUnblock {
    param(
        [string]$TargetPath,
        [string]$Method
    )

    if (-not $TargetPath.EndsWith('.app', [StringComparison]::OrdinalIgnoreCase)) {
        throw "On macOS, select a .app bundle."
    }
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "File not found: $TargetPath"
    }

    $selection = Normalize-MacAppPath -AppPath $TargetPath
    $null = Test-MacWritableBundle -SelectionPath $selection

    $patchApp = Get-PatchMacAppPath -AppPath $selection
    $launchTarget = $selection
    $shortcutPath = $null

    if ($Method -eq 'Gatekeeper' -or $Method -eq 'Both') {
        Invoke-MacGatekeeperBypass -AppBundlePath $patchApp
        $launchTarget = $patchApp
    }

    if ($Method -eq 'Folder' -or $Method -eq 'Both') {
        Write-Log "[Post-Patch] Applying appUnblocker (folder manipulation)..." -Level Info

        $wrapperInfo = if (Test-MacAppWrapped -AppPath $selection) {
            Update-MacFolderWrapper -WrapperPath $selection
        }
        else {
            New-MacFolderWrapper -AppPath $selection
        }

        $shortcutPath = New-MacLaunchShortcut -ParentDir $wrapperInfo.ParentDir -NestedAppPath $wrapperInfo.NestedApp
        $launchTarget = $shortcutPath
        $selection = $wrapperInfo.WrapperPath
    }

    if ($NoLaunch) {
        Write-Log "NoLaunch set; skipping open." -Level Warn
        Write-Log "Successfully finished running appUnblocker." -Level Success
        return
    }

    Write-Log "Opening: $launchTarget" -Level Info
    Write-Log "open `"$launchTarget`"" -Level Cmd
    & open $launchTarget
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to open app (exit code $LASTEXITCODE)."
    }
    Write-Log "PASS: Opened application." -Level Success
    Write-Log "Successfully finished running appUnblocker." -Level Success
}

function Select-MacMethod {
    if ($PSBoundParameters.ContainsKey('MacMethod')) {
        return $MacMethod
    }

    Write-Host ""
    Write-Host "macOS unblock method:"
    Write-Host "  1) Folder Manipulation (wrapper + launch shortcut) [default]"
    Write-Host "  2) Gatekeeper Bypass (remove quarantine xattr)"
    Write-Host "  3) Both"
    Write-Host ""
    $choice = Read-Host "Choose 1-3 (Enter = 1)"
    switch ($choice) {
        '2' { return 'Gatekeeper' }
        '3' { return 'Both' }
        default { return 'Folder' }
    }
}

# --- Main ---

try {
    if (-not $Script:OnWindows -and -not $Script:OnMacOS) {
        throw "Unsupported platform. Use Windows or macOS with PowerShell."
    }

    if ($Script:OnWindows -and $env:TERM -eq $null -and -not $SkipBanner) {
        try {
            Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_MAXIMIZE = 3;
}
"@
            $hWnd = [WinAPI]::GetForegroundWindow()
            [void][WinAPI]::ShowWindow($hWnd, [WinAPI]::SW_MAXIMIZE)
        }
        catch {
            # Non-interactive or no console — ignore
        }
    }

    Write-Banner

    if ($Script:OnMacOS -and -not $PSBoundParameters.ContainsKey('MacMethod') -and -not $Path) {
        $MacMethod = Select-MacMethod
    }

    $target = Read-TargetPath
    Confirm-Run -TargetPath $target

    if ($Script:OnWindows) {
        Start-WindowsUnblock -TargetPath $target
    }
    else {
        Write-Log "Starting actions..." -Level Info
        Write-Log "App directory: $target" -Level Info
        Start-MacUnblock -TargetPath $target -Method $MacMethod
    }
}
catch {
    Write-Log "Failed: $($_.Exception.Message)" -Level Error
    exit 1
}

if (-not $NoConfirm) {
    Write-Host ""
    $null = Read-Host "Press Enter to exit"
}
