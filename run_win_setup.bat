:: Call the script from this bat file so that we can override the script execution policy which doesn't allow you to run ps1 scripts by default.
:: This can be turned off, but it's likely on if you're running this on a new system.
@echo off
powershell.exe -ExecutionPolicy Bypass -File win_setup.ps1