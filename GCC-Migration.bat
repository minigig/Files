@echo off
for /f "tokens=2 delims=\" %%A in ('whoami') do set loggedInUser=%%A
if /i "%loggedInUser%"=="IDS" (
    powershell -Command Start-Process "PowerShell -Verb RunAs -ArgumentList '-ExecutionPolicy RemoteSigned -File C:\temp\GCCHIGH.PS1'"
) else (
    echo User not authorized to run this script. Must be logged in as IDS.
    echo Closing in 10 seconds...
    timeout /t 10 /nobreak >nul
)
