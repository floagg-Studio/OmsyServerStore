#!/bin/bash
set -e

PATH_ROOT="/Users/julie/Documents/OmsyServer"
ROOT=$(pwd)

if [[ "$(uname -s)" == "Darwin" ]]; then
	SED_INPLACE=(-i '')
else
	SED_INPLACE=(-i)
fi

echo $PATH_ROOT

names=(
	php85
)
urls=(
	"https://www.php.net/distributions/php-8.5.12.tar.gz"
)

for i in "${!names[@]}"; do
	file="${names[$i]}"
	url="${urls[$i]}"
	filename=$(basename "${url}")
	
	echo "--- Traitement de ${file} ---"
	wget -q --show-progress "${url}" -O "$PATH_ROOT/source/$filename"
	dir=$(tar -tf "$PATH_ROOT/source/$filename" | head -1 | cut -d/ -f1)
	tar -xf "$PATH_ROOT/source/$filename" -C "$PATH_ROOT/source/"
	mv "$PATH_ROOT/source/$dir" "$PATH_ROOT/source/${file}"
	chmod -R 755 "$PATH_ROOT/source/${file}"
done

dirs=(
	"$PATH_ROOT/sys/lib/php"
	"$PATH_ROOT/share/logs/php"
	"$PATH_ROOT/share/config/php"
)
mkdir -p "${dirs[@]}"

SRC_DIR="${ROOT}/source/php85"

PREFIX="$PATH_ROOT/sys/php85"
CONFDIR="$PATH_ROOT/share/config/php"
LOGDIR="$PATH_ROOT/share/logs/php"
EXTDIR="$PATH_ROOT/sys/lib/php/8.5"
OPENSSL_PREFIX="$PATH_ROOT/sys"

if [[ "$(uname -s)" == "Darwin" ]]; then
	OS="Macos"
	JOBS=$(sysctl -n hw.ncpu)
elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	OS="Ubuntu"
	JOBS=$(nproc)
fi

