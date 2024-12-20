$iconappUnblocker = "
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
         ++++++++++++++++++++++++++++++"

Write-Host "$iconappUnblocker"
Write-Host "Initalizing..."

Write-Host "Forcing window to maximize..."
# Automatically maximizes the window
# Add the necessary Windows API function
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinAPI
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int SW_MAXIMIZE = 3;
}
"@

# Get the handle for the current PowerShell window
$hWnd = [WinAPI]::GetForegroundWindow()

# Maximize the window
[WinAPI]::ShowWindow($hWnd, [WinAPI]::SW_MAXIMIZE)

$version = "v3.0w"
$build = "4"

Clear-Host
Write-Host "$iconappUnblocker" -ForegroundColor Red
Write-Host "`nWelcome to appUnblocker!" -ForegroundColor Red
Write-Host "(c) 2024 yourworstnightmare1"
Write-Host "`nVersion: $version | Build: $build" -ForegroundColor Yellow
Pause
Clear-Host
Write-Host "Changing directory..."
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)
Start-Process ".\exploit.bat"
