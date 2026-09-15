@echo off
setlocal
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PSEXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PSEXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Switch-Ebid.ps1" -Mode IC
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