cd "$SRC_DIR"
if [[ "$(uname -s)" == "Darwin" ]]; then
	HOMEBREW_PREFIX=$(brew --prefix)
	BZIP2_PREFIX=$(brew --prefix bzip2)
	LIBXML2_PREFIX=$(brew --prefix libxml2)
	LIBSXSLT_PREFIX=$(brew --prefix libxslt)
	CURL_PREFIX=$(brew --prefix curl)
	GETTEXT_PREFIX=$(brew --prefix gettext)
	ICU_PREFIX=$(brew --prefix icu4c)
	READLINE_PREFIX=$(brew --prefix readline)
	SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "")
	
	if [ -n "$SDK_PATH" ]; then
		SDK_FLAG="-isysroot $SDK_PATH"
		echo "📦 Utilisation du SDK : $SDK_PATH"
	else
		SDK_FLAG=""
		echo "⚠️  SDK non trouvé, utilisation des chemins par défaut."
	fi
	export CPPFLAGS="$SDK_FLAG -I$HOMEBREW_PREFIX/include -I$BZIP2_PREFIX/include -I$LIBXML2_PREFIX/include/libxml2 -I$LIBSXSLT_PREFIX/include -I$CURL_PREFIX/include -I$GETTEXT_PREFIX/include -I$ICU_PREFIX/include -I$READLINE_PREFIX/include -I$PATH_ROOT/sys/include -arch arm64"
	export LDFLAGS="$SDK_FLAG -L$HOMEBREW_PREFIX/lib -L$BZIP2_PREFIX/lib -L$LIBXML2_PREFIX/lib -L$CURL_PREFIX/lib -L$GETTEXT_PREFIX/lib -L$ICU_PREFIX/lib -L$READLINE_PREFIX/lib -L$PATH_ROOT/sys/lib/openssl -arch arm64 -Wl,-rpath,$PATH_ROOT/sys/lib/openssl -Wl,-rpath,$GETTEXT_PREFIX/lib -liconv"
	export CFLAGS="$SDK_FLAG -arch arm64"
	export CXXFLAGS="$SDK_FLAG -arch arm64"
	export PKG_CONFIG_PATH="$PATH_ROOT/sys/lib/openssl/pkgconfig:$LIBXML2_PREFIX/lib/pkgconfig:$LIBSXSLT_PREFIX/lib/pkgconfig:$ICU_PREFIX/lib/pkgconfig"
	./configure \
		--prefix="$PATH_ROOT/sys/php85" \
		--exec-prefix="$PATH_ROOT/sys/php85" \
		--bindir="$PATH_ROOT/sys/bin" \
		--sbindir="$PATH_ROOT/sys/bin" \
		--with-config-file-path="${CONFDIR}" \
		--with-config-file-scan-dir="${CONFDIR}/php85.d" \
		--with-fpm-user=omsy \
		--with-fpm-group=omsy \
		--enable-fpm \
		--enable-opcache \
		--enable-mbstring \
		--enable-bcmath \
		--enable-calendar \
		--enable-exif \
		--enable-ftp \
		--enable-intl \
		--enable-pcntl \
		--enable-shmop \
		--enable-soap \
		--enable-sockets \
		--enable-sysvmsg \
		--enable-sysvsem \
		--enable-sysvshm \
		--enable-gd \
		--with-freetype \
		--with-jpeg \
		--with-webp \
		--with-avif \
		--with-openssl \
		--with-zlib \
		--with-bz2=$BZIP2_PREFIX \
		--with-zip \
		--with-curl \
		--with-readline=$READLINE_PREFIX \
		--with-pdo-mysql=mysqlnd \
		--with-mysql-sock="$PATH_ROOT/share/run/mysql.sock" \
		--with-mysqli=mysqlnd \
		--with-pear \
		--with-gettext=$GETTEXT_PREFIX \
		--with-gmp \
		--with-mhash \
		--with-libxml \
		--with-xsl \
		--enable-simplexml \
		--enable-xml \
		--enable-xmlreader \
		--enable-xmlwriter \
		--disable-short-tags

elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	export LIBTOOL=libtool
	export LT_SYS_LIBRARY_PATH="$PATH_ROOT/sys/lib"
	export LD_LIBRARY_PATH="$PATH_ROOT/sys/lib/openssl:$LD_LIBRARY_PATH"
	export PKG_CONFIG_PATH="$PATH_ROOT/sys/lib/openssl/pkgconfig"
	export CPPFLAGS="-I$PATH_ROOT/sys/include"

	export LDFLAGS="-L$PATH_ROOT/sys/lib/openssl -L$PATH_ROOT/sys/lib -Wl,-rpath,$PATH_ROOT/sys/lib/openssl -Wl,-rpath,$PATH_ROOT/sys/lib"

	./configure \
		--prefix="${PREFIX}" \
		--exec-prefix="${PREFIX}" \
		--bindir="$PATH_ROOT/sys/bin" \
		--sbindir="$PATH_ROOT/sys/bin" \
		--with-config-file-path="${CONFDIR}" \
		--with-config-file-scan-dir="${CONFDIR}/php85.d" \
		--with-fpm-user=omsy \
		--with-fpm-group=omsy \
		--enable-fpm \
		--enable-opcache \
		--enable-mbstring \
		--enable-bcmath \
		--enable-calendar \
		--enable-exif \
		--enable-ftp \
		--enable-intl \
		--enable-pcntl \
		--enable-shmop \
		--enable-soap \
		--enable-sockets \
		--enable-sysvmsg \
		--enable-sysvsem \
		--enable-sysvshm \
		--enable-gd \
		--with-freetype \
		--with-jpeg \
		--with-webp \
		--with-avif \
		--with-openssl \
		--with-openssl-dir="$PATH_ROOT/sys" \
		--with-zlib \
		--with-bz2 \
		--with-zip \
		--with-curl \
		--with-readline \
		--with-pdo-mysql=mysqlnd \
		--with-mysql-sock="$PATH_ROOT/share/run/mysql.sock" \
		--with-mysqli=mysqlnd \
		--with-pear \
		--with-gettext \
		--with-gmp \
		--with-mhash \
		--with-libxml \
		--with-xsl \
		--with-iconv \
		--enable-simplexml \
		--enable-xml \
		--enable-xmlreader \
		--enable-xmlwriter \
		--disable-short-tags
