#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

find ./ -type f -name "*.sh" ! -name "install.sh" -exec sed "${SED_INPLACE[@]}" \
	-e "s|PATH_ROOT=/omsy|PATH_ROOT=$PATH_ROOT|g" \
	-e "s|PATH_ROOT=\"/omsy\"|PATH_ROOT=\"$PATH_ROOT\"|g" \
	-e "s|PATH_ROOT='/omsy'|PATH_ROOT='$PATH_ROOT'|g" {} +

if [[ "$(uname -s)" == "Darwin" ]]; then
	echo "Installation pour macOS"
	if [ "$EUID" -ne 0 ]; then
		if ! command -v brew &> /dev/null; then
			echo "Homebrew n'est pas installé. Installation..."
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		fi

		brew update
		brew install \
			cmake ninja pkg-config autoconf automake libtool \
			bison flex re2c \
			ncurses readline \
			zlib libxml2 libxslt \
			curl \
			libpng libjpeg freetype webp libavif \
			oniguruma zip sqlite gdbm bzip2 xz libffi libedit \
			icu4c \
			openldap krb5 \
			pcre2 \
			expat \
			gmp \
			wget git unzip \
			ca-certificates \
			perl python3 \
			doxygen
	fi

	if ! dscl . -list /Users | grep -q "^omsy$"; then
		sudo sysadminctl -addUser omsy -fullName "OMSY User" -home /var/empty -shell /usr/bin/false || \
		sudo dscl . -create /Users/omsy UniqueID 550
	fi

	if ! dscl . -list /Groups | grep -q "^omsy$"; then
		sudo dscl . -create /Groups/omsy
		sudo dscl . -create /Groups/omsy PrimaryGroupID 550
	fi

elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	echo "Installation pour Ubuntu"

	apt-get update -y
	apt-get install -y \
		build-essential gcc g++ make cmake ninja-build \
		pkg-config autoconf automake libtool \
		bison flex re2c \
		libncurses5-dev libncursesw5-dev \
		libreadline-dev \
		libssl-dev \
		zlib1g-dev \
		libxml2-dev \
		libxslt1-dev \
		libcurl4-openssl-dev \
		libpng-dev \
		libjpeg-dev \
		libfreetype6-dev \
		libwebp-dev \
		libavif-dev \
		libonig-dev \
		libzip-dev \
		libsqlite3-dev \
		libgdbm-dev \
		libdb5.3-dev \
		libbz2-dev \
		liblzma-dev \
		libffi-dev \
		libedit-dev \
		libpam0g-dev \
		libcap-dev \
		libsystemd-dev \
		libaio-dev \
		libnuma-dev \
		libmecab-dev \
		libicu-dev \
		libtirpc-dev \
		libldap2-dev \
		libsasl2-dev \
		libkrb5-dev \
		libgeoip-dev \
		libgd-dev \
		libmaxminddb-dev \
		libpcre2-dev \
		libpcre3-dev \
		libexpat1-dev \
		libapr1-dev \
		libaprutil1-dev \
		uuid-dev \
		libgmp-dev \
		wget curl git unzip tar xz-utils \
		ca-certificates \
		perl \
		python3 \
		doxygen \
		lsb-release \
		apt-transport-https \
		gnupg2 \
		patchelf

	if ! getent group omsy >/dev/null; then
		groupadd --system omsy
	fi
	if ! id omsy >/dev/null 2>&1; then
		useradd --system \
			--gid omsy \
			--no-create-home \
			--shell "$(command -v nologin || echo /sbin/nologin)" \
			--comment "OMSY services user" \
			omsy
	fi
fi

echo "Téléchargement des librairie pour les compilation"
names=(
	predis
	apr
	apr-util
	pcre2
	nghttp2
	zlib
)
urls=(
	"https://pecl.php.net/get/redis-6.3.0.tgz"
	"https://archive.apache.org/dist/apr/apr-1.7.6.tar.gz"
	"https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.gz"
	"https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.46/pcre2-10.46.tar.gz"
	"https://github.com/nghttp2/nghttp2/releases/download/v1.67.1/nghttp2-1.67.1.tar.gz"
	"https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
)

download_source \
	"predis" \
	"https://pecl.php.net/get/redis-6.3.0.tgz"

download_source \
	"apr" \
	"https://archive.apache.org/dist/apr/apr-1.7.6.tar.gz"

