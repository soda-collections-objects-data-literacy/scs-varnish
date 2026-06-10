#!/bin/bash
set -e

echo "Configuring Varnish backend..."
echo "Backend host: ${VARNISH_BACKEND_HOST}"
echo "Backend port: ${VARNISH_BACKEND_PORT}"

# Ensure environment variables are set
if [ -z "${VARNISH_BACKEND_HOST}" ]; then
  echo "ERROR: VARNISH_BACKEND_HOST is not set!"
  exit 1
fi

if [ -z "${VARNISH_BACKEND_PORT}" ]; then
  echo "ERROR: VARNISH_BACKEND_PORT is not set!"
  exit 1
fi

# Subsititute wit env
sed -e "s|\${VARNISH_BACKEND_HOST}|${VARNISH_BACKEND_HOST}|g" \
    -e "s|\${VARNISH_BACKEND_PORT}|${VARNISH_BACKEND_PORT}|g" \
    /etc/varnish/default.vcl.tpl > /etc/varnish/default.vcl

echo "Starting Varnish..."
exec /usr/local/bin/docker-varnish-entrypoint "$@"
