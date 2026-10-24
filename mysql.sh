#!/bin/bash
set -e

PATH_ROOT="/Users/julie/Documents/OmsyServer"

if [[ "$(uname -s)" == "Darwin" ]]; then
	OS="Macos"
	JOBS=$(sysctl -n hw.ncpu)
else
	OS="Ubuntu"
	JOBS=$(nproc)
fi

echo "$PATH_ROOT"

# ---------------------------------------------------------------
# Téléchargement des sources (ignoré si déjà présentes)
# ---------------------------------------------------------------
names=(
	mysql
)
urls=(
	"https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.5.tar.gz"
)

mkdir -p "$PATH_ROOT/source"

for i in "${!names[@]}"; do
	file="${names[$i]}"
	url="${urls[$i]}"
	filename=$(basename "${url}")

	echo "--- Traitement de ${file} ---"

	if [ -d "$PATH_ROOT/source/${file}" ] && [ -f "$PATH_ROOT/source/${file}/CMakeLists.txt" ]; then
		echo "Sources déjà présentes, téléchargement ignoré."
		continue
	fi

	wget -q --show-progress "${url}" -O "$PATH_ROOT/source/$filename"

	tmp=$(mktemp -d -p "$PATH_ROOT/source")
	tar -xf "$PATH_ROOT/source/$filename" -C "$tmp"

	dir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)

	rm -rf "$PATH_ROOT/source/${file}"
	mv "$dir" "$PATH_ROOT/source/${file}"
	rm -rf "$tmp"

	chmod -R 755 "$PATH_ROOT/source/${file}"
done

# ---------------------------------------------------------------
# Dossiers
# ---------------------------------------------------------------
dirs=(
	"$PATH_ROOT/sys/lib/mysql"
	"$PATH_ROOT/share/logs/mysql"
	"$PATH_ROOT/share/config/mysql"
	"$PATH_ROOT/share/data"
	"$PATH_ROOT/share/run"
	"$PATH_ROOT/share/ssl/certs"
	"$PATH_ROOT/share/ssl/private"
	"$PATH_ROOT/source/boost"
)
mkdir -p "${dirs[@]}" 2>/dev/null || sudo mkdir -p "${dirs[@]}"

SRC_DIR="$PATH_ROOT/source/mysql"
BUILD_DIR="${SRC_DIR}/build"
PREFIX="$PATH_ROOT/sys"
DATADIR="$PATH_ROOT/share/data"
LOGDIR="$PATH_ROOT/share/logs/mysql"
CONFDIR="$PATH_ROOT/share/config/mysql"
MYSQL_ROOT_PASS="OmsyRoot$(openssl rand -hex 8)"

# ---------------------------------------------------------------
# OpenSSL 3 maison : vérifications
# ---------------------------------------------------------------
OPENSSL_DIR="$PATH_ROOT/sys"
OPENSSL_LIBDIR="$PATH_ROOT/sys/lib/openssl"

for f in \
	"$OPENSSL_DIR/lib/libssl.dylib" \
	"$OPENSSL_DIR/lib/libcrypto.dylib" \
	"$OPENSSL_DIR/include/openssl/ssl.h"; do
	if [ ! -e "$f" ]; then
		echo "❌ Fichier OpenSSL introuvable : $f"
		exit 1
	fi
done

# Nettoyage total du build (cache CMake + fichiers root d'un ancien 'sudo ninja')
sudo rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ---------------------------------------------------------------
# Configuration CMake
# ---------------------------------------------------------------
EXTRA_CMAKE=()
if [[ "$OS" == "Macos" ]]; then
	export PKG_CONFIG_PATH=""
	# Empêche CMake d'aller piocher OpenSSL 4 (ou autre) dans Homebrew
	EXTRA_CMAKE+=(
		-DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local"
		-DCMAKE_FIND_FRAMEWORK=LAST
	)
fi