download_source \
	"apr-util" \
	"https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.gz"

download_source \
	"pcre2" \
	"https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.46/pcre2-10.46.tar.gz"

download_source \
	"nghttp2" \
	"https://github.com/nghttp2/nghttp2/releases/download/v1.67.1/nghttp2-1.67.1.tar.gz"

download_source \
	"zlib" \
	"https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"

dirs=(
	"$PATH_ROOT/sys"
	"$PATH_ROOT/sys/lib"
	"$PATH_ROOT/sys/bin"
	"$PATH_ROOT/sys/module"
	"$PATH_ROOT/share"
	"$PATH_ROOT/share/config"
	"$PATH_ROOT/share/logs"
	"$PATH_ROOT/share/empty"
	"$PATH_ROOT/usr"

	# "/usr/share/empty"
)
mkdir -p "${dirs[@]}"
chown -R omsy:omsy "$PATH_ROOT"
chmod -R 755 "$PATH_ROOT"

# echo "Installation du serveur de base"
# sh "openssl-3.5.sh"
# echo sh "vsftpd.sh"
# echo sh "nodejs.sh"

# echo "Installation des base de donées"
# sh "mysql-8.4.sh"
# sh "redis.sh"

# echo "Installation des serveur web"
# sh "nginx.sh"
# sh "apache.sh"

# echo "Installation des extention de codes"
# sh "php85.sh"
# sh "phpmyadmin.sh"

echo "Création de fichier pour omsyctl"

cat > "$PATH_ROOT/share/config/omsyctl/omsy.conf" <<EOF
path="$PATH_ROOT"
confdir="$PATH_ROOT/share/config/omsystackctl/"
EOF

cat > "$PATH_ROOT/share/config/omsyctl/openssl.conf" <<EOF
label="OpenSSL"
shell="$PATH_ROOT/src/services/openssl.sh"
bins="openssl"
EOF

cat > "$PATH_ROOT/share/config/omsyctl/mysql.conf" <<EOF
label="MySQL / MariaDB"
shell="$PATH_ROOT/source/mysql.sh"
bins="mysqld","mariadbd","mysql"
start="$PATH_ROOT/sys/bin/mysqld --defaults-file=$PATH_ROOT/share/config/mysql/my.cnf --user=$USER"
stop="pkill -TERM mysqld_safe", "$PATH_ROOT/sys/bin/mysqladmin --socket=$PATH_ROOT/share/run/mysql.sock -u root shutdown"
EOF

cat > "$PATH_ROOT/share/config/omsyctl/redis.conf" <<EOF
label="Redis"
shell="$PATH_ROOT/src/services/redis.sh"
bins="redis-server","redis"
start="$PATH_ROOT/sys/bin/redis-server $PATH_ROOT/share/config/redis/redis.conf --daemonize no"
stop="$PATH_ROOT/sys/bin/redis-cli shutdown"
EOF

cat > "$PATH_ROOT/share/config/omsyctl/nginx.conf" <<EOF
label="Nginx"
shell="$PATH_ROOT/src/services/nginx.sh"
bins="nginx"
start="$PATH_ROOT/sys/bin/nginx -c $PATH_ROOT/share/config/nginx/nginx.conf"
stop="kill -QUIT \$(cat $PATH_ROOT/share/run/nginx.pid)"
EOF

cat > "$PATH_ROOT/share/config/omsyctl/apache.conf" <<EOF
label="Apache"
shell="$PATH_ROOT/src/services/apache.sh"
bins="apache2","httpd"
start="$PATH_ROOT/sys/bin/apachectl -f $PATH_ROOT/share/config/apache/httpd.conf -k start"
stop="$PATH_ROOT/sys/bin/apachectl -f $PATH_ROOT/share/config/apache/httpd.conf -k stop"
EOF

cat > "$PATH_ROOT/share/config/omsyctl/phpfpm85.conf" <<EOF
label="PHP-FPM85"
shell="$PATH_ROOT/src/services/php85.sh"
bins="php-fpm","php-fpm85","php8.5-fpm"
start="$PATH_ROOT/sys/bin/php-fpm85 --fpm-config $PATH_ROOT/share/config/php/php-fpm85.conf"
stop="kill \$(cat $PATH_ROOT/share/run/php-fpm85.pid)"
EOF