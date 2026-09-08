#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -f .env ]; then
  echo '.env ya existe; se conserva.'
  exit 0
fi
umask 077
password=$(openssl rand -hex 12)
database_password=$(openssl rand -hex 24)
secret=$(openssl rand -hex 64)
sed -e "s/replace-with-at-least-12-characters/$password/" -e "s/replace-with-random-value/$database_password/" -e "s/replace-with-random-128-hex-characters/$secret/" .env.example > .env
echo '.env creado con credenciales aleatorias. Consultá ADMIN_EMAIL y ADMIN_PASSWORD allí.'
