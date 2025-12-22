@echo off

:: By default, this script will assume your Beef installation is stored in AppData, you can supply your own build here if you'd like, though.
set BEEF_DIR=%APPDATA%\..\Local\BeefLang\bin
set WORKSPACE_DIR=%~dp0..\

echo Building ARM
%BEEF_DIR%\BeefBuild -config=Debug -platform=armv7-none-linux-androideabi23 -workspace=%WORKSPACE_DIR%
echo Building ARM64
%BEEF_DIR%\BeefBuild -config=Debug -platform=aarch64-none-linux-android23 -workspace=%WORKSPACE_DIR%
echo Building x86
%BEEF_DIR%\BeefBuild -config=Debug -platform=i686-none-linux-android23 -workspace=%WORKSPACE_DIR%
echo Building x86_64
%BEEF_DIR%\BeefBuild -config=Debug -platform=x86_64-none-linux-android23 -workspace=%WORKSPACE_DIR%

echo All done!
:: pause