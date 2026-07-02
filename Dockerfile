FROM varnish:7.6

LABEL org.opencontainers.image.source=https://github.com/soda-collections-objects-data-literacy/scs-varnish-image.git
LABEL org.opencontainers.image.description="Varnish cache server with default VCL configuration for Drupal 11."

# Change permissions for to allow overriding default.vcl in entrypoint
USER root
RUN chown varnish:varnish default.vcl
USER varnish

COPY default.vcl.tpl /etc/varnish/default.vcl.tpl

COPY --chmod=+x entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
