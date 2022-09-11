#!/usr/bin/env bash

set -euo pipefail

# The directory in which this script lives in
_scripts_dir="$(cd "$(dirname "$0")" && pwd)"

_supported_versions=("2.7.18" "3.6.15" "3.7.14" "3.8.14" "3.9.14" "3.10.7")

_supported_versions_text="$(versions="${_supported_versions[*]}"; echo "${versions// /, }")"

function printUsage() {
    echo -e "\033[1m\033[4mUsage:\033[0m ./install-python-macos.sh {pythonVersion} {installBaseDir}"
    echo -e ""
    echo -e "This script will download the given version of the Python source code, compile it, and install it to the given location."
    echo -e ""
    echo -e "\033[1m\033[4mNOTE:\033[0m Currently only macOS is supported!"
    echo -e ""
    echo -e "\033[1m\033[4mSupported Python versions:\033[0m $_supported_versions_text"
    echo -e ""
    echo -e "The given \033[3m'installBaseDir'\033[0m will not be the final install directory, but a sub-directory in that."
    echo -e "For example in case of Python 3.8 it will be \033[1m\033[3m\033[4m{installBaseDir}/Python3.8-compiled\033[0m"
    echo -e ""
    echo -e "\033[1m\033[4mOptional arguments:\033[0m"
    echo -e "    --non-interactive - If given then we won't ask for confirmations"
    echo -e "    --extra-links - In case of Python 3 besides the pip3.x, python3.x and virtualenv3.x symbolic links,"
    echo -e "                    this will also create the pip3, python3 and virtualenv3 links"
    echo -e ""
}

if [[ "$#" -eq 1 ]] && [[ "$1" == "--help" ]]; then
    printUsage
    exit 0
fi

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

echo ""
echo "As a preparation we suggest to perform the following:"
echo "====================================================="
echo ""
echo "    * brew install asciidoc autoconf bzip2 coreutils dialog diffutils findutils fontconfig gawk gcc gdbm gdk-pixbuf gettext glib gmp gnu-getopt gnu-indent gnu-sed gnu-tar gnu-time gnu-which gnunet gnupg gnutls graphite2 grep jpeg jq libev libevent libextractor libffi libgcrypt libgpg-error libidn2 libmicrohttpd libmpc libnghttp2 libpng libpthread-stubs libsodium libtasn1 libtiff libtool libunistring libx11 libxau libxcb libxdmcp libxext libxrender lzo mpdecimal ncurses nettle nghttp2 ngrep openssl@1.1 p7zip pixman pkg-config python@3.9 readline source-highlight sqlite tcl-tk unbound unzip watch wget xz zlib"
echo ""
echo "    * Add the gnu sed installed with the above command to the PATH -- IMPORTANT: The default sed on macOS does not work with this script"
echo ""
echo "    * We also suggest adding the gnu tar, and wget to the PATH as that's what we've tested this script with"
echo ""

read -r -p "[install-python-macos] Did you perform the above? [y/N] " response

case "$response" in
    [yY][eE][sS]|[yY])
        echo ""
        ;;
    *)
        echo ""
        exit 0
        ;;
esac

if [[ "$#" -lt 2 ]]; then
    printUsage
    exit 1
fi

PYTHON_VERSION="$1"
PYTHON_INSTALL_BASE="$2"

shift 2

_non_interactive=0
_extra_links=0

# Checking the rest of the arguments
for arg in "$@"; do
    case "$arg" in
        --non-interactive)
            _non_interactive=1
            ;;
        --extra-links)
            _extra_links=1
            ;;
        *)
            echo >&2 "[ERROR] Unrecognized argument: '$arg'"
            echo >&2 ""
            exit 1
            ;;
    esac
    shift
done

# Validating the installation base directory
if [[ ! -d "$PYTHON_INSTALL_BASE" ]]; then
    echo >&2 "[ERROR] The install base directory does not exists: '$PYTHON_INSTALL_BASE'"
    echo >&2 ""
    exit 1
fi

# Checking whether the version provided to the script is a valid version or not
_is_valid_version=0
for supported_version in "${_supported_versions[@]}"; do
    if [[ "$supported_version" == "$PYTHON_VERSION" ]]; then
        _is_valid_version=1
        break
    fi
done
if [[ "$_is_valid_version" -ne 1 ]]; then
    echo >&2 "[ERROR] Invalid Python versions: '$PYTHON_VERSION'. Supported versions are: $_supported_versions_text"
    echo >&2 ""
    exit 1
