@echo off

REM Focus the Diablo IV window
powershell -command "(New-Object -ComObject WScript.Shell).AppActivate('Diablo IV')"

REM Wait for 1 seconds
timeout /t 1 /nobreak

REM Send Enter key press
powershell -command "$wshell = New-Object -ComObject wscript.shell; $wshell.SendKeys('{ENTER}')"

REM Close the command prompt window
exit
