vcl 4.1;

import std;

backend default {
    .host = "drupal";
    .port = "80";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
    .max_connections = 800;
}

acl purge {
    "localhost";
    "drupal";
}

sub vcl_recv {
    # Remove has_js and Google Analytics cookies.
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");
    # Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");

    # Allow purging from ACL.
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        return (purge);
    }

    # Only allow BAN requests from IP addresses in the 'purge' ACL.
    if (req.method == "BAN") {
        if (!client.ip ~ purge) {
            return (synth(403, "Not allowed."));
        }
        ban("req.http.host == " + req.http.host + " && req.url == " + req.url);
        return (synth(200, "Ban added."));
    }

    # Only cache GET and HEAD requests (pass through POST requests).
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Pass through any administrative or AJAX-related paths.
    if (req.url ~ "^/status\.php$" ||
        req.url ~ "^/update\.php$" ||
        req.url ~ "^/install\.php$" ||
        req.url ~ "^/admin" ||
        req.url ~ "^/admin/.*$" ||
        req.url ~ "^/user" ||
        req.url ~ "^/user/.*$" ||
        req.url ~ "^/flag/.*$" ||
        req.url ~ "^.*/ajax/.*$" ||
        req.url ~ "^.*/ahah/.*$") {
        return (pass);
    }

    # Remove all cookies for static files
    # A standard Drupal installation doesn't send cookies for static files (see .htaccess).
    # If you add custom content types, remove this rule for those content types.
    if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
        unset req.http.Cookie;
    }

    # Remove cookies for non-admin paths if there are no Drupal sessions.
    if (!(req.url ~ "^/admin") &&
        !(req.http.Cookie ~ "SESS[a-z0-9]+") &&
        !(req.http.Cookie ~ "SSESS[a-z0-9]+")
    ) {
        unset req.http.Cookie;
    }

    # If POST, PUT or DELETE, then don't cache.
    if (req.method == "POST" || req.method == "PUT" || req.method == "DELETE") {
        return (pass);
    }

    # Drupal 11: Remove cookies for anonymous users.
    if (!(req.http.Cookie ~ "SESS") && !(req.http.Cookie ~ "SSESS")) {
        unset req.http.Cookie;
    }

    # Pass anything that's authenticated.
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    return (hash);
}

sub vcl_backend_response {
    # Don't allow static files to set cookies.
    if (bereq.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
        unset beresp.http.set-cookie;
    }

    # Cache 404s for 5 minutes.
    if (beresp.status == 404) {
        set beresp.ttl = 300s;
        set beresp.grace = 1h;
    }

    # Don't cache redirects with cookies or auth.
    if (beresp.status == 301 || beresp.status == 302) {
        if (beresp.http.set-cookie || beresp.http.authorization) {
            set beresp.uncacheable = true;
            set beresp.ttl = 120s;
            return (deliver);
        }
    }

    # Allow items to be stale if needed.
    set beresp.grace = 6h;

    # Cache everything by default for 5 minutes.
    if (beresp.ttl <= 0s ||
        beresp.http.Set-Cookie ||
        beresp.http.Vary == "*") {
        set beresp.ttl = 300s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    return (deliver);
}

sub vcl_deliver {
    # Add cache hit data.
    if (obj.hits > 0) {
        set resp.http.X-Varnish-Cache = "HIT";
    }
    else {
        set resp.http.X-Varnish-Cache = "MISS";
    }
    # Remove some headers for security and cleanliness.
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.X-Generator;
    unset resp.http.X-Powered-By;
    return (deliver);
}

