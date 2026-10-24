#!/bin/bash
set -e

PATH_ROOT="/Users/julie/Documents/OmsyServer"
ROOT=$(pwd)

if [[ "$(uname -s)" == "Darwin" ]]; then
	OS="Macos"
	JOBS=$(sysctl -n hw.ncpu)
else
	OS="Ubuntu"
	JOBS=$(nproc)
fi

echo $PATH_ROOT

names=(
	redis
)
urls=(
	"https://download.redis.io/releases/redis-7.2.6.tar.gz"
)

for i in "${!names[@]}"; do
	file="${names[$i]}"
	url="${urls[$i]}"
	filename=$(basename "${url}")
	
	echo "--- Traitement de ${file} ---"
	
	# 1. Téléchargement sécurisé
	wget -q --show-progress "${url}" -O "$PATH_ROOT/source/$filename"
	
	# 2. Détermination dynamique du dossier racine créé à l'extraction
	dir=$(tar -tf "$PATH_ROOT/source/$filename" | head -1 | cut -d/ -f1)
	
	# 3. Extraction forcée à l'intérieur du dossier 'source'
	tar -xf "$PATH_ROOT/source/$filename" -C "$PATH_ROOT/source/"

	echo $dir
	
	# 4. Renommage vers le nom court (ex: openssl-3.5.1 -> openssl)
	mv "$PATH_ROOT/source/$dir" "$PATH_ROOT/source/${file}"
	
	# 5. Application des droits sur le dossier renommé
	chmod -R 755 "$PATH_ROOT/source/${file}"
done


dirs=(
	"$PATH_ROOT/share/config/redis"
	"$PATH_ROOT/share/logs/redis"
	"$PATH_ROOT/share/data/redis"
	"$PATH_ROOT/share/run/redis"
)
mkdir -p "${dirs[@]}"

PREFIX="$PATH_ROOT/sys"
CONFDIR="$PATH_ROOT/share/config/redis"
LOGDIR="$PATH_ROOT/share/logs/redis"
DATADIR="$PATH_ROOT/share/data/redis"
RUNDIR="$PATH_ROOT/share/run"
BUILD_TLS="no" # ???

cd "${ROOT}/source/redis"
if [[ "$OS" == "Macos" ]]; then
	make -j"${JOBS}" \
		PREFIX="${PREFIX}" \
		BUILD_TLS="${BUILD_TLS}" \
		CFLAGS="-arch arm64 -I${PREFIX}/include" \
		LDFLAGS="-arch arm64 -L${PREFIX}/lib/openssl -Wl,-rpath,${PREFIX}/lib/openssl" \
		OPENSSL_PREFIX="$ROOT/src/openssl"
elif [[ "$OS" == "Ubuntu" ]]; then
	make -j"${JOBS}" \
		PREFIX="${PREFIX}" \
		BUILD_TLS="${BUILD_TLS}" \
		OPENSSL_PREFIX="$ROOT/src/openssl"
fi

make PREFIX="${PREFIX}" install

mkdir -p "${CONFDIR}" "${LOGDIR}" "${DATADIR}" "${RUNDIR}"
sudo chown -R omsy:omsy "${LOGDIR}" "${DATADIR}" "${RUNDIR}"

REDIS_PASSWORD=$(openssl rand -hex 24)
echo "Mot de passe Redis généré : ${REDIS_PASSWORD}"
echo "${REDIS_PASSWORD}" > "${CONFDIR}/redis_password.txt"
sudo chown omsy:omsy "${CONFDIR}/redis_password.txt"
chmod 600 "${CONFDIR}/redis_password.txt"

cat > "${CONFDIR}/redis.conf" <<EOF
# =============================================================================
# redis.conf — Redis OMSY
# =============================================================================
 
# N'écoute que sur localhost : nginx/Apache ne parlent pas à Redis directement,
# c'est votre application (PHP, Node, ...) qui s'y connecte en local.
bind 127.0.0.1 -::1
port 6379
protected-mode yes
 
requirepass ${REDIS_PASSWORD}
 
daemonize no
supervised systemd
pidfile ${RUNDIR}/redis.pid
 
# Logs
loglevel notice
logfile ${LOGDIR}/redis.log
 
# Persistance (RDB)
dir ${DATADIR}
save 900 1
save 300 10
save 60 10000
dbfilename dump.rdb
 
# Persistance (AOF) — recommandé si Redis sert de source de vérité (sessions, etc.)
appendonly yes
appendfilename "appendonly.aof"
appenddirname "aof"
appendfsync everysec
 
# Limites mémoire (à adapter selon la RAM disponible)
maxmemory 256mb
maxmemory-policy allkeys-lru
 
# Utilisateur d'exécution
user omsy
 
EOF

if [[ "${BUILD_TLS}" == "yes" ]]; then
cat >> "${CONFDIR}/redis.conf" <<EOF
# TLS (désactivé par défaut, décommentez si Redis doit être exposé au-delà de localhost)
# port 0
# tls-port 6380
# tls-cert-file ${PATH_ROOT}/share/ssl/certs/redis.crt
# tls-key-file  ${PATH_ROOT}/share/ssl/private/redis.key
# tls-ca-cert-file ${PATH_ROOT}/share/ssl/certs/ca.crt
EOF
fi

echo ""
echo "=== Installation terminée ==="
echo "Binaire      : ${PREFIX}/bin/redis-server"
echo "Config       : ${CONFDIR}/redis.conf"
echo "Logs         : ${LOGDIR}/redis.log"
echo "Données      : ${DATADIR}"
echo "Mot de passe : ${CONFDIR}/redis_password.txt"