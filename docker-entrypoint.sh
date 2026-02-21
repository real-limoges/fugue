#!/bin/sh
set -e

echo "Running migrations..."
/app/bin/fugue eval "Fugue.Release.migrate()"

echo "Starting Fugue..."
exec /app/bin/fugue start
