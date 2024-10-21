@echo off
setlocal enabledelayedexpansion

:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :admin
) else (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%0' -ArgumentList 'admin'"
    exit /b
)

:admin
:: Set installation paths
set "SIMPLECLOUD_PREFIX=%LOCALAPPDATA%\SimpleCloud"
set "SIMPLECLOUD_REPOSITORY=%SIMPLECLOUD_PREFIX%\bin"
set "GITHUB_REPO=theSimpleCloud/simplecloud-manifest"
set "PLATFORM=cli-windows"

:: Create necessary directories
if not exist "%SIMPLECLOUD_REPOSITORY%" mkdir "%SIMPLECLOUD_REPOSITORY%"

echo This script will install:
echo %SIMPLECLOUD_REPOSITORY%\scl.exe
echo %SIMPLECLOUD_REPOSITORY%\simplecloud.exe

:: Get the latest release URL
call :get_latest_release %GITHUB_REPO%

if "%DOWNLOAD_URL%"=="" (
    echo Failed to get the download URL for the latest release.
    exit /b 1
)

echo Downloading and installing SimpleCloud...
pushd "%SIMPLECLOUD_REPOSITORY%"

:: Download the binary
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%PLATFORM%.exe'"

if not exist "%PLATFORM%.exe" (
    echo Failed to download SimpleCloud.
    exit /b 1
)

copy /y "%PLATFORM%.exe" "scl.exe"
copy /y "%PLATFORM%.exe" "simplecloud.exe"

popd

:: Add to PATH
call :create_powershell_script
powershell -ExecutionPolicy Bypass -File "%TEMP%\AddToPath.ps1" "%SIMPLECLOUD_REPOSITORY%"

echo Installation successful!
echo.
echo SimpleCloud was installed to: %SIMPLECLOUD_REPOSITORY%
echo The installation directory has been added to your PATH.
echo You can now use 'scl' or 'simplecloud' commands.
echo You may need to restart your command prompt or log out and log back in for the PATH changes to take effect.

echo For more information, see: https://simplecloud.app

pause
exit /b 0

:get_latest_release
    for /f "tokens=*" %%i in ('powershell -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/%1/releases/latest').assets | Where-Object { $_.name -like '*%PLATFORM%*' } | Select-Object -ExpandProperty browser_download_url"') do set "DOWNLOAD_URL=%%i"
exit /b 0

:create_powershell_script
    echo $dir = $args[0] > "%TEMP%\AddToPath.ps1"
    echo $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User') >> "%TEMP%\AddToPath.ps1"
    echo if ($userPath -notlike "*$dir*") { >> "%TEMP%\AddToPath.ps1"
    echo     $newPath = $userPath + ";$dir" >> "%TEMP%\AddToPath.ps1"
    echo     [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User') >> "%TEMP%\AddToPath.ps1"
    echo     Write-Host "SimpleCloud directory added to your PATH." >> "%TEMP%\AddToPath.ps1"
    echo } else { >> "%TEMP%\AddToPath.ps1"
    echo     Write-Host "SimpleCloud directory is already in your PATH." >> "%TEMP%\AddToPath.ps1"
    echo } >> "%TEMP%\AddToPath.ps1"
exit /b 0
