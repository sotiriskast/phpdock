#!/bin/sh
set -e

# Ensure directories exist with correct permissions
mkdir -p /usr/share/nginx/html/api-specs
chmod 777 /usr/share/nginx/html/api-specs

# Run the original entrypoint
exec /docker-entrypoint.sh "$@"