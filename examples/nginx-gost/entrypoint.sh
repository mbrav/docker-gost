#!/bin/bash
set -euo pipefail

CERT_DIR="/etc/nginx/certs"
CERT_KEY="${CERT_DIR}/server.key"
CERT_CRT="${CERT_DIR}/server.crt"

mkdir -p "$CERT_DIR"

if [[ ! -f "$CERT_CRT" ]]; then
    echo "[i] Generating self-signed GOST 2012 certificate..."

    # Step 1: generate a GOST 2012 private key (256-bit, parameter set A)
    openssl genpkey \
        -algorithm gost2012_256 \
        -pkeyopt paramset:A \
        -out "$CERT_KEY"

    # Step 2: create a certificate signing request
    openssl req -new \
        -key "$CERT_KEY" \
        -out "${CERT_DIR}/server.csr" \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=docker-gost/CN=localhost"

    # Step 3: self-sign the certificate (valid for 365 days)
    openssl x509 -req \
        -days 365 \
        -in "${CERT_DIR}/server.csr" \
        -signkey "$CERT_KEY" \
        -out "$CERT_CRT"

    rm -f "${CERT_DIR}/server.csr"

    echo "[✓] Certificate generated: $CERT_CRT"
else
    echo "[✓] Certificate already exists: $CERT_CRT"
fi

exec nginx -g "daemon off;"
