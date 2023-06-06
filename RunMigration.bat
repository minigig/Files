@echo off
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& { Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\temp\Migration.ps1"' -Verb RunAs}"
