#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./scripts/setup.sh
docker compose up -d --build --wait
# db:prepare seeds a fresh database; this also ensures seeds exist on later starts.
docker compose exec -T app bundle exec rails db:seed
printf '\nWebnotator listo. La URL y el acceso están en .env.\n'
