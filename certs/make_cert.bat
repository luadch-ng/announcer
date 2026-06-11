@echo off
rem make_cert.bat
rem
rem Generates a self-signed announcer client cert (servercert.pem) +
rem private key (serverkey.pem) using OpenSSL. Run from the certs/
rem directory: `cd certs && make_cert.bat`. OpenSSL must be on PATH.
rem
rem Pattern: a short-lived self-signed CA signs the server cert. The
rem CA private key (cakey.pem) and CA cert (cacert.pem) are removed
rem at the end - they are not needed at runtime, and leaving the CA
rem private key next to the server key on disk is bad practice.

rem Random 32-hex CN. `for /f` reads OpenSSL's stdout directly so we
rem do not leave a uid.txt + tmp.rnd behind even on Ctrl+C.
for /f %%i in ('openssl rand -hex 16') do set CERT_CN=%%i

openssl ecparam -out cakey.pem -name prime256v1 -genkey
openssl req -new -x509 -days 3650 -key cakey.pem -out cacert.pem -subj /CN=%CERT_CN%
openssl ecparam -out serverkey.pem -name prime256v1 -genkey
openssl req -new -key serverkey.pem -out servercert.pem -subj /CN=%CERT_CN%
openssl x509 -req -days 3650 -in servercert.pem -CA cacert.pem -CAkey cakey.pem -set_serial 01 -out servercert.pem

rem Cleanup: drop the CA private key + CA cert (transient signing
rem material, no runtime use). Same cleanup added to make_cert.sh.
del cakey.pem
del cacert.pem
pause
