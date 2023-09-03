#!/usr/bin/env bash

###################################################################################################
############################################ DESCRIPTION ##########################################
###################################################################################################
###                                                                                             ###
### Python 3.4 is NOT compatible with OpenSSL 1.1 hence we need to install Open SSL 1.0 for it  ###
### Since Open SSL 1.0 is EOL, we cannot install it via brew                                    ###
### However we can install it via this script                                                   ###
###                                                                                             ###
### The script will install OpenSSL 1.0 into $HOME/Library/openssl-1.0.2u                       ###
### If you want to change this you have to manually edit the script and replace all occurrences ###
###################################################################################################

set -euo pipefail

clear

# Checking whether we are running the script on macOS or not
if [[ "$(uname)" != "Darwin" ]]; then
    echo >&2 "${FNT_BLD}[ERROR]${FNT_RST} This script must be run on macOS"
    echo >&2 ""
    exit 1
fi

# Checking whether Homebrew is installed or not
if [[ "$(command -v brew 2> /dev/null || true)" == "" ]]; then
    echo >&2 "${FNT_BLD}[ERROR]${FNT_RST} Homebrew is not installed"
    echo >&2 ""
    exit 1
fi

G_PROG_NAME="$(basename -s ".sh" "$0")"
export G_PROG_NAME

# The directory in which this script lives in
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Importing basic functions
source "$SCRIPTS_DIR/utils/fonts.sh"
source "$SCRIPTS_DIR/utils/print-func.sh"
source "$SCRIPTS_DIR/utils/exec-func.sh"
source "$SCRIPTS_DIR/utils/utils.sh"

# Searching for GNU programs and adding them to the PATH
source "$SCRIPTS_DIR/libraries/search-gnu-progs.sh"

WORKING_DIR="$(cd "$TMPDIR" && pwd)/openssl-1.0.2u-temp.$(date "+%s")"
export WORKING_DIR

INSTALL_DIR="$HOME/Library/openssl-1.0.2u"

# Checking the architecture type (Intel vs. Apple Silicon)
if [[ "$(uname -m)" == "x86_64" ]]; then
    IS_APPLE_SILICON=false
elif [[ "$(uname -m)" == "arm64" ]]; then
    IS_APPLE_SILICON=true
else
    sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Unsupported OS: $(uname) ($(uname -m))"
    sysout >&2 ""
    exit 1
fi

# This method will be invoked when we exit from the script
# This will eventually delete our temporary directory
function deleteTempDirectory() {
    sysout ""
    sysout "${FNT_BLD}[EXIT]${FNT_RST} Deleting $WORKING_DIR"

    rm -rf "$WORKING_DIR"
}

export -f deleteTempDirectory

trap "deleteTempDirectory" EXIT

# Working directory already exists, deleting it
if [[ -d "$WORKING_DIR" ]]; then
    rm -rf "$WORKING_DIR"
fi

# Creating the temporary folder where we'll download the source and do the compilation
mkdir -p "$WORKING_DIR"

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Downloading the OpenSSL 1.0 source code"
sysout ""

# Downloading the OpenSSL source code
wget --no-verbose --no-check-certificate "https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz" -O "$WORKING_DIR/openssl-1.0.2u.tar.gz"

cd "$WORKING_DIR"

sysout ""
sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Extracting the OpenSSL 1.0 source code"
sysout ""

# Extracting the OpenSSL source code
tar zxf "openssl-1.0.2u.tar.gz"

cd "openssl-1.0.2u"

# Creating the destination directory
mkdir -p "$INSTALL_DIR"

# This is not a Python compilation (needed for libraries/search-libraries.sh)
# shellcheck disable=SC2034
G_PYTHON_COMPILE=false

# Searching for the necessary libraries to compile Python
# UPDATE: Since we are NOT using zlib anymore, we do not need this
# source "$SCRIPTS_DIR/libraries/search-libraries.sh"

# These are needed, so the gcc coming from brew does not get picked-up
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export LD="/usr/bin/g++"

# We don't need these
unset LDFLAGS CFLAGS CPPFLAGS CPATH LIBRARY_PATH PKG_CONFIG_PATH

# OpenSSL 1.0 does not have Apple Silicon support by default, so let's add it
if $IS_APPLE_SILICON; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Patching Configure"
    sysout ""

    cp Configure Configure.patched

    # Applying the patch file
    patch Configure.patched < "$SCRIPTS_DIR/patches/openssl-1.0.2u-Configure.patch"

    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Patch content for Configure:"
    sysout ""

    sysout "================================================================================"
    diff --color -u Configure Configure.patched || true
    sysout "================================================================================"

    sysout ""

    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"

    mv Configure.patched Configure
fi

# This could interfere with how we expect OpenSSL to build
unset OPENSSL_LOCAL_CONFIG_DIR

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Configuring OpenSSL"
sysout ""

# Configuring OpenSSL
echoAndExec ./Configure "darwin64-$(uname -m)-cc" "enable-ec_nistp_64_gcc_128" \
    threads no-ssl2 no-ssl3 no-ssl3-method no-comp no-zlib no-shared \
    "--prefix=$INSTALL_DIR" "--openssldir=$INSTALL_DIR"

sysout ""

ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Compiling OpenSSL"
sysout ""

# Compiling OpenSSL
echoAndExec make depend && sysout ""
echoAndExec make -j "$(proc_count="$(nproc)" && echo "$((proc_count / 2))")" && sysout ""

ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Installing OpenSSL"
sysout ""

# Installing OpenSSL
echoAndExec make install
