@echo off
rem Update this repo from GitHub, copy Leproc into the WoW: Forever client, and pack
rem Leproc-<version>.zip on the desktop.
rem Run it from a terminal (from any folder), then restart the client, or /reload if Leproc was
rem already loaded. It only pulls what's on GitHub: push your commits first.
setlocal

rem git pull can update this very file, and cmd reads a running script from disk line by line, so
rem the script runs from a temporary copy. The original folder is passed along as the second argument.
if not "%~1"=="--copy" (
  copy /y "%~f0" "%TEMP%\leproc_install.cmd" >nul
  call "%TEMP%\leproc_install.cmd" --copy "%~dp0"
  exit /b
)

rem The repo is the folder above this script's tools folder, so it keeps working if the repo is
rem renamed or moved.
for %%i in ("%~2..") do set "REPO=%%~fi"
rem Change WOW if your client lives elsewhere (for example the _classic_beta_ folder).
rem Inside ( ) blocks, always quote paths: the ) in "Program Files (x86)" would end the block.
set "WOW=C:\Program Files (x86)\World of Warcraft\_forever_"
set "ADDON=%WOW%\Interface\AddOns\Leproc"

if not exist "%REPO%\Leproc\Leproc.toc" (
  echo Can't find the addon in "%REPO%\Leproc". Is this script in the repo's tools folder?
  set "RESULT=1"
  goto done
)
if not exist "%WOW%\" (
  echo Can't find the WoW client at "%WOW%". Fix WOW at the top of this script.
  set "RESULT=1"
  goto done
)

git -C "%REPO%" pull --ff-only
if errorlevel 1 (
  echo git pull failed, so nothing was copied.
  set "RESULT=1"
  goto done
)

rem First install: create the addon folder (and Interface\AddOns if the client has none yet).
if not exist "%ADDON%\" (
  echo Creating "%ADDON%"
  mkdir "%ADDON%"
  if errorlevel 1 (
    echo Couldn't create the folder. Is the WoW folder writable? Try running this as administrator.
    set "RESULT=1"
    goto done
  )
)

rem WoW reads the addon's file list (the .toc) only when the game starts. If it changed, /reload
rem isn't enough: the game must be restarted.
set "RESTART=1"
if exist "%ADDON%\Leproc.toc" (
  fc /b "%REPO%\Leproc\Leproc.toc" "%ADDON%\Leproc.toc" >nul && set "RESTART=0"
)

rem /MIR makes the installed folder an exact copy (files no longer in the repo are deleted).
robocopy "%REPO%\Leproc" "%ADDON%" /MIR /IS /IT
rem robocopy exit codes below 8 mean success.
if errorlevel 8 (
  echo Copy failed. Is the WoW folder writable, and the path above right?
  set "RESULT=1"
  goto done
)

rem Stamp the installed copy with the commit, so /leproc shows which build is running.
rem "-dirty" means the copy includes changes that aren't committed.
for /f %%h in ('git -C "%REPO%" rev-parse --short HEAD') do set "BUILD=%%h"
for /f %%s in ('git -C "%REPO%" status --porcelain -- Leproc') do set "BUILD=%BUILD%-dirty"
> "%ADDON%\Build.lua" (
  echo local _, ns = ...
  echo ns.build = "%BUILD%"
)
echo Installed Leproc build %BUILD% into "%ADDON%"

rem Also pack the committed addon as Leproc-<version>.zip on the desktop, ready to share
rem or upload. git archive takes only committed files (without the build stamp above),
rem under a Leproc folder. The version is ## Version in the .toc. The desktop comes from
rem Windows, since OneDrive can move it.
set "VERSION="
for /f "tokens=3" %%v in ('findstr /b /c:"## Version:" "%REPO%\Leproc\Leproc.toc"') do set "VERSION=%%v"
set "DESKTOP=%USERPROFILE%\Desktop"
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%d"
if "%VERSION%"=="" (
  echo No ## Version in the .toc, so no zip was made.
) else (
  git -C "%REPO%" archive --format=zip --output="%DESKTOP%\Leproc-%VERSION%.zip" HEAD Leproc
  if errorlevel 1 (
    echo Couldn't write "%DESKTOP%\Leproc-%VERSION%.zip".
  ) else (
    echo Packed "%DESKTOP%\Leproc-%VERSION%.zip" from the last commit.
  )
)
if "%RESTART%"=="1" (
  echo The addon's file list changed: fully restart the game, /reload won't load new files.
  echo Then /leproc should say build %BUILD%.
) else (
  echo In game: /reload, then /leproc should say build %BUILD%.
)
set "RESULT=0"

:done
exit /b %RESULT%
