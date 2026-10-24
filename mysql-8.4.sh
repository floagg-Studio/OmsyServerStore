#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

download_source \
	"mysql" \
	"https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.5.tar.gz"

dirs=(
	"$LIB_DIR/mysql"
	"$LOG_DIR/mysql"
	"$CONFIG_DIR/mysql"
	"$SHARE_DIR/data"
	"$RUN_DIR"
	"$OPENSSL_CERT"
	"$OPENSSL_PRIVATE"
	"$SOURCE_DIR/boost"
)
mkdir -p "${dirs[@]}"

SRC_DIR="$SOURCE_DIR/mysql"
BUILD_DIR="${SRC_DIR}/build"
PREFIX="$SYSTEM_DIR"
DATADIR="$SHARE_DIR/data"
LOGDIR="$LOG_DIR/mysql"
CONFDIR="$CONFIG_DIR/mysql"
MYSQL_ROOT_PASS="OmsyRoot$($BINARY_DIR/openssl rand -hex 8)"

# Vérification de l'installation OpenSSL
for f in \
    "$OPENSSL_DIR/include/openssl/ssl.h" \
    "$OPENSSL_DIR/include/openssl/opensslv.h" \
    "$OPENSSL_LIBDIR/libssl.3.dylib" \
    "$OPENSSL_LIBDIR/libcrypto.3.dylib" \
    "$OPENSSL_DIR/bin/openssl"
do
    if [[ ! -e "$f" ]]; then
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

rm -rf CMakeCache.txt CMakeFiles build.ninja

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

echo "=== Configuration SSL détectée ==="

grep -Ei 'WITH_SSL|OPENSSL.*(DIR|LIBRARY|VERSION)|CRYPTO_LIBRARY' \
    CMakeCache.txt || true

if grep -E '(/opt/homebrew|/usr/local/opt)' CMakeCache.txt \
    | grep -qi openssl; then
    echo "❌ CMake référence encore OpenSSL Homebrew."
    exit 1
fi

echo "✅ Vérification terminée."

ninja -j"${JOBS}"
sudo ninja install

if [[ "$OS" == "Ubuntu" ]]; then
	echo "$LIB_DIR/mysql" | sudo tee /etc/ld.so.conf.d/omsy-mysql.conf >/dev/null
	echo "$LIB_DIR/openssl" | sudo tee -a /etc/ld.so.conf.d/omsy-mysql.conf >/dev/null
	sudo ldconfig
fi

sudo chown omsy:omsy "$RUN_DIR"

#
export DYLD_LIBRARY_PATH="$LIB_DIR/mysql:$LIB_DIR/openssl:$DYLD_LIBRARY_PATH"
if [[ "$OS" == "Macos" ]]; then
	PROTOBUF_LIB=$(find "$LIB_DIR" -name "libprotobuf-lite*.dylib" | head -1)
	if [ -n "$PROTOBUF_LIB" ]; then
		echo "🔧 Correction du chemin de protobuf dans les exécutables MySQL..."
		for exe in "$BINARY_DIR/mysqld" "$BINARY_DIR/mysql" "$BINARY_DIR/mysqladmin" "$BINARY_DIR/mysqldump"; do
			if [ -f "$exe" ]; then
				sudo install_name_tool -change "@loader_path/libprotobuf-lite.24.4.0.dylib" "$PROTOBUF_LIB" "$exe" 2>/dev/null || true
			fi
		done
	else
		echo "⚠️ libprotobuf-lite.dylib introuvable, vérifiez l'installation."
	fi
fi
#

sudo env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$BINARY_DIR/openssl" req -x509 -nodes -days 3650 \
	-newkey rsa:4096 \
	-keyout "$OPENSSL_PRIVATE/omsy-sql.key" \
	-out "$OPENSSL_CERT/omsy-sql.crt" \
	-subj "/C=CA/ST=Quebec/L=Montreal/O=OMSY/CN=omsy-sql" || {
		echo "❌ Erreur lors de la génération du certificat SSL."
		exit 1
	}

sudo chmod 644 "$SHARE_DIR"/ssl/certs/*.crt
sudo chmod 600 "$SHARE_DIR"/ssl/private/*.key
sudo chown omsy:omsy "$SHARE_DIR"/ssl/certs/*.crt "$SHARE_DIR"/ssl/private/*.key

cat > "${CONFDIR}/my.cnf" <<EOF
[mysqld]
# Chemins
basedir         = $PATH_ROOT/sys
datadir         = $SHARE_DIR/data
socket          = $RUN_DIR/mysql.sock
pid-file        = $RUN_DIR/mysql.pid
log-error       = $LOG_DIR/mysql/error.log
general_log_file = $LOG_DIR/mysql/general.log
slow_query_log_file = $LOG_DIR/mysql/slow.log

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
ssl-ca      = $OPENSSL_CERT/omsy-sql.crt
ssl-cert    = $OPENSSL_CERT/omsy-sql.crt
ssl-key     = $OPENSSL_PRIVATE/omsy-sql.key

# Utilisateur
user        = omsy

[mysql]
socket      = $RUN_DIR/mysql.sock
default-character-set = utf8mb4

[client]
socket      = $RUN_DIR/mysql.sock
default-character-set = utf8mb4
EOF

sudo chown -R omsy:omsy "$DATADIR" "$LOGDIR"
sudo -u omsy env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$BINARY_DIR/mysqld" \
	--defaults-file="${CONFDIR}/my.cnf" \
	--initialize-insecure \
	--user=omsy

sudo -u omsy env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$BINARY_DIR/mysqld" \
	--defaults-file="${CONFDIR}/my.cnf" \
	--user=omsy \
	--daemonize

sleep 6

"$BINARY_DIR/mysql" --socket="$RUN_DIR/mysql.sock" -u root \
	-e "SELECT VERSION();" || echo "MySQL ne répond pas après démarrage."

"$BINARY_DIR/mysql" \
	--socket="$RUN_DIR/mysql.sock" \
	--user=root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS phpmyadmin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
SQL

"$BINARY_DIR/mysqladmin" \
	--socket="$RUN_DIR/mysql.sock" \
	--user=root \
	--password="${MYSQL_ROOT_PASS}" \
	shutdown || true
sleep 3

CRED_FILE="${CONFDIR}/.mysql_root_pass"
echo "$MYSQL_ROOT_PASS" > "$CRED_FILE"
chmod 600 "$CRED_FILE"
sudo chown omsy:omsy "$CRED_FILE"

echo "✅ MySQL installé. Mot de passe root dans : $CRED_FILE"