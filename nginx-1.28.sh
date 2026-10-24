#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

download_source \
	"nginx" \
	"https://nginx.org/download/nginx-1.28.0.tar.gz"


PREFIX="$PATH_ROOT/sys"
CONFDIR="$PATH_ROOT/share/config/nginx"
LOGDIR="$PATH_ROOT/share/logs/nginx"

dirs=(
	"$PATH_ROOT/sys/lib/nginx"
	"$PATH_ROOT/share/run/nginx"
	$LOGDIR
	$CONFDIR
	"$PATH_ROOT/share/config/nginx/sites"
)
mkdir -p "${dirs[@]}"

cd "$PATH_ROOT/source/nginx"
if [[ "$(uname -s)" == "Darwin" ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--sbin-path="${PREFIX}/bin/nginx" \
		--modules-path="${PREFIX}/module" \
		--conf-path="${CONFDIR}/nginx.conf" \
		--error-log-path="${LOGDIR}/error.log" \
		--http-log-path="${LOGDIR}/access.log" \
		--pid-path="$PATH_ROOT/share/run/nginx.pid" \
		--lock-path="$PATH_ROOT/share/run/nginx.lock" \
		--http-client-body-temp-path="$PATH_ROOT/share/run/nginx/client_temp" \
		--http-proxy-temp-path="$PATH_ROOT/share/run/nginx/proxy_temp" \
		--http-fastcgi-temp-path="$PATH_ROOT/share/run/nginx/fastcgi_temp" \
		--with-openssl="$PATH_ROOT/source/openssl" \
		--with-openssl-opt="no-tests" \
		--with-zlib="$PATH_ROOT/source/zlib" \
		--with-pcre \
		--with-pcre-jit \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_stub_status_module \
		--with-http_gzip_static_module \
		--with-http_auth_request_module \
		--with-http_secure_link_module \
		--with-http_slice_module \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_realip_module \
		--with-stream_ssl_preread_module \
		--with-threads \
		--with-compat \
		--user=omsy \
		--group=omsy \
		--with-cc-opt="-arch arm64 -I$PREFIX/include -D_GNU_SOURCE" \
		--with-ld-opt="-arch arm64 -L$PREFIX/lib/openssl -Wl,-rpath,$PREFIX/lib/openssl"

elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--sbin-path="${PREFIX}/bin/nginx" \
		--modules-path="${PREFIX}/module" \
		--conf-path="${CONFDIR}/nginx.conf" \
		--error-log-path="${LOGDIR}/error.log" \
		--http-log-path="${LOGDIR}/access.log" \
		--pid-path="$PATH_ROOT/share/run/nginx.pid" \
		--lock-path="$PATH_ROOT/share/run/nginx.lock" \
		--http-client-body-temp-path="$PATH_ROOT/share/run/nginx/client_temp" \
		--http-proxy-temp-path="$PATH_ROOT/share/run/nginx/proxy_temp" \
		--http-fastcgi-temp-path="$PATH_ROOT/share/run/nginx/fastcgi_temp" \
		--with-openssl="$PATH_ROOT/source/openssl" \
		--with-openssl-opt="no-tests" \
		--with-zlib="$PATH_ROOT/source/zlib" \
		--with-pcre \
		--with-pcre-jit \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_stub_status_module \
		--with-http_gzip_static_module \
		--with-http_auth_request_module \
		--with-http_secure_link_module \
		--with-http_slice_module \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_realip_module \
		--with-stream_ssl_preread_module \
		--with-threads \
		--with-file-aio \
		--with-compat \
		--user=omsy \
		--group=omsy
fi

make -j"${JOBS}" # 2>&1 | tee "$PATH_ROOT/build.log"
make install # 2>&1 | tee "$PATH_ROOT/build_.log"

mkdir -p $PATH_ROOT/share/run/nginx
sudo chown -R omsy:omsy $PATH_ROOT/share/run/nginx "$LOGDIR"

cat > "${CONFDIR}/nginx.conf" <<EOF
# =============================================================================
# nginx.conf — Nginx OMSY 1.27.4 — Reverse Proxy
# =============================================================================

user  omsy omsy;
worker_processes auto;
worker_rlimit_nofile 65535;

error_log $PATH_ROOT/share/logs/nginx/error.log warn;
pid       $PATH_ROOT/share/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    include      $PATH_ROOT/share/config/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log $PATH_ROOT/share/logs/nginx/access.log main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout 65;
    server_tokens   off;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json
               application/javascript application/xml+rss
               application/atom+xml image/svg+xml;

    # Buffer pour le reverse proxy
    proxy_buffer_size   128k;
    proxy_buffers       4 256k;
    proxy_busy_buffers_size 256k;

    # Headers communs vers Apache
    proxy_set_header Host              \$host;
    proxy_set_header X-Real-IP         \$remote_addr;
    proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_http_version 1.1;
    proxy_set_header Connection "";

    # Inclusion des sites
    include $PATH_ROOT/share/config/nginx/sites/*.conf;
}
EOF

cp "$PATH_ROOT/source/nginx/conf/mime.types" "${CONFDIR}/mime.types"

mkdir -p "${CONFDIR}/sites"
cat > "${CONFDIR}/sites/default.com.conf" <<EOF
# Redirect HTTP → HTTPS
# server {
#     listen 80;
#     server_name default.com www.default.com;
#     return 301 https://\$host\$request_uri;
# }

server {
    listen 80;
    server_name default.com www.default.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}

# HTTPS → Apache :8080
server {
    listen 443 ssl;
    http2  on;
    server_name default.com www.default.com;

    ssl_certificate     $PATH_ROOT/share/ssl/certs/defaults.crt;
    ssl_certificate_key $PATH_ROOT/share/ssl/private/defaults.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF