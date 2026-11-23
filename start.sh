#!/bin/bash
# Railway wrapper for LandPPT: prepares the volume, applies safe defaults,
# migrates the database once, seeds the LLM provider from variables, then
# hands over to the upstream entrypoint as the unprivileged landppt user.
set -euo pipefail

APP_UID=10001
DATA=/data

if [ "$(id -u)" = "0" ]; then
  mkdir -p "$DATA"
  for d in data data/artifacts uploads research_reports lib lib/Linux lib/MacOS lib/Windows \
           temp temp/ai_responses_cache temp/style_genes_cache temp/summeryanyfile_cache \
           temp/templates_cache temp/images_cache; do
    mkdir -p "$DATA/$d"
  done
  if [ ! -f "$DATA/.env" ]; then
    printf '# LandPPT runtime settings written by the admin UI (kept on the volume).\n# Railway variables take precedence; set new values there.\n' > "$DATA/.env"
  fi
  # Only fix ownership when it is wrong, so large volumes start fast.
  if [ "$(stat -c %u "$DATA")" != "$APP_UID" ] || [ "$(stat -c %u "$DATA/.env")" != "$APP_UID" ]; then
    chown -R "$APP_UID:$APP_UID" "$DATA"
  fi
  chmod 600 "$DATA/.env"
  exec setpriv --reuid="$APP_UID" --regid="$APP_UID" --init-groups env HOME=/home/landppt "$0" "$@"
fi

# Safe defaults that the image's .env.example would otherwise set differently.
export ENABLE_USER_REGISTRATION="${ENABLE_USER_REGISTRATION:-false}"
export LANDPPT_BOOTSTRAP_ADMIN_ENABLED="${LANDPPT_BOOTSTRAP_ADMIN_ENABLED:-true}"
export LANDPPT_BOOTSTRAP_ADMIN_USERNAME="${LANDPPT_BOOTSTRAP_ADMIN_USERNAME:-admin}"
export DATABASE_URL="${DATABASE_URL:-sqlite:////data/landppt.db}"
export HOST=0.0.0.0

if [ -z "${SECRET_KEY:-}" ]; then
  echo "FATAL: SECRET_KEY is not set" >&2; exit 1
fi
if [ -z "${LANDPPT_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
  echo "FATAL: LANDPPT_BOOTSTRAP_ADMIN_PASSWORD is not set (it must never fall back to admin123)" >&2; exit 1
fi

cd /app
# Migrate, create the admin and default templates, and seed the AI provider,
# under a database lock so overlapping deploys don't run this twice.
/opt/venv/bin/python /usr/local/lib/landppt-railway/seed.py

# Uvicorn exits non-zero on a crash, so Railway's ON_FAILURE policy restarts it.
exec /usr/local/bin/docker-entrypoint.sh "$@"