cmake .. \
	-DCMAKE_INSTALL_PREFIX="${PREFIX}" \
	-DCMAKE_PREFIX_PATH="$PATH_ROOT/sys" \
	-DMYSQL_DATADIR="${DATADIR}" \
	-DSYSCONFDIR="${CONFDIR}" \
	-DMYSQL_UNIX_ADDR="$PATH_ROOT/share/run/mysql.sock" \
	-DCMAKE_BUILD_TYPE=Release \
	-DWITH_SSL="${OPENSSL_DIR}" \
	-DOPENSSL_ROOT_DIR="${OPENSSL_DIR}" \
	-DOPENSSL_INCLUDE_DIR="${OPENSSL_DIR}/include" \
	-DWITH_ZLIB=bundled \
	-DWITH_ICU=bundled \
	-DWITH_LZ4=bundled \
	-DWITH_LIBEVENT=bundled \
	-DWITH_PROTOBUF=bundled \
	-DWITH_RAPIDJSON=bundled \
	-DWITH_FIDO=bundled \
	-DDOWNLOAD_BOOST=1 \
	-DWITH_BOOST="$PATH_ROOT/source/boost" \
	-DENABLED_LOCAL_INFILE=1 \
	-DWITH_MYSQLX=1 \
	-DDEFAULT_CHARSET=utf8mb4 \
	-DDEFAULT_COLLATION=utf8mb4_unicode_ci \
	-DMYSQL_TCP_PORT=3306 \
	-DINSTALL_SBINDIR=bin \
	-DINSTALL_BINDIR=bin \
	-DINSTALL_LIBDIR=lib/mysql \
	-DINSTALL_PLUGINDIR=lib/mysql/plugin \
	-DINSTALL_INCLUDEDIR=include/mysql \
	-DINSTALL_SHAREDIR=share/mysql \
	-DINSTALL_MANDIR=share/man \
	-DINSTALL_DOCDIR=share/doc/mysql \
	-DWITH_UNIT_TESTS=OFF \
	-DWITHOUT_SERVER=OFF \
	"${EXTRA_CMAKE[@]}" \
	-G Ninja

# Vérifie que CMake a bien pris TON OpenSSL et pas Homebrew
if grep -E "^(OPENSSL_LIBRARY|CRYPTO_LIBRARY)" CMakeCache.txt | grep -qi "Cellar\|homebrew"; then
	echo "❌ CMake utilise encore OpenSSL Homebrew :"
	grep -E "^(OPENSSL_LIBRARY|CRYPTO_LIBRARY)" CMakeCache.txt
	exit 1
fi

# Compilation sans sudo, installation avec sudo
ninja -j"${JOBS}"
sudo ninja install

if [[ "$OS" == "Ubuntu" ]]; then
	echo "$PATH_ROOT/sys/lib/mysql" | sudo tee /etc/ld.so.conf.d/omsy-mysql.conf >/dev/null
	echo "$PATH_ROOT/sys/lib/openssl" | sudo tee -a /etc/ld.so.conf.d/omsy-mysql.conf >/dev/null
	sudo ldconfig
fi

sudo chown omsy:omsy "$PATH_ROOT/share/run"

# ---------------------------------------------------------------
# Certificat SSL + correctifs macOS
# ---------------------------------------------------------------
export DYLD_LIBRARY_PATH="$PATH_ROOT/sys/lib/mysql:$PATH_ROOT/sys/lib/openssl:$DYLD_LIBRARY_PATH"

if [[ "$OS" == "Macos" ]]; then
	PROTOBUF_LIB=$(find "$PATH_ROOT/sys/lib" -name "libprotobuf-lite*.dylib" | head -1)
	if [ -n "$PROTOBUF_LIB" ]; then
		echo "🔧 Correction du chemin de protobuf dans les exécutables MySQL..."
		for exe in "$PATH_ROOT/sys/bin/mysqld" "$PATH_ROOT/sys/bin/mysql" "$PATH_ROOT/sys/bin/mysqladmin" "$PATH_ROOT/sys/bin/mysqldump"; do
			if [ -f "$exe" ]; then
				sudo install_name_tool -change "@loader_path/libprotobuf-lite.24.4.0.dylib" "$PROTOBUF_LIB" "$exe" 2>/dev/null || true
			fi
		done
	else
		echo "⚠️ libprotobuf-lite.dylib introuvable, vérifiez l'installation."
	fi
fi

