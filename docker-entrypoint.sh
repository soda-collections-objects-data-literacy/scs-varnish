#!/bin/bash
set -e

echo "Configuring Varnish backend..."
echo "Backend host: ${VARNISH_BACKEND_HOST}"
echo "Backend port: ${VARNISH_BACKEND_PORT}"

# Substitute environment variables in VCL template
envsubst '${VARNISH_BACKEND_HOST} ${VARNISH_BACKEND_PORT}' \
  < /etc/varnish/default.vcl.template \
  > /etc/varnish/default.vcl

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
