@echo off
rem Creates the config signing key pair. Run this ONCE.
rem   set N3DI_KEYDIR=<folder for the private key>
rem   set N3DI_ON_DISK=1        (only needed when that folder is on a fixed disk)
rem The private key is the identity of your release channel: whoever holds it can publish a config
rem that every installer obeys. So: never inside a git working tree, never in a synced folder, and
rem always behind a passphrase (the .pem is written AES-256 encrypted).
setlocal enabledelayedexpansion
if "%N3DI_KEYDIR%"=="" (
  echo Set N3DI_KEYDIR first, e.g.  set N3DI_KEYDIR=C:\Users\%USERNAME%\n3-keys
  echo Then, if it is on a fixed disk rather than removable media, also:  set N3DI_ON_DISK=1
  exit /b 2
)

rem --- refuse anything inside a git working tree (walk up to six levels) ---
set "PROBE=%N3DI_KEYDIR%\."
for /L %%i in (1,1,6) do (
  for %%D in ("!PROBE!") do set "PROBE=%%~dpD"
  if exist "!PROBE!.git" (
    echo Refusing: "!N3DI_KEYDIR!" is inside the git repository at !PROBE!
    echo A private key that lives where you run "git add ." will be committed one day. Pick another folder.
    exit /b 3
  )
)

rem --- refuse a fixed disk unless the operator says so on purpose ---
set "DRIVE="
for %%D in ("%N3DI_KEYDIR%") do set "DRIVE=%%~dD"
if /i not "%N3DI_ON_DISK%"=="1" (
  echo Refusing: %DRIVE% is a fixed disk. If you really want the key on disk, re-run after
  echo   set N3DI_ON_DISK=1
  echo Understand the difference: on the everyday machine the key is readable by anything that runs
  echo as you, so the passphrase and your backup plan are what actually protect it.
  exit /b 4
)

if not exist "%N3DI_KEYDIR%" mkdir "%N3DI_KEYDIR%"
if not exist "%N3DI_KEYDIR%" (echo cannot create %N3DI_KEYDIR% & exit /b 5)
if exist "%N3DI_KEYDIR%\n3di-config-sign.pem" (
  echo Already exists: "%N3DI_KEYDIR%\n3di-config-sign.pem"
  echo Not overwriting - losing that key means every shipped installer must be rebuilt with a new one.
  exit /b 6
)

set "PEM=%N3DI_KEYDIR%\n3di-config-sign.pem"
set "OPENSSL=D:\Program Files\Git\mingw64\bin\openssl.exe"
if not exist "%OPENSSL%" set "OPENSSL=D:\Program Files\Git\usr\bin\openssl.exe"

rem openssl asks for the AES-256 passphrase twice; it is not stored anywhere in this script.
"%OPENSSL%" genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -aes256 -out "%PEM%"
if errorlevel 1 (echo keygen failed & del /q "%PEM%" & exit /b 7)
rem A cancelled passphrase prompt can leave a zero-byte file behind; never export a public key from it.
for %%F in ("%PEM%") do if %%~zF LSS 100 (
  echo The key file came out empty - the passphrase prompt was probably interrupted. Nothing was published.
  del /q "%PEM%"
  exit /b 9
)

icacls "%N3DI_KEYDIR%" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F"
if errorlevel 1 echo WARNING: could not lock down the folder ACL; do it yourself before continuing.
icacls "%PEM%" /inheritance:r /grant:r "%USERNAME%:F"
if errorlevel 1 echo WARNING: could not lock down the key file ACL.

rem Export through pubkey.cmd: a piped export hid the failure and left a 0-byte file behind.
call "%~dp0pubkey.cmd"
if errorlevel 1 (echo public key export failed - re-run pubkey.cmd after fixing the cause & exit /b 8)

echo.
echo Private key : %PEM%   (AES-256 passphrase protected; never commit, never email, never sync)
echo Public key  : %~dp0n3di.pub.spki.b64   (safe to publish; paste it into kEmbeddedSpkiDer and rebuild)
echo.
echo Do now: 1) make one backup copy of the .pem somewhere offline (password manager blob, second disk,
echo         printed QR is overkill) and remember the passphrase separately;
echo         2) keep the folder out of every backup job that uploads to a cloud you do not control.
endlocal
