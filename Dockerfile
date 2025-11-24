FROM varnish:7.6

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-varnish.git
LABEL org.opencontainers.image.description="Varnish cache server with default VCL configuration for Drupal 11."

# Copy the default.vcl configuration file.
COPY default.vcl /etc/varnish/default.vcl