fi

# Keeping only the major and minor version
# E.g.: '3.9.14' becomes '3.9'
PY_POSTFIX="$(IFS='.' read -ra parts <<< "$PYTHON_VERSION"; echo "${parts[0]}.${parts[1]}")"

# Validating the --extra-links argument's purpose
if [[ "$_extra_links" -eq 1 ]] && [[ "$PY_POSTFIX" == "2.7" ]]; then
    echo >&2 "[ERROR] --extra-links can only be used with Python 3"
    echo >&2 ""
    exit 1
fi

# Assembling the final installation directory
PYTHON_INSTALL_DIR="$PYTHON_INSTALL_BASE/Python$PY_POSTFIX-compiled"

# Function to check whether a given path is not a file/directory/link
function checkNotExists() {
    if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
        echo >&2 "[ERROR] The following file or directory already exists: $1"
        echo >&2 ""
        return 1
    fi
}

checkNotExists "$PYTHON_INSTALL_DIR"

if [[ "$PY_POSTFIX" == "2.7" ]]; then
    checkNotExists "$PYTHON_INSTALL_BASE/python2"
    checkNotExists "$PYTHON_INSTALL_BASE/pip2"
    checkNotExists "$PYTHON_INSTALL_BASE/virtualenv2"
else
    checkNotExists "$PYTHON_INSTALL_BASE/python$PY_POSTFIX"
    checkNotExists "$PYTHON_INSTALL_BASE/pip$PY_POSTFIX"
    checkNotExists "$PYTHON_INSTALL_BASE/virtualenv$PY_POSTFIX"

    # If --extra-links was given, then we also need to validate that those do not exist
    if [[ "$_extra_links" -eq 1 ]]; then
        checkNotExists "$PYTHON_INSTALL_BASE/python3"
        checkNotExists "$PYTHON_INSTALL_BASE/pip3"
        checkNotExists "$PYTHON_INSTALL_BASE/virtualenv3"
    fi
fi

export WORKING_DIR="/tmp/Python-$PYTHON_VERSION"

echo "[install-python-macos] Will install Python version: $PYTHON_VERSION into $PYTHON_INSTALL_DIR"
echo ""

echo "[install-python-macos] Using working directory: $WORKING_DIR"
echo ""

if [[ "$_non_interactive" -ne 1 ]]; then
    read -r -p "[install-python-macos] Do you want to continue? [y/N] " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo ""
            ;;
        *)
            echo ""
            exit 0
            ;;
    esac
fi

# Working directory already exists, deleting it
if [[ -d "$WORKING_DIR" ]]; then
    rm -rf "$WORKING_DIR"
fi

mkdir -p "$WORKING_DIR"

# This method will be invoked when we exit from the script
# This will eventually delete our temporary directory
function deleteWorkingDirectory() {
    echo ""
    echo "[EXIT] Deleting $WORKING_DIR"

    rm -rf "$WORKING_DIR"
}

export -f deleteWorkingDirectory

trap "deleteWorkingDirectory" EXIT

export PYTHONHTTPSVERIFY=0

# We are compiling Python here (needed for search-libraries.sh)
# shellcheck disable=SC2034
_python_compile=1

# Searching for the necessary libraries to compile Python
source "$_scripts_dir/search-libraries.sh"

# Begin installation

echo "[install-python-macos] Downloading https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz into $WORKING_DIR/Python-$PYTHON_VERSION.tgz"
echo ""

wget --no-check-certificate "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -O "$WORKING_DIR/Python-$PYTHON_VERSION.tgz"

cd "$WORKING_DIR"

echo "[install-python-macos] Extracting Python-$PYTHON_VERSION.tgz"
echo ""

tar xzvf "Python-$PYTHON_VERSION.tgz"

echo ""

cd "$WORKING_DIR/Python-$PYTHON_VERSION"

