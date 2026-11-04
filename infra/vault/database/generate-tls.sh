#!/bin/sh
# Run from the repository root. Keep the CA key offline after issuing certs.
set -eu
umask 077
target=infra/vault/private/database-tls
if [ -e "$target" ]; then
  echo "$target already exists; refusing to replace database trust roots" >&2
  exit 1
fi
mkdir -p "$target"
openssl req -x509 -newkey rsa:3072 -nodes -days 3650 \
  -subj '/CN=Home Server Database CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$target/ca-key.pem" -out "$target/ca.pem"
for service in postgresql mariadb; do
  mkdir "$target/$service"
  openssl req -new -newkey rsa:3072 -nodes -subj "/CN=$service" \
    -keyout "$target/$service/server-key.pem" -out "$target/$service/server.csr"
  cat > "$target/$service/extensions.cnf" <<EOF
subjectAltName=DNS:$service
extendedKeyUsage=serverAuth
keyUsage=critical,digitalSignature,keyEncipherment
basicConstraints=critical,CA:FALSE
EOF
  openssl x509 -req -days 365 -in "$target/$service/server.csr" \
    -CA "$target/ca.pem" -CAkey "$target/ca-key.pem" -CAcreateserial \
    -extfile "$target/$service/extensions.cnf" -out "$target/$service/server.pem"
  openssl verify -CAfile "$target/ca.pem" -verify_hostname "$service" "$target/$service/server.pem"
  chmod 755 "$target/$service"
  chmod 644 "$target/$service/server.pem"
done
chmod 755 "$target"
chmod 644 "$target/ca.pem"
