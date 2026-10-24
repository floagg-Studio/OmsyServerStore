cat > "${CONFDIR}/sites/phpmyadmin.conf" <<EOF
# PHPMyAdmin — accessible sur :8888 (HTTPS)
server {
    listen 8888 ssl;
    http2  on;
    server_name _;

    ssl_certificate     $PATH_ROOT/share/ssl/certs/phpmyadmin.crt;
    ssl_certificate_key $PATH_ROOT/share/ssl/private/phpmyadmin.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_session_cache   shared:PMASSL:5m;
    ssl_session_timeout 10m;

    # Restriction IP recommandée (décommente et adapte)
    # allow 192.168.0.0/24;
    # deny all;

    location / {
        proxy_pass http://127.0.0.1:8880;
    }
}
EOF

cat > "${CONFDIR}/vhosts/phpmyadmin.conf" <<EOF
# Vhost PHPMyAdmin — Apache interne port 8880
<VirtualHost *:8880>
    ServerName phpmyadmin.local
    DocumentRoot ${PATH_ROOT}/usr/phpmyadmin

    DirectoryIndex index.php

    # PHP-FPM 8.4
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:${PATH_ROOT}/share/run/php-fpm84.sock|fcgi://localhost"
    </FilesMatch>

    <Directory "${PATH_ROOT}/usr/phpmyadmin">
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${PATH_ROOT}/share/logs/apache/phpmyadmin-error.log
    CustomLog ${PATH_ROOT}/share/logs/apache/phpmyadmin-access.log combined
</VirtualHost>
EOF