sudo env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$PATH_ROOT/sys/bin/openssl" req -x509 -nodes -days 3650 \
	-newkey rsa:4096 \
	-keyout "$PATH_ROOT/share/ssl/private/omsy-sql.key" \
	-out "$PATH_ROOT/share/ssl/certs/omsy-sql.crt" \
	-subj "/C=CA/ST=Quebec/L=Montreal/O=OMSY/CN=omsy-sql" || {
		echo "❌ Erreur lors de la génération du certificat SSL."
		exit 1
	}

sudo chmod 644 "$PATH_ROOT"/share/ssl/certs/*.crt
sudo chmod 600 "$PATH_ROOT"/share/ssl/private/*.key
sudo chown omsy:omsy "$PATH_ROOT"/share/ssl/certs/*.crt "$PATH_ROOT"/share/ssl/private/*.key

# ---------------------------------------------------------------
# my.cnf
# ---------------------------------------------------------------
cat > "${CONFDIR}/my.cnf" <<EOF
[mysqld]
# Chemins
basedir         = $PATH_ROOT/sys
datadir         = $PATH_ROOT/share/data
socket          = $PATH_ROOT/share/run/mysql.sock
pid-file        = $PATH_ROOT/share/run/mysql.pid
log-error       = $PATH_ROOT/share/logs/mysql/error.log
general_log_file = $PATH_ROOT/share/logs/mysql/general.log
slow_query_log_file = $PATH_ROOT/share/logs/mysql/slow.log

# Réseau
port            = 3306
bind-address    = 127.0.0.1

# Charset
character-set-server  = utf8mb4
collation-server      = utf8mb4_unicode_ci

# Performance (MySQL 8.4)
innodb_buffer_pool_size        = 256M
innodb_redo_log_capacity       = 128M
innodb_flush_log_at_trx_commit = 1
max_connections                = 150
thread_cache_size              = 8
tmp_table_size                 = 32M
max_heap_table_size            = 32M

# SSL
ssl-ca      = $PATH_ROOT/share/ssl/certs/omsy-sql.crt
ssl-cert    = $PATH_ROOT/share/ssl/certs/omsy-sql.crt
ssl-key     = $PATH_ROOT/share/ssl/private/omsy-sql.key

# Utilisateur
user        = omsy

[mysql]
socket      = $PATH_ROOT/share/run/mysql.sock
default-character-set = utf8mb4

[client]
socket      = $PATH_ROOT/share/run/mysql.sock
default-character-set = utf8mb4
EOF

# ---------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------
sudo chown -R omsy:omsy "$DATADIR" "$LOGDIR"

# --initialize exige un datadir vide
if [ -n "$(ls -A "$DATADIR" 2>/dev/null)" ]; then
	echo "❌ $DATADIR n'est pas vide : vide-le avant l'initialisation."
	exit 1
fi

sudo -u omsy env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$PATH_ROOT/sys/bin/mysqld" \
	--defaults-file="${CONFDIR}/my.cnf" \
	--initialize-insecure \
	--user=omsy

if grep -i "\[ERROR\]" "$LOGDIR/error.log" | tail -5 | grep -q .; then
	grep -i "\[ERROR\]" "$LOGDIR/error.log" | tail -5
	echo "Des erreurs ont été détectées lors de l'init — vérifiez le log."
fi

sudo -u omsy env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$PATH_ROOT/sys/bin/mysqld" \
	--defaults-file="${CONFDIR}/my.cnf" \
	--user=omsy \
	--daemonize

sleep 6

"$PATH_ROOT/sys/bin/mysql" --socket="$PATH_ROOT/share/run/mysql.sock" -u root \
	-e "SELECT VERSION();" || echo "MySQL ne répond pas après démarrage."

"$PATH_ROOT/sys/bin/mysql" \
	--socket="$PATH_ROOT/share/run/mysql.sock" \
	--user=root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS phpmyadmin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
SQL

"$PATH_ROOT/sys/bin/mysqladmin" \
	--socket="$PATH_ROOT/share/run/mysql.sock" \
	--user=root \
	--password="${MYSQL_ROOT_PASS}" \
	shutdown || true
sleep 3

CRED_FILE="${CONFDIR}/.mysql_root_pass"
echo "$MYSQL_ROOT_PASS" > "$CRED_FILE"
chmod 600 "$CRED_FILE"
sudo chown omsy:omsy "$CRED_FILE"

echo "✅ MySQL installé. Mot de passe root dans : $CRED_FILE"