fi

make -j"${JOBS}"
make install
if [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	echo "$PATH_ROOT/sys/lib" > /etc/ld.so.conf.d/omsy-extra.conf
	echo "$PATH_ROOT/sys/lib/openssl" >> /etc/ld.so.conf.d/omsy-extra.conf
	ldconfig
fi

cp $PATH_ROOT/sys/bin/php     $PATH_ROOT/sys/bin/php85
cp $PATH_ROOT/sys/bin/php-fpm $PATH_ROOT/sys/bin/php-fpm85
cp $PATH_ROOT/sys/bin/phpize  $PATH_ROOT/sys/bin/phpize85  2>/dev/null || true
cp $PATH_ROOT/sys/bin/php-config $PATH_ROOT/sys/bin/php-config85 2>/dev/null || true

ln -sf $PATH_ROOT/sys/bin/php85     $PATH_ROOT/sys/bin/php
ln -sf $PATH_ROOT/sys/bin/php-fpm85 $PATH_ROOT/sys/bin/php-fpm

mkdir -p "$EXTDIR"
if [ -d "${PREFIX}/lib/php/extensions" ]; then
	cp -r "${PREFIX}/lib/php/extensions"/*/* "$EXTDIR/" 2>/dev/null || true
fi
mkdir -p "${CONFDIR}/php85.d"

cp "${SRC_DIR}/php.ini-production" "${CONFDIR}/php85.ini"

cat >> "${CONFDIR}/php85.ini" <<EOF

;; ── OMSY overrides ──────────────────────────────────────────────────────────
date.timezone = America/Montreal
error_log     = $PATH_ROOT/share/logs/php/php85-error.log
upload_max_filesize = 64M
post_max_size       = 64M
memory_limit        = 256M
max_execution_time  = 60
opcache.enable      = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
extension_dir = $PATH_ROOT/sys/lib/php/8.4
EOF

ln -sf "${CONFDIR}/php85.ini" "${CONFDIR}/php.ini"

cat > "${CONFDIR}/php-fpm85.conf" <<EOF
[global]
pid       = $PATH_ROOT/share/run/php-fpm85.pid
error_log = $PATH_ROOT/share/logs/php/php-fpm85.log
daemonize = yes

[www85]
user  = omsy
group = omsy

listen = $PATH_ROOT/share/run/php-fpm85.sock
listen.owner = omsy
listen.group = omsy
listen.mode  = 0660

pm                   = dynamic
pm.max_children      = 20
pm.start_servers     = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests      = 500

php_admin_value[error_log]  = $PATH_ROOT/share/logs/php/php85-fpm-error.log
php_admin_flag[log_errors]  = on
EOF

cd "$PATH_ROOT/source/predis"
"$PATH_ROOT/sys/bin/phpize85"
./configure --with-php-config="${PATH_ROOT}/sys/bin/php-config85"
sudo make -j"${JOBS}"
sudo make install

cat >> "${PATH_ROOT}/share/config/php/php85.ini" <<EOF
session.save_handler = redis
session.save_path = "tcp://127.0.0.1:6379?auth=${REDIS_PASSWORD}"
extension=${PATH_ROOT}/sys/php85/lib/php/extensions/no-debug-non-zts-20240924/redis.so
EOF

cat > "${CONFDIR}/php-handlers/default.com.conf" <<EOF
# PHP-FPM 8.5.12
<FilesMatch "\.php\$">
	SetHandler "proxy:unix:${PATH_ROOT}/share/run/php-fpm85.sock|fcgi://localhost"
</FilesMatch>
EOF