# This function will apply a patch to the given file, and display the diff between the patched and the original file
function applyPatch() {
    local _file_name
    local _patch_file
    local _no_confirmation

    _file_name="$1"
    _patch_file="$_scripts_dir/patches/python$PYTHON_VERSION-$2"
    _no_confirmation=0

    if [[ "$#" -eq 3 ]] && [[ "$3" == "--no-confirm" ]]; then
        _no_confirmation=1
    fi

    if [[ ! -f "$_file_name" ]]; then
        echo >&2 "[ERROR] The file we wanted to patch does not exist: $_file_name"
        echo >&2 ""
        exit 1
    fi

    if [[ ! -f "$_patch_file" ]]; then
        echo >&2 "[ERROR] The patch file does not exist: $_patch_file"
        echo >&2 ""
        exit 1
    fi

    echo "[install-python-macos] Patching file '$_file_name'"

    if [[ "$_no_confirmation" -ne 1 ]]; then
        echo ""
    fi

    # Creating a copy of the original file
    cp "$_file_name" "$_file_name.patched"

    # Applying the patch on the copy
    patch --quiet "$_file_name.patched" < "$_patch_file"

    # In case we are patching the Setup file, we also replace the OpenSSL home directory
    if [[ "$_file_name" == "Modules/Setup" ]] || [[ "$_file_name" == "Modules/Setup.dist" ]]; then
        # shellcheck disable=SC2154
        sed -i "s/__openssl_install_dir__/$(echo "$_openssl_base" | sed 's/\//\\\//g' | sed 's/\./\\\./g')/g" "$_file_name.patched"
    fi

    if [[ "$_no_confirmation" -ne 1 ]]; then
        echo "[install-python-macos] Patch content for file '$_file_name':"
        echo ""

        # Displaying the diff between the original and the patch file
        echo "================================================================================"
        diff --color -u "$_file_name" "$_file_name.patched" || true
        echo "================================================================================"

        echo ""

        if [[ "$_non_interactive" -ne 1 ]]; then
            read -r -p "Press [ENTER] to continue " && echo ""
        fi
    fi

    # Renaming the patched file to the original one
    mv "$_file_name.patched" "$_file_name"
}

# Patching the Setup file
if [[ -f "Modules/Setup" ]]; then
    applyPatch "Modules/Setup" "setup.patch"
elif [[ -f "Modules/Setup.dist" ]]; then
    applyPatch "Modules/Setup.dist" "setup.patch"
else
    echo >&2 "[ERROR] Could not find neither Modules/Setup nor Modules/Setup.dist"
    echo >&2 ""
    exit 1
fi

# This function simply asks for a final confirmation after all patches have been applied,
# but only if we are in interactive mode
function afterPatchConfirmation() {
    echo ""

    # But after all files have been patched, we do ask for one if we need to
    if [[ "$_non_interactive" -ne 1 ]]; then
        read -r -p "Press [ENTER] to continue " && echo ""
    fi
}

# Applying extra patches
case "$PY_POSTFIX" in

    2.7)
        applyPatch "configure" "configure.patch" --no-confirm
        applyPatch "configure.ac" "configure.ac.patch" --no-confirm
        applyPatch "Mac/Modules/qt/setup.py" "qt-setup.py.patch" --no-confirm
        applyPatch "Mac/Tools/pythonw.c" "pythonw.c.patch" --no-confirm
        applyPatch "setup.py" "setup.py.patch" --no-confirm

        afterPatchConfirmation
        ;;

    3.6)
        applyPatch "configure" "configure.patch" --no-confirm
        applyPatch "configure.ac" "configure.ac.patch" --no-confirm
        applyPatch "Lib/test/test_unicode.py" "test_unicode.py.patch" --no-confirm
        applyPatch "Modules/_ctypes/_ctypes.c" "ctypes.c.patch" --no-confirm
        applyPatch "Modules/_ctypes/callproc.c" "callproc.c.patch" --no-confirm
        applyPatch "Modules/_ctypes/ctypes.h" "ctypes.h.patch" --no-confirm
        applyPatch "Modules/_decimal/libmpdec/mpdecimal.h" "mpdecimal.h.patch" --no-confirm
        applyPatch "Modules/posixmodule.c" "posixmodule.c.patch" --no-confirm
        applyPatch "Python/random.c" "random.c.patch" --no-confirm
        applyPatch "setup.py" "setup.py.patch" --no-confirm

        afterPatchConfirmation
        ;;

    3.7)
        applyPatch "Lib/test/test_unicode.py" "test_unicode.py.patch" --no-confirm
        applyPatch "Modules/_ctypes/_ctypes.c" "ctypes.c.patch" --no-confirm
        applyPatch "Modules/_ctypes/callproc.c" "callproc.c.patch" --no-confirm
        applyPatch "Modules/_ctypes/ctypes.h" "ctypes.h.patch" --no-confirm
        applyPatch "Modules/_decimal/libmpdec/mpdecimal.h" "mpdecimal.h.patch" --no-confirm
        applyPatch "setup.py" "setup.py.patch" --no-confirm

        afterPatchConfirmation
        ;;

