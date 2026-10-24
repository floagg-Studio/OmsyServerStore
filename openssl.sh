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

names=(
	openssl
)
urls=(
	"https://github.com/openssl/openssl/releases/download/openssl-3.5.1/openssl-3.5.1.tar.gz"
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
	
	# 4. Renommage vers le nom court (ex: openssl-3.5.1 -> openssl)
	mv "$PATH_ROOT/source/$dir" "$PATH_ROOT/source/${file}"
	
	# 5. Application des droits sur le dossier renommé
	chmod -R 755 "$PATH_ROOT/source/${file}"
done

dirs=(
	"$PATH_ROOT/sys/lib/openssl"
	"$PATH_ROOT/share/ssl/certs"
	"$PATH_ROOT/share/ssl/private"
)
mkdir -p "${dirs[@]}"

cd "${ROOT}/source/openssl"
if [[ "$(uname -s)" == "Darwin" ]]; then
	OPENSSL_TARGET="darwin64-arm64-cc"
	OPENSSL_EC_FLAG="enable-ec_nistp_64_gcc_128"
elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	ARCH=$(uname -m)
	if [ "$ARCH" = "x86_64" ]; then
		OPENSSL_TARGET="linux-x86_64"
		OPENSSL_EC_FLAG="enable-ec_nistp_64_gcc_128"
		PKG_LIB_ARCH="x86_64-linux-gnu"
	elif [ "$ARCH" = "aarch64" ]; then
		OPENSSL_TARGET="linux-aarch64"
		OPENSSL_EC_FLAG=""
		PKG_LIB_ARCH="aarch64-linux-gnu"
	fi

	export LDFLAGS="-Wl,-rpath,${PATH_ROOT}/sys/lib/openssl"
	export LD_LIBRARY_PATH="${PATH_ROOT}/sys/lib/openssl${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

./Configure \
	--prefix="${PATH_ROOT}/sys" \
	--openssldir="${PATH_ROOT}/share/config/openssl" \
	--libdir="${PATH_ROOT}/sys/lib/openssl" \
	shared \
	zlib \
	no-tests \
	enable-ec_nistp_64_gcc_128 \
	enable-tls1_3 \
	${OPENSSL_EC_FLAG:+$OPENSSL_EC_FLAG} \
	${OPENSSL_TARGET}
make -j"${JOBS}"
make install_sw install_ssldirs

ln -sf $PATH_ROOT/sys/bin/openssl /usr/local/bin/omsy-openssl 2>/dev/null || true
if [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	echo "$PATH_ROOT/sys/lib/openssl" > /etc/ld.so.conf.d/omsy-openssl.conf
	ldconfig
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
	sudo cp /etc/ssl/cert.pem $PATH_ROOT/share/config/openssl/cert.pem 2>/dev/null || \
	sudo cp /usr/local/etc/ca-certificates/cert.pem $PATH_ROOT/share/config/openssl/cert.pem 2>/dev/null || \
	echo "Attention: cert.pem non trouvé, vous devrez le fournir manuellement."
elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	cp /etc/ssl/certs/ca-certificates.crt $PATH_ROOT/share/config/openssl/cert.pem
fi

$PATH_ROOT/sys/bin/openssl req -x509 -nodes -days 3650 \
	-newkey rsa:4096 \
	-keyout $PATH_ROOT/share/ssl/private/defaults.key \
	-out $PATH_ROOT/share/ssl/certs/defaults.crt \
	-subj "/C=CA/ST=Quebec/L=Montreal/O=OMSY/CN=defaults"

chmod 644 $PATH_ROOT/share/ssl/certs/*.crt
chmod 600 $PATH_ROOT/share/ssl/private/*.key
chown omsy:omsy $PATH_ROOT/share/ssl/certs/*.crt $PATH_ROOT/share/ssl/private/*.key