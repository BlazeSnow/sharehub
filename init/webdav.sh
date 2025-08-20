#!/bin/bash

echo "正在配置 WebDAV 服务"

PASSWORD_HASH=$(caddy hash-password --plaintext "$PASSWORD" 2>/dev/null || echo "$PASSWORD")

mkdir -p /etc/caddy
touch /etc/caddy/Caddyfile

if [ "$WRITABLE" = "false" ]; then
    cat >/etc/caddy/Caddyfile <<EOF
{
    order webdav before file_server
}

:80 {
    root * $SHAREPATH
    
    @readonly_methods method GET HEAD OPTIONS PROPFIND
    
    route {
        webdav @readonly_methods
        file_server browse
        respond * "WebDAV is read-only" 405
    }
}
EOF
else
    cat >/etc/caddy/Caddyfile <<EOF
{
    order webdav before file_server
}

:80 {
    root * $SHAREPATH
    webdav
    file_server browse
}
EOF
fi

mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy 2>/dev/null || true
