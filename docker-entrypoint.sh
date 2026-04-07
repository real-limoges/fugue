#!/bin/sh
set -e

# If a CozoDB auth token file is mounted, export it
COZO_AUTH_FILE="/cozo-auth/cozo.db.rocksdb.cozo_auth"
if [ -z "$COZODB_AUTH_TOKEN" ] && [ -f "$COZO_AUTH_FILE" ]; then
  echo "Reading CozoDB auth token from shared volume..."
  export COZODB_AUTH_TOKEN=$(cat "$COZO_AUTH_FILE")
fi

echo "Starting Fugue..."
exec /app/bin/fugue start
