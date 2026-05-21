#Requires -Version 5.1
<#
.SYNOPSIS
  Build CLI and GUI release zips for Windows x64.

.EXAMPLE
  .\build-release.ps1
  .\build-release.ps1 -Version v4.0 -Arch x86_64
#>
[CmdletBinding()]
param(
    [string]$Version = 'v4.0',
    [string]$Arch = 'x86_64',
    [string]$OutputDir = 'release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$ElectronDir = Join-Path $Root 'electron'
$ReleaseDir = Join-Path $Root $OutputDir
$CliZipName = "appunblocker-$Version-$Arch-cli.zip"
$GuiZipName = "appunblocker-$Version-$Arch-gui.zip"
$CliZipPath = Join-Path $ReleaseDir $CliZipName
$GuiZipPath = Join-Path $ReleaseDir $GuiZipName

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function New-EmptyDirectory([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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
    # Use a fresh folder so a locked electron\dist from a running app does not fail the build.
    Join-Path $ElectronDir ("dist-build-{0}" -f (Get-Date -Format 'yyyyMMddHHmmss'))
}

function Build-CliZip {
    Write-Step "Packaging CLI ($CliZipName)"

    $stage = Join-Path $env:TEMP "appunblocker-cli-stage-$([guid]::NewGuid())"
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

        if (Test-Path -LiteralPath $CliZipPath) {
            Remove-Item -LiteralPath $CliZipPath -Force
        }
        Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $CliZipPath -CompressionLevel Optimal
        Write-Host "Created $CliZipPath" -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Build-GuiZip {
    Write-Step "Building GUI (Electron, win x64)"

    Ensure-Command 'npm'
    Stop-BlockingAppProcesses -ElectronRoot $ElectronDir

    $buildOutputDir = Get-ElectronBuildOutputDir
    $buildOutputName = Split-Path -Leaf $buildOutputDir

    Push-Location $ElectronDir
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $ElectronDir 'node_modules'))) {
            Write-Host "Running npm install..."
            & npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
        }

        Write-Host "Running electron-builder (output: $buildOutputName)..."
        & npx electron-builder --win --x64 --config.directories.output=$buildOutputName
        if ($LASTEXITCODE -ne 0) { throw "electron-builder failed (exit $LASTEXITCODE)" }
    }
    finally {
        Pop-Location
    }

    $distDir = $buildOutputDir
    $builtZip = Get-ChildItem -Path $distDir -Filter '*.zip' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $builtZip) {
        throw "No .zip found in $distDir. Run the build on Windows with Node.js installed."
    }

    Write-Step "Renaming GUI artifact to $GuiZipName"
    if (Test-Path -LiteralPath $GuiZipPath) {
        Remove-Item -LiteralPath $GuiZipPath -Force
    }
    Copy-Item -LiteralPath $builtZip.FullName -Destination $GuiZipPath -Force
    Write-Host "Created $GuiZipPath (from $($builtZip.Name))" -ForegroundColor Green
}

Write-Step "appUnblocker release build ($Version, $Arch)"
Ensure-Command 'powershell'
New-EmptyDirectory $ReleaseDir

Build-CliZip
Build-GuiZip

Write-Host ""
Write-Host "Done. Release files:" -ForegroundColor Green
Write-Host "  $CliZipPath"
Write-Host "  $GuiZipPath"
