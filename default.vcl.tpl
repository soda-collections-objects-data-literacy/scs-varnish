vcl 4.1;

import std;

# -------------------------
# Backend: Drupal
# -------------------------
backend default {
    .host = "${VARNISH_BACKEND_HOST}";
    .port = "${VARNISH_BACKEND_PORT}";

    .connect_timeout = 5s;
    .first_byte_timeout = 60s;
    .between_bytes_timeout = 30s;

    .max_connections = 800;
}

# -------------------------
# ACL for purge/ban
# -------------------------
acl purge {
    "172.18.0.0"/16;
    "172.19.0.0"/16;
    "127.0.0.1";
}

# -------------------------
# VCL RECV
# -------------------------
sub vcl_recv {

    # --------------------------------
    # Forwarded headers (Traefik-safe)
    # Traefik terminates SSL and forwards HTTP to Varnish, so we trust
    # X-Forwarded-* headers from Traefik and only set defaults if missing.
    # --------------------------------
    # X-Forwarded-For: Append Varnish IP if Traefik already set it, otherwise set it.
    if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
    } else {
        set req.http.X-Forwarded-For = client.ip;
    }

    # X-Forwarded-Proto: Trust Traefik's header. If missing, default to http
    # (since Varnish receives HTTP from Traefik, but original may be HTTPS).
    if (!req.http.X-Forwarded-Proto) {
        set req.http.X-Forwarded-Proto = "http";
    }

    # X-Forwarded-Host: Pass through from Traefik, set from Host if missing.
    if (!req.http.X-Forwarded-Host) {
        set req.http.X-Forwarded-Host = req.http.Host;
    }

    # X-Forwarded-Port: Pass through from Traefik, set default if missing.
    if (!req.http.X-Forwarded-Port) {
        if (req.http.X-Forwarded-Proto == "https") {
            set req.http.X-Forwarded-Port = "443";
        } else {
            set req.http.X-Forwarded-Port = "80";
        }
    }

    # -------------------------
    # PURGE / BAN
    # -------------------------
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "PURGE not allowed"));
        }
        return (purge);
    }

    if (req.method == "BAN") {
        if (!client.ip ~ purge) {
            return (synth(403, "BAN not allowed"));
        }

        # Ban by host (Drupal cache tags compatible)
        ban("req.http.host == " + req.http.host);
        return (synth(200, "Ban added"));
    }

    # -------------------------
    # Only cache GET/HEAD
    # -------------------------
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # -------------------------
    # Pass admin & system paths
    # -------------------------
    if (req.url ~ "^/(status|update|install)\.php$" ||
        req.url ~ "^/admin" ||
        req.url ~ "^/user" ||
        req.url ~ "^/flag" ||
        req.url ~ "^.*/(ajax|ahah)/") {
        return (pass);
    }

    # -------------------------
    # Static assets
    # -------------------------
    if (req.url ~ "(?i)\.(css|js|png|gif|jpe?g|svg|ico|webp|woff2?|ttf|eot|pdf|zip|tar|gz)(\?.*)?$") {
        unset req.http.Cookie;
        return (hash);
    }

    # -------------------------
    # Remove cookies for anonymous users
    # -------------------------
    if (req.http.Cookie) {
        if (!(req.http.Cookie ~ "SESS") &&
            !(req.http.Cookie ~ "SSESS")) {
            unset req.http.Cookie;
        }
    }

    # -------------------------
    # Authenticated users bypass cache
    # -------------------------
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    return (hash);
}

# -------------------------
# BACKEND RESPONSE
# -------------------------
sub vcl_backend_response {

    # -------------------------
    # Grace mode (serve stale if backend down)
    # -------------------------
    set beresp.grace = 6h;

    # -------------------------
    # Never cache admin or user pages
    # -------------------------
    if (bereq.url ~ "^/(admin|user)") {
        set beresp.uncacheable = true;
        set beresp.ttl = 0s;
        return (deliver);
    }

    # -------------------------
    # Remove cookies from static assets
    # -------------------------
    if (bereq.url ~ "(?i)\.(css|js|png|gif|jpe?g|svg|ico|webp|woff2?|ttf|eot|pdf|zip|tar|gz)(\?.*)?$") {
        unset beresp.http.Set-Cookie;
    }

    # -------------------------
    # Cache 404 for 5 minutes
    # -------------------------
    if (beresp.status == 404) {
        set beresp.ttl = 5m;
        return (deliver);
    }

    # -------------------------
    # Redirect handling
    # -------------------------
    if (beresp.status == 301 || beresp.status == 302) {
        if (beresp.http.Set-Cookie || beresp.http.Authorization) {
            set beresp.uncacheable = true;
            return (deliver);
        }
    }

    # -------------------------
    # Default TTL for anonymous pages
    # -------------------------
    if (beresp.ttl <= 0s) {
        set beresp.ttl = 5m;
    }

    # -------------------------
    # Don't cache if cookies or wildcard vary
    # -------------------------
    if (beresp.http.Set-Cookie || beresp.http.Vary == "*") {
        set beresp.uncacheable = true;
        return (deliver);
    }

    return (deliver);
}

# -------------------------
# DELIVER
# -------------------------
sub vcl_deliver {

    if (obj.hits > 0) {
        set resp.http.X-Varnish-Cache = "HIT";
    } else {
        set resp.http.X-Varnish-Cache = "MISS";
    }

    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.X-Powered-By;
    unset resp.http.X-Generator;

    return (deliver);
}
