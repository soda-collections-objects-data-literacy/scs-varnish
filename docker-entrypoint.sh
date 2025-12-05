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

# Substitute environment variables in VCL template
# Use sed for reliable substitution
sed -e "s|\${VARNISH_BACKEND_HOST}|${VARNISH_BACKEND_HOST}|g" \
    -e "s|\${VARNISH_BACKEND_PORT}|${VARNISH_BACKEND_PORT}|g" \
    /etc/varnish/default.vcl.template > /etc/varnish/default.vcl

echo "VCL configuration after substitution:"
grep -A 2 "backend default" /etc/varnish/default.vcl || true

# Validate VCL
echo "Validating VCL configuration..."
varnishd -C -f /etc/varnish/default.vcl || {
    echo "VCL validation failed!"
    exit 1
}

echo "Starting Varnish..."
exec varnishd -F \
  -f /etc/varnish/default.vcl \
  -a :80 \
  -s malloc,${VARNISH_SIZE}
