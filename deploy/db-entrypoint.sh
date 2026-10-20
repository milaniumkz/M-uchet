#!/bin/sh
set -eu
if [ -z "${MUCHET_APP_PASSWORD_FILE:-}" ]; then
  echo 'Application database password file is required.' >&2
  exit 1
fi
MUCHET_APP_PASSWORD=$(cat "$MUCHET_APP_PASSWORD_FILE")
if [ -z "$MUCHET_APP_PASSWORD" ]; then
  echo 'Application database password must not be empty.' >&2
  exit 1
fi
export MUCHET_APP_PASSWORD
exec /usr/local/bin/docker-entrypoint.sh "$@"
