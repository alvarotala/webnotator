#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
docker compose run --rm -e RAILS_ENV=test -e SEED_DEMO=false app bundle exec rails db:prepare
docker compose run --rm -e RAILS_ENV=test -e SEED_DEMO=false app bundle exec rails test
