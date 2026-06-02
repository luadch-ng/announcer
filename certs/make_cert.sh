#!/bin/sh
# #31: variable was named UID, which collides with the bash readonly
# builtin holding the current user's numeric UID. On bash the
# assignment either fails with "UID: readonly variable" or silently
# no-ops, producing a cert with an empty CN. Renamed to CERT_CN.
CERT_CN=$(openssl rand -hex 16)
openssl ecparam -out cakey.pem -name prime256v1 -genkey
openssl req -new -x509 -days 3650 -key cakey.pem -out cacert.pem -subj /CN="$CERT_CN"
openssl ecparam -out serverkey.pem -name prime256v1 -genkey
openssl req -new -key serverkey.pem -out servercert.pem -subj /CN="$CERT_CN"
openssl x509 -req -days 3650 -in servercert.pem -CA cacert.pem -CAkey cakey.pem -set_serial 01 -out servercert.pem
