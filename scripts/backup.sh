#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
umask 077
stamp=$(date -u +%Y%m%dT%H%M%SZ)
destination="backups/$stamp"
mkdir -p "$destination"
# Pause writes to keep the database dump and attachment files consistent.
docker compose stop app
trap 'docker compose start app >/dev/null' EXIT HUP INT TERM
docker compose exec -T postgres pg_dump -U webnotator -d webnotator -Fc > "$destination/database.dump"
docker compose run --rm --no-deps --entrypoint tar app -czf - -C /app/storage . > "$destination/uploads.tar.gz"
cp .env "$destination/env"
echo "Backup creado: $destination. Contiene credenciales; guardalo fuera del VPS."
