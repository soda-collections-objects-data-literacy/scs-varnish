FROM varnish:7.6

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-varnish.git
LABEL org.opencontainers.image.description="Varnish cache server with default VCL configuration for Drupal 11."

# Copy VCL template
COPY default.vcl.template /etc/varnish/default.vcl.template

# Ensure /etc/varnish is writable by varnish user
RUN chown -R varnish:varnish /etc/varnish

# Copy entrypoint script with execute permissions
COPY --chmod=+x docker-entrypoint.sh /docker-entrypoint.sh

# Set default environment variables
ENV VARNISH_BACKEND_HOST=drupal \
    VARNISH_BACKEND_PORT=80 \
    VARNISH_SIZE=256M

EXPOSE 80 8443

ENTRYPOINT ["/docker-entrypoint.sh"]
