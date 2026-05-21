#Requires -Version 5.1
<#
.SYNOPSIS
  Build CLI and GUI release zips for Windows and macOS.

.EXAMPLE
  .\build-release.ps1
  .\build-release.ps1 -Version v4.0
  .\build-release.ps1 -SkipWindows
  .\build-release.ps1 -SkipMac
#>
[CmdletBinding()]
param(
    [string]$Version = 'v4.0',
    [string]$OutputDir = 'release',
    [switch]$SkipWindows,
    [switch]$SkipMac
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$ElectronDir = Join-Path $Root 'electron'
$ReleaseDir = Join-Path $Root $OutputDir

$Script:OnMacOS = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsMacOS } else { $false }
if (-not $Script:OnMacOS) {
    $uname = Get-Command uname -ErrorAction SilentlyContinue
    if ($uname) { $Script:OnMacOS = (& uname) -eq 'Darwin' }
}

$Script:BuiltArtifacts = [System.Collections.Generic.List[string]]::new()

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-TempRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:TEMP)) { return $env:TEMP.TrimEnd('/', '\') }
    if (-not [string]::IsNullOrWhiteSpace($env:TMPDIR)) { return $env:TMPDIR.TrimEnd('/', '\') }
    return [System.IO.Path]::GetTempPath().TrimEnd('/', '\')
}

function New-EmptyDirectory([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Directory path is null or empty.'
    }
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-MacBuildArch {
    $machine = (& uname -m).Trim()
    if ($machine -eq 'arm64') { return 'arm64' }
    return 'x86_64'
}

function Stop-BlockingAppProcesses {
    param([string]$ElectronRoot)

    $resolvedRoot = (Resolve-Path -LiteralPath $ElectronRoot).Path
    $processNames = @('appUnblocker', 'electron')

    foreach ($name in $processNames) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            $procPath = $_.Path
            $shouldStop = $name -eq 'appUnblocker'
            if (-not $shouldStop -and $procPath) {
                $shouldStop = $procPath -like "*$resolvedRoot*"
            }

            if ($shouldStop) {
                Write-Host "Stopping $($_.ProcessName) (PID $($_.Id))..."
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Start-Sleep -Milliseconds 500
}

function Get-ElectronBuildOutputDir {
    param([string]$Label)
    Join-Path $ElectronDir ("dist-build-{0}-{1}" -f $Label, (Get-Date -Format 'yyyyMMddHHmmss'))
}

function Invoke-ElectronBuilder {
    param(
        [string]$Label,
        [string[]]$BuilderArgs
    )

    Ensure-Command 'npm'
    Stop-BlockingAppProcesses -ElectronRoot $ElectronDir

    $buildOutputDir = Get-ElectronBuildOutputDir -Label $Label
    $buildOutputName = Split-Path -Leaf $buildOutputDir

    Push-Location $ElectronDir
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $ElectronDir 'node_modules'))) {
            Write-Host "Running npm install..."
            & npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
        }

        $args = @(
            'electron-builder',
            "--config.directories.output=$buildOutputName"
        ) + $BuilderArgs

        Write-Host "Running npx $($args -join ' ')..."
        & npx @args 2>&1 | ForEach-Object { Write-Host $_.ToString() }
        if ($LASTEXITCODE -ne 0) { throw "electron-builder failed (exit $LASTEXITCODE)" }
    }
    finally {
        Pop-Location
    }

    return ,$buildOutputDir
}

function Publish-GuiZip {
    param(
        [string]$DistDir,
        [string]$DestZipPath,
        [string]$ZipFilter = '*.zip'
    )

    $builtZip = Get-ChildItem -Path $DistDir -Filter $ZipFilter -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $builtZip) {
        throw "No zip matching '$ZipFilter' found in $DistDir"
    }

    if (Test-Path -LiteralPath $DestZipPath) {
        Remove-Item -LiteralPath $DestZipPath -Force
    }
    Copy-Item -LiteralPath $builtZip.FullName -Destination $DestZipPath -Force
    Write-Host "Created $DestZipPath (from $($builtZip.Name))" -ForegroundColor Green
    $Script:BuiltArtifacts.Add($DestZipPath) | Out-Null
}

function Build-CliZip {
    $cliZipName = "appunblocker-$Version-cli.zip"
    $cliZipPath = Join-Path $ReleaseDir $cliZipName

    Write-Step "Packaging CLI ($cliZipName)"

    $stage = Join-Path (Get-TempRoot) "appunblocker-cli-stage-$([guid]::NewGuid())"
    New-EmptyDirectory $stage

    try {
        $cliFiles = @(
            (Join-Path $Root 'appunblocker.ps1'),
            (Join-Path $Root 'LICENSE'),
            (Join-Path $Root 'README.md')
        )
        foreach ($file in $cliFiles) {
            if (-not (Test-Path -LiteralPath $file)) {
                throw "Missing required file: $file"
            }
            Copy-Item -LiteralPath $file -Destination $stage
        }

        $archiveItems = @(Get-ChildItem -LiteralPath $stage -Force)
        if ($archiveItems.Count -eq 0) {
            throw "CLI stage folder is empty: $stage"
        }
        Compress-Archive -Path ($archiveItems | ForEach-Object { $_.FullName }) -DestinationPath $cliZipPath -CompressionLevel Optimal -Force
        Write-Host "Created $cliZipPath" -ForegroundColor Green
        $Script:BuiltArtifacts.Add($cliZipPath) | Out-Null
    }
    finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Build-WindowsGuiZip {
    $guiZipName = "appunblocker-$Version-win-x86_64-gui.zip"
    $guiZipPath = Join-Path $ReleaseDir $guiZipName

    Write-Step "Building GUI (Windows x64) -> $guiZipName"
    $distDir = Invoke-ElectronBuilder -Label 'win' -BuilderArgs @('--win', 'zip', '--x64')
    Publish-GuiZip -DistDir $distDir -DestZipPath $guiZipPath
}

function Build-MacGuiZip {
    $macArch = Get-MacBuildArch
    $electronArchFlag = if ($macArch -eq 'arm64') { '--arm64' } else { '--x64' }
    $guiZipName = "appunblocker-$Version-macos-$macArch-gui.zip"
    $guiZipPath = Join-Path $ReleaseDir $guiZipName

    Write-Step "Building GUI (macOS $macArch) -> $guiZipName"
    $distDir = Invoke-ElectronBuilder -Label "mac-$macArch" -BuilderArgs @('--mac', 'zip', $electronArchFlag)
    Publish-GuiZip -DistDir $distDir -DestZipPath $guiZipPath -ZipFilter '*-mac.zip'
}

Write-Step "appUnblocker release build ($Version)"

if (-not $Script:OnMacOS -and -not $SkipWindows) {
    Write-Host "Note: Windows GUI can be cross-built from macOS. macOS GUI requires building on a Mac." -ForegroundColor Yellow
}

New-EmptyDirectory $ReleaseDir

Build-CliZip

if (-not $SkipWindows) {
    Build-WindowsGuiZip
}
else {
    Write-Host "Skipping Windows GUI (-SkipWindows)." -ForegroundColor Yellow
}

if (-not $SkipMac) {
    if ($Script:OnMacOS) {
        Build-MacGuiZip
    }
    else {
        Write-Host "Skipping macOS GUI (build must run on macOS)." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Skipping macOS GUI (-SkipMac)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Release files:" -ForegroundColor Green
foreach ($artifact in $Script:BuiltArtifacts) {
    Write-Host "  $artifact"
}
