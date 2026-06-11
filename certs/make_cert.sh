#!/bin/sh
# make_cert.sh
#
# Generates a self-signed announcer client cert (servercert.pem) +
# private key (serverkey.pem) using OpenSSL. Run from the certs/
# directory: `cd certs && bash make_cert.sh`.
#
# Pattern: a short-lived self-signed CA signs the server cert. The
# CA private key (cakey.pem) and CA cert (cacert.pem) are removed
# at the end - they are not needed at runtime, and leaving the CA
# private key next to the server key on disk is bad practice.
#
# Issue #31: variable was named UID, which collides with the bash
# readonly builtin holding the current user's numeric UID. On bash
# the assignment either fails with "UID: readonly variable" or
# silently no-ops, producing a cert with an empty CN. Renamed to
# CERT_CN.

set -e

CERT_CN=$(openssl rand -hex 16)
openssl ecparam -out cakey.pem -name prime256v1 -genkey
openssl req -new -x509 -days 3650 -key cakey.pem -out cacert.pem -subj /CN="$CERT_CN"
openssl ecparam -out serverkey.pem -name prime256v1 -genkey
openssl req -new -key serverkey.pem -out servercert.pem -subj /CN="$CERT_CN"
openssl x509 -req -days 3650 -in servercert.pem -CA cacert.pem -CAkey cakey.pem -set_serial 01 -out servercert.pem

# Cleanup: drop the CA private key + CA cert (transient signing
# material, no runtime use). Same cleanup added to make_cert.bat.
rm -f cakey.pem cacert.pem
