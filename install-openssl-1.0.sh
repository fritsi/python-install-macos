#!/usr/bin/env bash

set -euo pipefail

# The directory in which this script lives in
_scripts_dir="$(cd "$(dirname "$0")" && pwd)"

export _temp_dir="/tmp/openssl-1.0.2u"

_install_dir="$HOME/Library/openssl-1.0.2u"

####################################################################################################
############################################ DESCRIPTION ###########################################
####################################################################################################
#
# Python 3.4 is NOT compatible with OpenSSL 1.1 hence we need to install Open SSL 1.0 for it
# Since Open SSL 1.0 is EOL, we cannot install it via brew
# However we can install it via this script
#
# The script will install OpenSSL 1.0 into $HOME/Library/openssl-1.0.2u
# If you want to change this you have to manually edit the script and replace all occurrences
# After you've done that, you also have to replace the same string in search-libraries.sh
#
####################################################################################################

# Checking whether we are running the script on macOS or not
if [[ "$(uname)" != "Darwin" ]]; then
    echo >&2 "[ERROR] This script must be run on macOS"
    echo >&2 ""
    exit 1
fi

# Checking the architecture type (Intel vs. Apple Silicon)
if [[ "$(uname -m)" == "x86_64" ]]; then
    _is_apple_silicon=0
elif [[ "$(uname -m)" == "arm64" ]]; then
    _is_apple_silicon=1
else
    echo >&2 "[ERROR] Unsupported OS: $(uname) ($(uname -m))"
    echo >&2 ""
    exit 1
fi

# This method will be invoked when we exit from the script
# This will eventually delete our temporary directory
function deleteTempDirectory() {
    echo ""
    echo "[EXIT] Deleting $_temp_dir"

    rm -rf "$_temp_dir"
}

export -f deleteTempDirectory

trap "deleteTempDirectory" EXIT

# Working directory already exists, deleting it
if [[ -d "$_temp_dir" ]]; then
    rm -rf "$_temp_dir"
fi

# Creating the temporary folder where we'll download the source and do the compilation
mkdir -p "$_temp_dir"

echo "[install-openssl-1.0] Downloading the OpenSSL 1.0 source code"
echo ""

# Downloading the OpenSSL source code
wget "https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz" -O "$_temp_dir/openssl-1.0.2u.tar.gz"

cd "$_temp_dir"

echo "[install-openssl-1.0] Extracting the OpenSSL 1.0 source code"
echo ""

# Extracting the OpenSSL source code
tar zxvf "openssl-1.0.2u.tar.gz"

echo ""

cd "openssl-1.0.2u"

# Creating the destination directory
mkdir -p "$_install_dir"

# This is not a Python compilation (needed for search-libraries.sh)
# shellcheck disable=SC2034
_python_compile=0

# Searching for the necessary libraries to compile Python
source "$_scripts_dir/search-libraries.sh"

# These are needed, so the gcc coming from brew does not get picked-up
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export LD="/usr/bin/g++"

# OpenSSL 1.0 does not have Apple Silicon support by default, so let's add it
if [[ "$_is_apple_silicon" -eq 1 ]]; then
    echo "[install-openssl-1.0] Patching Configure"
    echo ""

    cp Configure Configure.patched

    # Applying the patch file
    patch Configure.patched < "$_scripts_dir/patches/openssl-1.0.2u-Configure.patch"

    echo "[install-openssl-1.0] Patch content for Configure:"
    echo ""

    echo "================================================================================"
    diff --color -u Configure Configure.patched || true
    echo "================================================================================"

    echo ""

    read -r -p "Press [ENTER] to continue " && echo ""

    mv Configure.patched Configure

    _openssl_arch="darwin64-arm64-cc"
else
    _openssl_arch="darwin64-x86_64-cc"
fi

echo "[install-openssl-1.0] Configuring OpenSSL"
echo ""

# Configuring OpenSSL
./Configure "$_openssl_arch" "--prefix=$_install_dir" "--openssldir=$_install_dir" shared zlib

echo ""

read -r -p "Press [ENTER] to continue " && echo ""

echo "[install-openssl-1.0] Compiling OpenSSL"
echo ""

# Compiling OpenSSL
make -j 8

echo ""

read -r -p "Press [ENTER] to continue " && echo ""

echo "[install-openssl-1.0] Installing OpenSSL"
echo ""

# Installing OpenSSL
make install
