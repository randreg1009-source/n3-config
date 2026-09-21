@echo off
rem Independent check with openssl (no rebuild needed): does n3-packages.json.sig match the published
rem public key? The installer itself verifies the same pair through CAPI.
setlocal
set "CFG=%~dp0n3-packages.json"
set "PUB=%~dp0n3di.pub.spki.b64"
set "OPENSSL=D:\Program Files\Git\mingw64\bin\openssl.exe"
if not exist "%OPENSSL%" set "OPENSSL=D:\Program Files\Git\usr\bin\openssl.exe"
if not exist "%PUB%" (echo public key file missing: %PUB% & exit /b 1)
if not exist "%CFG%.sig" (echo signature file missing: %CFG%.sig & exit /b 1)
"%OPENSSL%" base64 -d -A -in "%PUB%" -out "%~dp0pub.der"
if errorlevel 1 (echo cannot decode %PUB% & exit /b 1)
powershell -NoProfile -Command "$d=[Convert]::ToBase64String([IO.File]::ReadAllBytes('%~dp0pub.der')); $s='-----BEGIN PUBLIC KEY-----'+[Environment]::NewLine; for($i=0;$i -lt $d.Length;$i+=64){$s+=$d.Substring($i,[Math]::Min(64,$d.Length-$i))+[Environment]::NewLine}; $s+='-----END PUBLIC KEY-----'+[Environment]::NewLine; Set-Content -NoNewline -Encoding ascii '%~dp0pub.pem' $s"
"%OPENSSL%" base64 -d -A -in "%CFG%.sig" -out "%~dp0sig.tmp.der"
if errorlevel 1 (echo cannot decode %CFG%.sig & exit /b 1)
"%OPENSSL%" dgst -sha256 -verify "%~dp0pub.pem" -signature "%~dp0sig.tmp.der" "%CFG%"
set "RC=%errorlevel%"
if exist "%~dp0sig.tmp.der" del /q "%~dp0sig.tmp.der"
if exist "%~dp0pub.der" del /q "%~dp0pub.der"
if exist "%~dp0pub.pem" del /q "%~dp0pub.pem"
if not "%RC%"=="0" (echo signature does not match this config & exit /b 1)
echo signature is valid for this config
endlocal
