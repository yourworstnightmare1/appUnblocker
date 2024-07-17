: This is the script for appUnblocker which unblocks the application. This cannot be run properly without its prerequisite appunblocker-main.ps1.
: This is a development build / raw compilation of this file. The final application is an executable and not a batch file.
@echo off
title script.bat - appUnblocker for Windows by yourworstnightmare1
color 4
cls

echo          ==============================          
echo       ====================================       
echo      ======================================      
echo     ========================================     
echo    ===================-::-===================    
echo    ================:....... :================    
echo    =============:...:======:...:=============    
echo    ===========.  .============.  .-==========    
echo    =========- .-================-. :=========    
echo    =========- .-================-. :=========    
echo    ==========-.. :============:...-==========    
echo    ============-.  .:======-.. .-============    
echo    +=========-.. :-: ........-: ..-=========+    
echo    +++++++++: .-+++++=:..:-+++++-. -+++++++++    
echo    +++++++++: .-=++++++++++++++=-. -+++++++++    
echo    ++++++++++=...:=++++++++++=.. .=++++++++++    
echo    ++++++++++++=:. .-=++++=:...:=++++++++++++    
echo    +++++++++++++++=: ...... :=+++++++++++++++    
echo    ++++++++++++++++++=-::-=++++++++++++++++++    
echo     ++++++++++++++++++++++++++++++++++++++++     
echo      ++++++++++++++++++++++++++++++++++++++      
echo       ++++++++++++++++++++++++++++++++++++       
echo          ++++++++++++++++++++++++++++++
echo ______________________________________________
echo Before we begin, we need to know some things in order to continue.
echo:
echo Please type in the directory of your application, or simply drag it in. If the directory has spaces, add a quotation to the beginning and end of the directory (example: "C:\Users\joe\Downloads\Visual Studio Setup.exe").
set /p application=
cls

echo Application: %application%
echo [%time% ^| INFO] Running compatability layer script...
set __COMPAT_LAYER=RunAsInvoker
start %application%
if errorlevel ==1 (
    color 4
    cls
    echo     ####*                        *####    
    echo   +#######-                    =#######+  
    echo  ###########.                .###########.
    echo   ############              ############  
    echo     ############          ############    
    echo      .############      ############      
    echo        =###########*  *###########-       
    echo          ########################         
    echo            ####################           
    echo              ################             
    echo               -############:              
    echo              ################             
    echo            ####################           
    echo          =######################=         
    echo        .############  ############.       
    echo       ############      ############      
    echo     ############          ############    
    echo   ############.            .############  
    echo  ###########=                =###########.
    echo   ########+                    *########  
    echo     #####                        #####
    echo A critical error has occurred.
    echo ______________________________
    echo Failed to execute application with path %application% as invoker using compatability layer script. The file may be missing or corrupt.
    echo Consider reinstalling your application.
    echo Press any key to exit appUnblocker.
    pause > nul:
    exit
)
echo [%time% ^| SUCCESS] Executed application successfully!
echo Exiting in 10 seconds, press any key to close this window...
timeout /t 10 > nul:
exit