@echo off
rem Exports the PUBLIC key (SPKI DER, base64, one line) from an existing n3di-config-sign.pem.
rem Safe to run repeatedly: the public half is what gets published. It asks for your passphrase once.
setlocal
if "%N3DI_KEYDIR%"=="" (
  echo Set N3DI_KEYDIR to the folder holding n3di-config-sign.pem, e.g.  set N3DI_KEYDIR=C:\Users\%USERNAME%\n3-keys
  exit /b 2
)
set "PEM=%N3DI_KEYDIR%\n3di-config-sign.pem"
if not exist "%PEM%" (echo private key not found: %PEM% & exit /b 3)
set "OPENSSL=D:\Program Files\Git\mingw64\bin\openssl.exe"
if not exist "%OPENSSL%" set "OPENSSL=D:\Program Files\Git\usr\bin\openssl.exe"
set "OUT=%~dp0n3di.pub.spki.b64"

rem Never pipe: with `a | b` the errorlevel only shows b, so a failed decrypt used to leave a
rem zero-byte "public key" file behind and still print success. Each step is checked on its own.
"%OPENSSL%" pkey -in "%PEM%" -pubout -outform DER -out "%~dp0spki.tmp.der"
if errorlevel 1 (
  echo export failed - wrong passphrase or unreadable key. Nothing was written.
  if exist "%~dp0spki.tmp.der" del /q "%~dp0spki.tmp.der"
  exit /b 4
)
for %%F in ("%~dp0spki.tmp.der") do if not "%%~zF"=="294" (
  echo unexpected DER size: %%~zF bytes ^(expected 294 for RSA-2048 SPKI^). Refusing to publish it.
  del /q "%~dp0spki.tmp.der"
  exit /b 5
)
"%OPENSSL%" base64 -A -in "%~dp0spki.tmp.der" -out "%OUT%"
if errorlevel 1 (echo base64 step failed & del /q "%~dp0spki.tmp.der" & exit /b 6)
del /q "%~dp0spki.tmp.der"
for %%F in ("%OUT%") do if not "%%~zF"=="392" (
  echo unexpected base64 size: %%~zF bytes ^(expected 392^). Check the file.
  exit /b 7
)
echo public key written: %OUT% (392 bytes, one line, no padding)
echo It is safe to publish. Paste its content into kEmbeddedSpkiDer in the installer source and rebuild.
endlocal
