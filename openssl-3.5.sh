#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

download_source \
	"openssl" \
	"https://github.com/openssl/openssl/releases/download/openssl-3.5.1/openssl-3.5.1.tar.gz"

dirs=(
	"$LIB_DIR/openssl"
	"$OPENSSL_CERT"
	"$OPENSSL_PRIVATE"
)
mkdir -p "${dirs[@]}"

cd "${PATH_ROOT}/source/openssl"
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

	export LDFLAGS="-Wl,-rpath,${LIB_DIR}/openssl"
	export LD_LIBRARY_PATH="${LIB_DIR}/openssl${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

./Configure \
	--prefix="${SYSTEM_DIR}" \
	--openssldir="${CONFIG_DIR}/openssl" \
	--libdir="${LIB_DIR}/openssl" \
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
	echo "$LIB_DIR/openssl" > /etc/ld.so.conf.d/omsy-openssl.conf
	ldconfig
fi

# sudo ln -sf "$PATH_ROOT/sys/lib/openssl/libssl.3.dylib" "$PATH_ROOT/sys/lib/libssl.dylib"
# sudo ln -sf "$PATH_ROOT/sys/lib/openssl/libcrypto.3.dylib" "$PATH_ROOT/sys/lib/libcrypto.dylib"
# ls -l "$PATH_ROOT/sys/lib/libssl.dylib" "$PATH_ROOT/sys/lib/libcrypto.dylib"

# cd /Users/julie/Documents/OmsyServer/sys/lib
# sudo cp -p "$PATH_ROOT/sys/lib/openssl/libssl.3.dylib" "$PATH_ROOT/sys/lib/openssl/libcrypto.3.dylib" "$PATH_ROOT/sys/lib"
# sudo ln -s "$PATH_ROOT/sys/lib/libssl.3.dylib" "$PATH_ROOT/sys/lib/libssl.dylib"
# sudo ln -s "$PATH_ROOT/sys/lib/libcrypto.3.dylib" "$PATH_ROOT/sys/lib/libcrypto.dylib"

if [[ "$(uname -s)" == "Darwin" ]]; then
	sudo cp /etc/ssl/cert.pem $CONFIG_DIR/openssl/cert.pem 2>/dev/null || \
	sudo cp /usr/local/etc/ca-certificates/cert.pem $CONFIG_DIR/openssl/cert.pem 2>/dev/null || \
	echo "Attention: cert.pem non trouvé, vous devrez le fournir manuellement."
elif [[ -f /etc/os-release && $(grep -c "Ubuntu" /etc/os-release) -gt 0 ]]; then
	cp /etc/ssl/certs/ca-certificates.crt $CONFIG_DIR/openssl/cert.pem
fi

$PATH_ROOT/sys/bin/openssl req -x509 -nodes -days 3650 \
	-newkey rsa:4096 \
	-keyout $OPENSSL_PRIVATE/defaults.key \
	-out $OPENSSL_CERT/defaults.crt \
	-subj "/C=CA/ST=Quebec/L=Montreal/O=OMSY/CN=defaults"

chmod 644 $OPENSSL_CERT/*.crt
chmod 600 $OPENSSL_PRIVATE/*.key
chown omsy:omsy $OPENSSL_CERT/*.crt $OPENSSL_PRIVATE/*.key

echo "Cp, ln, ln, ls"
cd "$PATH_ROOT/sys/lib"
sudo cp -p openssl/libssl.3.dylib openssl/libcrypto.3.dylib .
sudo ln -s libssl.3.dylib libssl.dylib
sudo ln -s libcrypto.3.dylib libcrypto.dylib
ls -l libssl* libcrypto*
echo "yerminé"