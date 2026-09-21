@echo off
rem Signs n3-packages.json into n3-packages.json.sig (base64 RSA-SHA256 over the exact bytes).
rem Usage:  sign.cmd [newSerial]      - with an argument it bumps the TOP-LEVEL "serial" first, then signs.
rem The private key lives on the USB: set N3DI_KEYDIR to the folder holding n3di-config-sign.pem.
setlocal
if "%N3DI_KEYDIR%"=="" (
  echo Set N3DI_KEYDIR to the folder that holds n3di-config-sign.pem ^(the USB^).
  exit /b 2
)
set "PEM=%N3DI_KEYDIR%\n3di-config-sign.pem"
if not exist "%PEM%" (echo private key not found: %PEM% & exit /b 3)
set "OPENSSL=D:\Program Files\Git\mingw64\bin\openssl.exe"
if not exist "%OPENSSL%" set "OPENSSL=D:\Program Files\Git\usr\bin\openssl.exe"
set "CFG=%~dp0n3-packages.json"
if not exist "%CFG%" (echo config not found: %CFG% & exit /b 4)
if "%~1"=="" goto dosign
rem Only the header region (before "packages") may be touched: a stray "serial" inside a package
rem would be silently ignored by the parser and leave the real anti-rollback field unchanged.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%CFG%'; $t=[IO.File]::ReadAllText($p); $i=$t.IndexOf('\"packages\"'); if($i -lt 0){$i=$t.Length}; $head=$t.Substring(0,$i); $rest=$t.Substring($i); $h=[regex]::Replace($head,'\"serial\"\s*:\s*\d+', ('\"serial\": ' + %1)); if($h -eq $head){ if(-not $h.StartsWith('{')){ 'header does not start with {'; exit 1 }; $h = '{\"serial\": ' + %1 + ',' + $h.Substring(1) }; [IO.File]::WriteAllText($p, ($h + $rest), (New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 (echo serial bump failed & exit /b 5)
:dosign
rem Canonical line endings. git (core.autocrlf) publishes LF and the signature covers exact bytes,
rem so the signed file must be LF too - otherwise a clean checkout stops verifying.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%CFG%'; $t=[IO.File]::ReadAllText($p); $t=$t.Replace([string][char]13 + [char]10, [string][char]10); [IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 (echo line-ending step failed & exit /b 8)
rem exact bytes - so the file we sign must already be LF, or a clean checkout stops verifying.
"%OPENSSL%" dgst -sha256 -sign "%PEM%" -out "%~dp0sig.tmp.der" "%CFG%"
if errorlevel 1 (echo signing failed ^(wrong passphrase?^) & exit /b 6)
"%OPENSSL%" base64 -A -in "%~dp0sig.tmp.der" -out "%CFG%.sig"
if errorlevel 1 (echo base64 encoding failed & exit /b 7)
del /q "%~dp0sig.tmp.der"
echo signed %CFG%
echo wrote %CFG%.sig
echo Publish BOTH files in one commit: a remote config without its .sig is rejected by the installer.
endlocal