esac

echo "[install-python-macos] Configuring the Compiler"
echo ""

# These are needed, so the gcc coming from brew does not get picked-up
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export LD="/usr/bin/g++"

# Configuring Python
if [[ "$PY_POSTFIX" == "2.7" ]] || [[ "$PY_POSTFIX" == "3.6" ]]; then
    ./configure "--prefix=$PYTHON_INSTALL_DIR" --enable-optimizations --with-ensurepip=install 2>&1
elif [[ "$_is_apple_silicon" -eq 1 ]]; then
    ./configure "--prefix=$PYTHON_INSTALL_DIR" --enable-optimizations --with-ensurepip=install "--with-openssl=$_openssl_base" 2>&1
else
    ./configure "--prefix=$PYTHON_INSTALL_DIR" --enable-optimizations --with-ensurepip=install "--with-openssl=$_openssl_base" --enable-universalsdk --with-universal-archs=intel-64 2>&1
fi

echo ""

if [[ "$_non_interactive" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi

echo "[install-python-macos] Compiling Python"
echo ""

# Compiling Python
make -j 8 2>&1

echo ""

if [[ "$_non_interactive" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi

echo "[install-python-macos] Installing Python into $PYTHON_INSTALL_DIR"
echo ""

# Installing Python to the destination directory
make install 2>&1

# Unsetting the compiler arguments
unset LDFLAGS CPPFLAGS LD_LIBRARY_PATH CC CXX LD

echo ""

if [[ "$_non_interactive" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi

echo "[install-python-macos] Creating links"
echo ""

# Creating symbolic links for pip and the python command
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    ln -s "$PYTHON_INSTALL_DIR/bin/python2" "$PYTHON_INSTALL_BASE/python2"
    ln -s "$PYTHON_INSTALL_DIR/bin/pip2" "$PYTHON_INSTALL_BASE/pip2"
else
    ln -s "$PYTHON_INSTALL_DIR/bin/python3" "$PYTHON_INSTALL_BASE/python$PY_POSTFIX"
    ln -s "$PYTHON_INSTALL_DIR/bin/pip3" "$PYTHON_INSTALL_BASE/pip$PY_POSTFIX"

    # If --extra-links was given, then we also create the python3 and pip3 symbolic links
    if [[ "$_extra_links" -eq 1 ]]; then
        ln -s "$PYTHON_INSTALL_DIR/bin/python3" "$PYTHON_INSTALL_BASE/python3"
        ln -s "$PYTHON_INSTALL_DIR/bin/pip3" "$PYTHON_INSTALL_BASE/pip3"
    fi
fi

# Adding our new and shiny Python installation to the PATH
export PATH="$PYTHON_INSTALL_BASE:$PATH"

echo "[install-python-macos] Locations:"
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    echo "    * python2: $(which "python2")"
    echo "    * pip2: $(which "pip2")"
else
    echo "    * python$PY_POSTFIX: $(which "python$PY_POSTFIX")"
    echo "    * pip$PY_POSTFIX: $(which "pip$PY_POSTFIX")"

    # If --extra-links was given, then we also print the python3 and pip3 links
    if [[ "$_extra_links" -eq 1 ]]; then
        echo "    * python3: $(which "python3")"
        echo "    * pip3: $(which "pip3")"
    fi
fi
echo ""

echo "[install-python-macos] Upgrading pip and setuptools"
echo ""

# Upgrading pip
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    pip2 install --upgrade pip
else
    "pip$PY_POSTFIX" install --upgrade pip
fi

# Upgrading setuptools
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    pip2 install --upgrade setuptools
else
    "pip$PY_POSTFIX" install --upgrade setuptools
fi

echo ""
echo "[install-python-macos] Installing virtualenv"
echo ""

# Installing virtualenv
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    pip2 install virtualenv
else
    "pip$PY_POSTFIX" install virtualenv
fi

echo ""
echo "[install-python-macos] Creating a link for virtualenv"

# Creating a symbolic link for virtualenv
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv2"
else
    ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv$PY_POSTFIX"

    # If --extra-links was given, then we also create the virtualenv3 symbolic link
    if [[ "$_extra_links" -eq 1 ]]; then
        ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv3"
    fi
fi

echo ""
echo "It is recommended that you add $PYTHON_INSTALL_BASE to your PATH"
echo "For that execute: export PATH=\"$PYTHON_INSTALL_BASE:\$PATH\""

echo ""
echo "Python $PY_POSTFIX successfully completed :)"
