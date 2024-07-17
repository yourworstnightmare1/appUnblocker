# appUnblocker created by yourworstnightmare1
# GitHub: https://github.com/yourworstnightmare1/appunblocker

Write-Host "Loading..." -ForegroundColor Yellow
Write-Host "Setting variables..."

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
          ++++++++++++++++++++++++++++++                                                  
"

$iconError = "
     ####*                        *####    
   +#######-                    =#######+  
  ###########.                .###########.
   ############              ############  
     ############          ############    
      .############      ############      
        =###########*  *###########-       
          ########################         
            ####################           
              ################             
               -############:              
              ################             
            ####################           
          =######################=         
        .############  ############.       
       ############      ############      
     ############          ############    
   ############.            .############  
  ###########=                =###########.
   ########+                    *########  
     #####                        #####
"

Write-Host "Getting version info..."

# appUnblocker Info
$appname = "appUnblocker"
Write-Host "Application name: $appname"
$version = "v3.0w"
Write-Host "Application version: $version"
$build = "2"
Write-Host "Build: $build"
$shell = "powershell (ps)"
Write-Host "Shell: $shell"

Write-Host "Completed loading. Beam me up, console!" -ForegroundColor green
Clear-Host

Write-Host "$iconappUnblocker" -ForegroundColor Red
Write-Host "Welcome to appUnblocker!" -ForegroundColor Red
Write-Host "Version: $version | Build: $build" -ForegroundColor Yellow
Write-Host "Created & Programmed by yourworstnightmare1"
Write-Host "___________________________________________"
Write-Host "Press any key to continue with the exploit..."
Write-Host "`n"
Pause
Clear-Host
Write-Host "[SUCCESS] Started appUnblocker" -ForegroundColor Green
Write-Host "[INFO] Changing directory of PowerShell terminal to current terminal's directory..."
Set-Location .
$CurrentLocation = Get-Location
Write-Host "[SUCCESS] Successfully changed directory of PowerShell terminal to $CurrentLocation" -ForegroundColor Green
Write-Host "[INFO] Changing directory of PowerShell terminal to $CurrentLocation\scripts..."
Set-Location scripts
$CurrentLocation = Get-Location
Write-Host "[SUCCESS] Successfully changed directory of PowerShell terminal to $CurrentLocation" -ForegroundColor Green
Write-Host "[INFO] Starting new process "script.exe" inside $CurrentLocation\script.bat..."
Start-Process "script.exe"
Write-Host "[SUCCESS] Successfully started new process "script.exe" with Command Prompt" -ForegroundColor Green
Write-Host "[INFO] Exiting current PowerShell session..." -ForegroundColor Red
Exit-PSSession