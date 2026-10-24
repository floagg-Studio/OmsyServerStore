#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

download_source \
	"apache" \
	"https://archive.apache.org/dist/httpd/httpd-2.4.65.tar.gz"

PREFIX="$PATH_ROOT/sys"
CONFDIR="$PATH_ROOT/share/config/apache"
LOGDIR="$PATH_ROOT/share/logs/apache"
WWWDIR="$PATH_ROOT/usr"

dirs=(
	"$PATH_ROOT/sys/lib/apache"
	"$PATH_ROOT/share/logs/apache"
	$CONFDIR
	"$CONFDIR/vhosts"
	"$WWWDIR/default.com/public"
)
mkdir -p "${dirs[@]}"

cd "$PATH_ROOT/source/pcre2"
if [[ "$(uname -s)" == "Darwin" ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--libdir="${PREFIX}/lib/apache" \
		--includedir="${PREFIX}/include" \
		--enable-shared \
		--enable-pcre2-16 \
		--enable-pcre2-32 \
		CFLAGS="-arch arm64" \
		CXXFLAGS="-arch arm64" \
		LDFLAGS="-arch arm64"
elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--libdir="${PREFIX}/lib/apache" \
		--includedir="${PREFIX}/include" \
		--enable-shared \
		--enable-pcre2-16 \
		--enable-pcre2-32
fi

make -j"${JOBS}"
make install

if [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	echo "${PREFIX}/lib/apache" > /etc/ld.so.conf.d${PATH_ROOT}-pcre2.conf
	ldconfig
fi


cd "$PATH_ROOT/source/nghttp2"
if [[ "$(uname -s)" == "Darwin" ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--libdir="${PREFIX}/lib/apache" \
		--includedir="${PREFIX}/include" \
		--enable-shared \
		--disable-static \
		--disable-python-bindings \
		--disable-examples \
		--disable-app \
		--disable-hpack-tools \
		--disable-failmalloc \
		PKG_CONFIG_PATH="${PREFIX}/lib/apache/pkgconfig:${PREFIX}/lib/openssl/pkgconfig" \
		CFLAGS="-arch arm64" \
		CXXFLAGS="-arch arm64" \
		LDFLAGS="-arch arm64 -Wl,-rpath,${PREFIX}/lib/openssl -Wl,-rpath,${PREFIX}/lib/apache"

elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--libdir="${PREFIX}/lib/apache" \
		--includedir="${PREFIX}/include" \
		--enable-shared \
		--disable-static \
		--disable-python-bindings \
		--disable-examples \
		--disable-app \
		--disable-hpack-tools \
		--disable-failmalloc \
		PKG_CONFIG_PATH="${PREFIX}/lib/apache/pkgconfig:${PREFIX}/lib/openssl/pkgconfig"
fi

make -j"${JOBS}"
make install
if [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	ldconfig
fi

mv "$PATH_ROOT/source/apr" "$PATH_ROOT/source/apache/srclib/apr"
mv "$PATH_ROOT/source/apr-util" "$PATH_ROOT/source/apache/srclib/apr-util"


cd "$PATH_ROOT/source/apache"
if [[ "$(uname -s)" == "Darwin" ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--exec-prefix="${PREFIX}" \
		--bindir="${PREFIX}/bin" \
		--sbindir="${PREFIX}/bin" \
		--libdir="${PREFIX}/lib/apache" \
		--libexecdir="${PREFIX}/module" \
		--sysconfdir="${CONFDIR}" \
		--datadir="${WWWDIR}" \
		--localstatedir="${PATH_ROOT}/share" \
		--with-mpm=event \
		--with-included-apr \
		--with-pcre="${PREFIX}/bin/pcre2-config" \
		--with-ssl="${PREFIX}" \
		--with-z=/usr \
		--with-nghttp2="${PREFIX}" \
		--enable-so \
		--enable-ssl \
		--enable-http2 \
		--enable-rewrite \
		--enable-proxy \
		--enable-proxy-fcgi \
		--enable-proxy-http \
		--enable-proxy-balancer \
		--enable-headers \
		--enable-expires \
		--enable-deflate \
		--enable-mime \
		--enable-alias \
		--enable-dir \
		--enable-auth-basic \
		--enable-setenvif \
		--enable-log-config \
		--enable-env \
		--enable-vhost-alias \
		--enable-status \
		--enable-info \
		--enable-mods-shared=most \
		--enable-mpms-shared=all \
		CPPFLAGS="-I${PREFIX}/include -arch arm64" \
		CFLAGS="-arch arm64" \
		CXXFLAGS="-arch arm64" \
		LDFLAGS="-L${PREFIX}/lib/apache -L${PREFIX}/lib/openssl -arch arm64 -Wl,-rpath,${PREFIX}/lib/openssl -Wl,-rpath,${PREFIX}/lib/apache" \
		PKG_CONFIG_PATH="${PREFIX}/lib/apache/pkgconfig:${PREFIX}/lib/openssl/pkgconfig"

elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	./configure \
		--prefix="${PREFIX}" \
		--exec-prefix="${PREFIX}" \
		--bindir="${PREFIX}/bin" \
		--sbindir="${PREFIX}/bin" \
		--libdir="${PREFIX}/lib/apache" \
		--libexecdir="${PREFIX}/module" \
		--sysconfdir="${CONFDIR}" \
		--datadir="${WWWDIR}" \
		--localstatedir="${PATH_ROOT}/share" \
		--with-mpm=event \
		--with-included-apr \
		--with-pcre="${PREFIX}/bin/pcre2-config" \
		--with-ssl="${PREFIX}" \
		--with-z=/usr \
		--with-nghttp2="${PREFIX}" \
		--enable-so \
		--enable-ssl \
		--enable-http2 \
		--enable-rewrite \
		--enable-proxy \
		--enable-proxy-fcgi \
		--enable-proxy-http \
		--enable-proxy-balancer \
		--enable-headers \
		--enable-expires \
		--enable-deflate \
		--enable-mime \
		--enable-alias \
		--enable-dir \
		--enable-auth-basic \
		--enable-setenvif \
		--enable-log-config \
		--enable-env \
		--enable-vhost-alias \
		--enable-status \
		--enable-info \
		--enable-mods-shared=most \
		--enable-mpms-shared=all \
		CPPFLAGS="-I${PREFIX}/include" \
		LDFLAGS="-L${PREFIX}/lib/apache -L${PREFIX}/lib/openssl \
			-Wl,-rpath,${PREFIX}/lib/openssl \
			-Wl,-rpath,${PREFIX}/lib/apache" \
		PKG_CONFIG_PATH="${PREFIX}/lib/apache/pkgconfig:${PREFIX}/lib/openssl/pkgconfig"
fi

make -j"${JOBS}"
make install
if [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	echo "${PREFIX}/lib/apache" > /etc/ld.so.conf.d/omsy-apache.conf
	ldconfig
fi

mkdir -p "${CONFDIR}/vhosts"
cat > "${CONFDIR}/httpd.conf" <<EOF
# =============================================================================
# httpd.conf — Apache OMSY 2.4.63
# Écoute sur 8080 (interne, derrière Nginx reverse proxy)
# =============================================================================

ServerRoot "${PATH_ROOT}/sys"
ServerAdmin admin@default.com
ServerName  default.com

Listen 8080
Listen 8880

User  omsy
Group omsy

# Modules de base
LoadModule mpm_event_module		${PATH_ROOT}/sys/module/mod_mpm_event.so
LoadModule authn_core_module	${PATH_ROOT}/sys/module/mod_authn_core.so
LoadModule authz_core_module	${PATH_ROOT}/sys/module/mod_authz_core.so
LoadModule authz_host_module	${PATH_ROOT}/sys/module/mod_authz_host.so
LoadModule mime_module			${PATH_ROOT}/sys/module/mod_mime.so
LoadModule log_config_module	${PATH_ROOT}/sys/module/mod_log_config.so
LoadModule env_module			${PATH_ROOT}/sys/module/mod_env.so
LoadModule headers_module		${PATH_ROOT}/sys/module/mod_headers.so
LoadModule setenvif_module		${PATH_ROOT}/sys/module/mod_setenvif.so
LoadModule ssl_module			${PATH_ROOT}/sys/module/mod_ssl.so
LoadModule socache_shmcb_module ${PATH_ROOT}/sys/module/mod_socache_shmcb.so
LoadModule rewrite_module		${PATH_ROOT}/sys/module/mod_rewrite.so
LoadModule deflate_module		${PATH_ROOT}/sys/module/mod_deflate.so
LoadModule expires_module		${PATH_ROOT}/sys/module/mod_expires.so
LoadModule proxy_module			${PATH_ROOT}/sys/module/mod_proxy.so
LoadModule proxy_fcgi_module	${PATH_ROOT}/sys/module/mod_proxy_fcgi.so
LoadModule proxy_http_module	${PATH_ROOT}/sys/module/mod_proxy_http.so
LoadModule alias_module			${PATH_ROOT}/sys/module/mod_alias.so
LoadModule dir_module			${PATH_ROOT}/sys/module/mod_dir.so
LoadModule vhost_alias_module	${PATH_ROOT}/sys/module/mod_vhost_alias.so
LoadModule status_module		${PATH_ROOT}/sys/module/mod_status.so
LoadModule unixd_module			${PATH_ROOT}/sys/module/mod_unixd.so
LoadModule http2_module			${PATH_ROOT}/sys/module/mod_http2.so

#
PidFile "/chemin/absolu/vers/share/run/apache2.pid"

# MIME types
TypesConfig ${CONFDIR}/mime.types

# Logs
ErrorLog	${PATH_ROOT}/share/logs/apache/error.log
CustomLog	${PATH_ROOT}/share/logs/apache/access.log	combined
LogLevel warn

# Performance MPM Event
<IfModule mpm_event_module>
	StartServers			2
	MinSpareThreads			25
	MaxSpareThreads			75
	ThreadLimit				64
	ThreadsPerChild			25
	MaxRequestWorkers		150
	MaxConnectionsPerChild 1000
	PIDFile     ${PATH_ROOT}/share/run/httpd.pid
</IfModule>

# Sécurité
ServerTokens Prod
ServerSignature Off
TraceEnable Off

# SSL
SSLRandomSeed	startup	file:/dev/urandom  256
SSLRandomSeed	connect	builtin
SSLSessionCache			shmcb:${PATH_ROOT}/share/run/ssl_scache(512000)
SSLSessionCacheTimeout	300
SSLCipherSuite			ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
SSLProtocol				all -SSLv3 -TLSv1 -TLSv1.1
SSLHonorCipherOrder		off
SSLUseStapling			On
SSLStaplingCache		shmcb:${PATH_ROOT}/share/run/ssl_stapling(32768)

# Inclusion des vhosts
IncludeOptional ${CONFDIR}/vhosts/*.conf

# Accès par défaut
<Directory />
	AllowOverride None
	Require all denied
</Directory>

<Directory "${PATH_ROOT}/usr">
	Options FollowSymLinks
	AllowOverride All
	Require all granted
</Directory>
EOF

cat > "${CONFDIR}/vhosts/default.com.conf" <<EOF
# Vhost default.com — Apache interne port 8080
<VirtualHost *:8080>
	ServerName  default.com
	ServerAlias www.default.com
	DocumentRoot ${PATH_ROOT}/usr/default.com/public

	DirectoryIndex index.php index.html

	# PHP-FPM LINE AUTO INCLUDE
	IncludeOptional ${CONFDIR}/php-handlers/default.com.conf

	<Directory "${PATH_ROOT}/usr/default.com/public">
		Options -Indexes +FollowSymLinks
		AllowOverride All
		Require all granted
	</Directory>

	ErrorLog  ${PATH_ROOT}/share/logs/apache/default.com-error.log
	CustomLog ${PATH_ROOT}/share/logs/apache/default.com-access.log combined

	Header always set X-Content-Type-Options "nosniff"
	Header always set X-Frame-Options "SAMEORIGIN"
	Header always set X-XSS-Protection "1; mode=block"
	Header always set Referrer-Policy "strict-origin-when-cross-origin"
</VirtualHost>
EOF

mkdir -p "${CONFDIR}/php-handlers"

cp "$PATH_ROOT/source/apache/docs/conf/mime.types" "${CONFDIR}/mime.types" 2>/dev/null || \
cp "${PATH_ROOT}/sys/conf/mime.types" "${CONFDIR}/mime.types" 2>/dev/null || true

mkdir -p $PATH_ROOT/usr/default.com/public
cat > "$PATH_ROOT/usr/default.com/public/index.php" <<EOF
<?php phpinfo();
EOF
sudo chown -R omsy:omsy $PATH_ROOT/usr/default.com

mkdir -p $PATH_ROOT/share/run
sudo chown -R omsy:omsy "$LOGDIR" $PATH_ROOT/share/run