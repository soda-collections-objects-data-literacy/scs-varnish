# SCS Varnish Image

A containerized Varnish HTTP cache server optimized for Drupal 11 applications with pre-configured VCL rules.

## Overview

This Docker image provides a ready-to-use Varnish cache layer with:
- **Base image**: `varnish:7.6`
- **Pre-configured VCL**: Drupal-optimized caching rules
- **Performance**: Configured for high-traffic Drupal sites
- **Security**: Purge and ban request handling with ACL controls

## Features

### Caching Optimization
- Cookie handling for anonymous and authenticated users
- Static file caching without cookies
- Bypass caching for admin and AJAX paths
- 404 error page caching (5 minutes)
- Grace mode for stale content delivery

### Security
- ACL-based purge and ban request controls
- Header sanitization (X-Varnish, Via, X-Generator, X-Powered-By)
- Cookie filtering to prevent tracking

### Performance
- Configurable backend timeouts (600s default)
- Maximum 800 backend connections
- 6-hour grace period for stale content
- Cache hit/miss headers for debugging

## Configuration

### Backend Configuration

The default VCL is configured to use a backend named `drupal` on port `80`. Modify the backend settings in `default.vcl` if needed:

```vcl
backend default {
    .host = "drupal";
    .port = "80";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
    .max_connections = 800;
}
```

### ACL Configuration

By default, purge and ban requests are allowed from:
- `localhost`
- `drupal` (container name)

To add additional allowed hosts, modify the ACL in `default.vcl`:

```vcl
acl purge {
    "localhost";
    "drupal";
    "your-additional-host";
}
```

### Environment Variables

When running the container, you can configure Varnish memory size:

- `VARNISH_SIZE`: Memory allocation for Varnish cache (default: `256M`)

## Usage

### With Docker Compose

```yaml
services:
  varnish:
    image: ghcr.io/soda-collections-objects-data-literacy/scs-varnish:latest
    container_name: my-project--varnish
    restart: always
    environment:
      - VARNISH_SIZE=256M
    ports:
      - "80:80"
    networks:
      - internal
```

### Standalone Docker

```bash
docker run -d \
  --name varnish \
  -e VARNISH_SIZE=512M \
  -p 80:80 \
  ghcr.io/soda-collections-objects-data-literacy/scs-varnish:latest
```

## VCL Rules

### Bypassed Paths

The following paths are not cached and passed directly to the backend:
- `/status.php`
- `/update.php`
- `/install.php`
- `/admin/*`
- `/user/*`
- `/flag/*`
- `*/ajax/*`
- `*/ahah/*`

### Cached File Types

Static files are cached without cookies:
- Documents: `pdf`, `doc`, `xls`, `ppt`, `csv`, `txt`, `dat`, `asc`, `tgz`
- Images: `png`, `gif`, `jpeg`, `jpg`, `ico`, `swf`
- Web assets: `css`, `js`

### Cache Control

- **Authenticated users**: Requests with cookies or authorization headers bypass cache
- **Anonymous users**: Cookies are removed and content is cached
- **Static files**: Cached regardless of user state
- **POST/PUT/DELETE**: Never cached
- **404 errors**: Cached for 5 minutes

## Cache Management

### Purge Cache for Specific URL

```bash
curl -X PURGE http://your-domain.com/path/to/purge
```

### Ban URLs

```bash
curl -X BAN http://your-domain.com/path/to/ban
```

### Check Cache Status

Response headers indicate cache status:
- `X-Varnish-Cache: HIT` - Content served from cache
- `X-Varnish-Cache: MISS` - Content fetched from backend

## Development

### Building the Image

```bash
git clone <repository-url>
cd scs-varnish
docker build -t scs-varnish:latest .
```

### Testing VCL Configuration

Before building, validate the VCL syntax:

```bash
varnishd -C -f default.vcl
```

### Customizing VCL

To modify caching rules:

1. Edit `default.vcl` with your custom rules
2. Rebuild the image
3. Test thoroughly in a staging environment

### Extending the Image

Create a custom Dockerfile:

```dockerfile
FROM ghcr.io/soda-collections-objects-data-literacy/scs-varnish:latest

# Copy custom VCL configuration.
COPY custom-default.vcl /etc/varnish/default.vcl
```

## Monitoring and Debugging

### View Cache Statistics

```bash
docker exec <container-name> varnishstat
```

### View Cache Log

```bash
docker exec <container-name> varnishlog
```

### Check Backend Health

```bash
docker exec <container-name> varnishadm backend.list
```

## Performance Tuning

### Memory Allocation

Adjust `VARNISH_SIZE` based on your content and traffic:
- Small sites: `128M - 256M`
- Medium sites: `256M - 512M`
- Large sites: `512M - 2G`

### Cache TTL

Default cache TTL is 5 minutes (300s). Modify in VCL:

```vcl
set beresp.ttl = 300s;  # Adjust as needed
```

### Grace Period

Grace period allows serving stale content if backend is unavailable:

```vcl
set beresp.grace = 6h;  # Currently set to 6 hours
```

## Troubleshooting

### Cache Not Working

1. Check cache headers: `curl -I http://your-domain.com`
2. Look for `X-Varnish-Cache` header
3. Verify cookies are being handled correctly
4. Check backend connectivity

### Backend Connection Issues

```bash
docker exec <container-name> varnishadm backend.list
docker logs <container-name>
```

### High Memory Usage

- Reduce `VARNISH_SIZE`
- Review cached content size
- Implement cache expiration policies

## License

This project is licensed under the GNU General Public License v3.0. See the [LICENSE.md](LICENSE.md) file for details.

## Support

### Getting Help
- Review container logs: `docker logs <container-name>`
- Check [Varnish documentation](https://varnish-cache.org/docs/)
- Consult [Drupal Varnish integration guide](https://www.drupal.org/docs/administering-a-drupal-site/caching-to-improve-performance/varnish-cache)

### Contributing
- Report issues through the project issue tracker
- Submit pull requests for improvements
- Include tests for VCL changes

---

**Note**: This image is designed for production use with Drupal 11. Test thoroughly in a staging environment before deploying to production.

