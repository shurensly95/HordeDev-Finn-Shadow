@echo off
setlocal

REM Get the directory where the batch file is located
set "batch_dir=%~dp0"

REM Remove trailing backslash if present
if "%batch_dir:~-1%" == "\" set "batch_dir=%batch_dir:~0,-1%"

REM Define the Lua script path
set "lua_script_path=%batch_dir%\enter_horde.lua"

REM Define the old path that needs to be replaced
set "old_path=C:\\Users"

REM Define the new path with double backslashes
set "new_path=%batch_dir:\=\\%"

REM Backup the original Lua script
copy "%lua_script_path%" "%lua_script_path%.bak"

REM Replace the old path with the new path in the Lua script
powershell -Command "(Get-Content '%lua_script_path%.bak') -replace [regex]::Escape('%old_path%'), '%new_path%' | Set-Content '%lua_script_path%'"

REM Clean up the backup
del "%lua_script_path%.bak"

echo Lua script path updated successfully.
endlocal
