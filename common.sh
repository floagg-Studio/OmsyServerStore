#!/bin/bash
set -e

PATH_ROOT="/Users/julie/Documents/OmsyServer"
SOURCE_DIR="$PATH_ROOT/source"

SYSTEM_DIR="$PATH_ROOT/sys"
BINARY_DIR="$SYSTEM_DIR/bin"
LIB_DIR="$SYSTEM_DIR/lib"

USER_DIR="$PATH_ROOT/usr"
SHARE_DIR="$PATH_ROOT/share"

RUN_DIR="$SHARE_DIR/run"
LOG_DIR="$SHARE_DIR/logs"
CONFIG_DIR="$SHARE_DIR/config"

OPENSSL_DIR="$PATH_ROOT/sys"
OPENSSL_LIBDIR="$PATH_ROOT/sys/lib/openssl"

OPENSSL_CERT="$SHARE_DIR/ssl/certs"
OPENSSL_PRIVATE="$SHARE_DIR/ssl/private"

# Détection du système d'exploitation
if [[ "$(uname -s)" == "Darwin" ]]; then
	OS="Macos"
	JOBS=$(sysctl -n hw.ncpu)
	SED_INPLACE=(-i '')
else
	OS="Ubuntu"
	JOBS=$(nproc)
	SED_INPLACE=(-i)
fi

mkdir -p "$SOURCE_DIR"

echo "Système : $OS"
echo "Processeurs : $JOBS"
echo "Dossier : $PATH_ROOT"

# ---------------------------------------------------------------
# Téléchargement et extraction des sources
# ---------------------------------------------------------------
download_source() {
	local name="$1"
	local url="$2"
	local marker="${3:-CMakeLists.txt}"

	local archive
	local tmp
	local dir

	archive="$SOURCE_DIR/$(basename "$url")"

	# Télécharger les sources
	wget -q --show-progress "${url}" -O "$archive"

	# Créer un dossier temporaire compatible macOS et Linux
	tmp=$(mktemp -d "$SOURCE_DIR/.tmp.XXXXXX")

	# Extraire les sources
	tar -xf "$archive" -C "$tmp"

	# Identifier le dossier extrait
	dir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print -quit)

	# Remplacer les anciennes sources incomplètes
	rm -rf "$SOURCE_DIR/$name"
	mv "$dir" "$SOURCE_DIR/$name"
	rm -rf "$tmp"

	# Appliquer les permissions
	chmod -R 755 "$SOURCE_DIR/$name"
}