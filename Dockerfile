FROM varnish:7.6

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-varnish.git
LABEL org.opencontainers.image.description="Varnish cache server with default VCL configuration for Drupal 11."

# Copy the default.vcl configuration file.
COPY default.vcl /etc/varnish/default.vcl

# Set permissions.
RUN chmod 644 /etc/varnish/default.vcl

# Expose Varnish port.
EXPOSE 8000

# Start Varnish with the default VCL.
CMD ["varnishd", "-F", "-f", "/etc/varnish/default.vcl", "-a", ":8000"]

