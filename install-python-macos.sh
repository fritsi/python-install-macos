#!/usr/bin/env bash

set -euo pipefail

# The directory in which this script lives in
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

SUPPORTED_VERSIONS=("2.7.18" "3.6.15" "3.7.15" "3.8.15" "3.9.15" "3.10.8" "3.11.0")

SUPPORTED_VERSIONS_TEXT="$(versions="${SUPPORTED_VERSIONS[*]}" && echo "${versions// /, }")"

function printUsage() {
    echo -e "\033[1m\033[4mUsage:\033[0m ./install-python-macos.sh {pythonVersion} {installBaseDir}"
    echo -e ""
    echo -e "This script will download the given version of the Python source code, compile it, and install it to the given location."
    echo -e ""
    echo -e "\033[1m\033[4mNOTE:\033[0m Currently only macOS is supported!"
    echo -e ""
    echo -e "\033[1m\033[4mSupported Python versions:\033[0m $SUPPORTED_VERSIONS_TEXT"
    echo -e ""
    echo -e "The given \033[3m'installBaseDir'\033[0m will not be the final install directory, but a subdirectory in that."
    echo -e "For example in case of Python 3.8 it will be \033[1m\033[3m\033[4m{installBaseDir}/python-3.8\033[0m"
    echo -e ""
    echo -e "The script will ask you whether you want to run the Python tests or not."
    echo -e "This can be used to check whether everything is okay with the compiled Python or not."
    echo -e ""
    echo -e "\033[1mIf you followed the instructions, you should have no failures.\033[0m"
    echo -e ""
    echo -e "If there are test failures, the script will stop and ask you if you'd like to continue."
    echo -e ""
    echo -e "\033[1m\033[4mNOTE:\033[0m In case of non-interactive mode, the script will always run these tests."
    echo -e ""
    echo -e "\033[1m\033[4mNOTE 2:\033[0m While running the tests, you might see a pop-up window asking you to allow Python to connect to the network."
    echo -e "These are for the socket/ssl related tests. It's safe to allow."
    echo -e ""
    echo -e "\033[1m\033[4mNOTE 3:\033[0m Currently the UI (Tkinter) related tests are deliberately skipped as they are unstable."
    echo -e ""
    echo -e "\033[1m\033[4mOptional arguments:\033[0m"
    echo -e ""
    echo -e "    \033[1m--non-interactive\033[0m - If given then we won't ask for confirmations."
    echo -e ""
    echo -e "    \033[1m--extra-links\033[0m - In case of Python 3 besides the pip3.x, python3.x and virtualenv3.x symbolic links,"
    echo -e "                    this will also create the pip3, python3 and virtualenv3 links."
    echo -e ""
    echo -e "    \033[1m--keep-working-dir\033[0m - We'll keep the working directory after the script finished / exited."
    echo -e ""
    echo -e "    \033[1m--keep-test-results\033[0m - We'll keep the test log and test result xml files even in case everything passed."
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
    IS_APPLE_SILICON=0
elif [[ "$(uname -m)" == "arm64" ]]; then
    IS_APPLE_SILICON=1
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

read -r -p "[install-python-macos] Did you perform the above? ([y]/N) " response

case "$response" in
    "" | [yY][eE][sS] | [yY])
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

P_NON_INTERACTIVE=0
P_EXTRA_LINKS=0
P_KEEP_WORKING_DIR=0
P_KEEP_TEST_RESULTS=0

# Checking the rest of the arguments
while [[ "$#" -gt 0 ]]; do
    # Getting the next argument
    argument="$1"
    shift

    case "$argument" in
        --non-interactive)
            P_NON_INTERACTIVE=1
            ;;
        --extra-links)
            P_EXTRA_LINKS=1
            ;;
        --keep-working-dir)
            P_KEEP_WORKING_DIR=1
            ;;
        --keep-test-results)
            P_KEEP_TEST_RESULTS=1
            ;;
        *)
            echo >&2 "[ERROR] Unrecognized argument: '$argument'"
            echo >&2 ""
            exit 1
            ;;
    esac
done

# Exporting this as we need to use it in "trap"
export P_KEEP_WORKING_DIR

# Validating the installation base directory
if [[ ! -d "$PYTHON_INSTALL_BASE" ]]; then
    echo >&2 "[ERROR] The install base directory does not exists: '$PYTHON_INSTALL_BASE'"
    echo >&2 ""
    exit 1
fi

# Checking whether the version provided to the script is a valid version or not
_is_valid_version=0
for supported_version in "${SUPPORTED_VERSIONS[@]}"; do
    if [[ "$supported_version" == "$PYTHON_VERSION" ]]; then
        _is_valid_version=1
        break
    fi
done
if [[ "$_is_valid_version" -ne 1 ]]; then
    echo >&2 "[ERROR] Invalid Python versions: '$PYTHON_VERSION'. Supported versions are: $SUPPORTED_VERSIONS_TEXT"
    echo >&2 ""
    exit 1
fi

# Keeping only the major and minor version
# E.g.: '3.9.14' becomes '3.9'
PY_POSTFIX="$(IFS='.' read -ra parts <<< "$PYTHON_VERSION" && echo "${parts[0]}.${parts[1]}")"

# Validating the --extra-links argument's purpose
if [[ "$P_EXTRA_LINKS" -eq 1 ]] && [[ "$PY_POSTFIX" == "2.7" ]]; then
    echo >&2 "[ERROR] --extra-links can only be used with Python 3"
    echo >&2 ""
    exit 1
fi

# Assembling the final installation directory
PYTHON_INSTALL_DIR="$PYTHON_INSTALL_BASE/python-$PY_POSTFIX"

# Function to check whether a given path is not a file/directory/link
function checkNotExists() {
    if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
        echo >&2 "[ERROR] The following file or directory already exists: $1"
        echo >&2 ""
        return 1
    fi
}

WORKING_DIR="$(cd "$TMPDIR" && pwd)/python-$PYTHON_VERSION-temp"
export WORKING_DIR

checkNotExists "$WORKING_DIR/Python-$PYTHON_VERSION.tgz"
checkNotExists "$WORKING_DIR/Python-$PYTHON_VERSION"

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
    if [[ "$P_EXTRA_LINKS" -eq 1 ]]; then
        checkNotExists "$PYTHON_INSTALL_BASE/python3"
        checkNotExists "$PYTHON_INSTALL_BASE/pip3"
        checkNotExists "$PYTHON_INSTALL_BASE/virtualenv3"
    fi
fi

echo -e "[install-python-macos] Will install Python version: \033[1m$PYTHON_VERSION\033[0m into \033[1m$PYTHON_INSTALL_DIR\033[0m"
echo ""

echo -e "[install-python-macos] Using working directory: \033[1m$WORKING_DIR\033[0m"
echo ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    read -r -p "[install-python-macos] Do you want to continue? ([y]/N) " response

    case "$response" in
        "" | [yY][eE][sS] | [yY])
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

    if [[ "$P_KEEP_WORKING_DIR" -ne 1 ]]; then
        echo "[EXIT] Deleting $WORKING_DIR"
        rm -rf "$WORKING_DIR"
    else
        echo "[EXIT] Keeping $WORKING_DIR"
    fi
}

export -f deleteWorkingDirectory

trap "deleteWorkingDirectory" EXIT

# We are compiling Python here (needed for search-libraries.sh)
# shellcheck disable=SC2034
G_PYTHON_COMPILE=1

# Searching for the necessary libraries to compile Python
source "$SCRIPTS_DIR/search-libraries.sh"

# Begin installation

echo "[install-python-macos] Downloading https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz into $WORKING_DIR/Python-$PYTHON_VERSION.tgz"
echo ""

wget --no-verbose --no-check-certificate "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -O "$WORKING_DIR/Python-$PYTHON_VERSION.tgz"

cd "$WORKING_DIR"

echo ""
echo "[install-python-macos] Extracting Python-$PYTHON_VERSION.tgz"
echo ""

tar xzf "Python-$PYTHON_VERSION.tgz"

cd "$WORKING_DIR/Python-$PYTHON_VERSION"

echo "[install-python-macos] Applying the patch file onto the Python source code"

# Copying the patch file to our working directory as we need to replace '__openssl_install_dir__' in it
cp "$SCRIPTS_DIR/patches/Python-$PYTHON_VERSION.patch" "$WORKING_DIR/Python-$PYTHON_VERSION.patch"

# Function to replace variables with a value in the patch file
function substituteVariableInPatch() {
    local variableName
    local variableValue

    variableName="$1"
    variableValue="$2"

    echo "[install-python-macos] Substituting '$variableName' with '$variableValue' in the patch file"

    sed -i "s/$variableName/$(echo "$variableValue" | sed 's/\//\\\//g' | sed 's/\./\\\./g')/g" "$WORKING_DIR/Python-$PYTHON_VERSION.patch"
}

echo ""

# Substituting some variable in the patch file
substituteVariableInPatch "__openssl_install_dir__" "$L_OPENSSL_BASE"
substituteVariableInPatch "__readline_install_dir__" "$L_READLINE_BASE"
substituteVariableInPatch "__tcl_tk_install_dir__" "$L_TCL_TK_BASE"
substituteVariableInPatch "__zlib_install_dir__" "$L_ZLIB_BASE"

echo ""

# Applying the patch file
patch -p1 < "$WORKING_DIR/Python-$PYTHON_VERSION.patch"

echo ""

# But after all files have been patched, we do ask for one if we need to
if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi

# Prints a command line and then executes it
function echoAndExec() {
    local param
    local index
    index=0

    echo -n ">> "

    # First item (assuming it's the executable) will be printed without quotes
    # The rest of the parameters with quotes
    for param in "$@"; do
        if [[ "$index" -eq 0 ]]; then
            echo -n "$param"
        else
            echo -n " \"$param\""
        fi
        index=$((index + 1))
    done

    echo ""
    echo ""

    if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
        read -r -p "Press [ENTER] to execute the above command " && echo ""
    fi

    "$@"
}

export -f echoAndExec

echo "[install-python-macos] Configuring the Compiler"
echo ""

# These are needed, so the gcc coming from brew does not get picked-up
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export LD="/usr/bin/g++"

# Parameters used for ./configure
CONFIGURE_PARAMS=(
    "--prefix=$PYTHON_INSTALL_DIR"
    "--with-ensurepip=install"
    "--enable-optimizations"
)

# --with-openssl is only available from Python 3.7
if [[ "$PY_POSTFIX" != "2.7" ]] && [[ "$PY_POSTFIX" != "3.6" ]]; then
    CONFIGURE_PARAMS+=("--with-openssl=$L_OPENSSL_BASE")
fi

# --with-tcltk-includes and --with-tcltk-libs is NOT available since Python 3.11
if [[ "$PY_POSTFIX" != "3.11" ]]; then
    CONFIGURE_PARAMS+=("--with-tcltk-includes=-I$L_TCL_TK_BASE/include")
    CONFIGURE_PARAMS+=("--with-tcltk-libs=-L$L_TCL_TK_BASE/lib -ltk8.6 -ltcl8.6 -DWITH_APPINIT")
fi

# On non Apple-Silicon machines if the Python version is >= 3.7, then
# we add --enable-universalsdk and --with-universal-archs=intel-64 as well
if [[ "$IS_APPLE_SILICON" -ne 1 ]] && [[ "$PY_POSTFIX" != "2.7" ]] && [[ "$PY_POSTFIX" != "3.6" ]]; then
    CONFIGURE_PARAMS+=("--enable-universalsdk")
    CONFIGURE_PARAMS+=("--with-universal-archs=intel-64")
fi

# Configuring Python
echoAndExec ./configure "${CONFIGURE_PARAMS[@]}" 2>&1

echo ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi

# Saving the number of processors
PROC_COUNT="$(nproc)"

echo "[install-python-macos] Compiling Python"
echo ""

# Compiling Python
# We'll be using half the available cores for make
echoAndExec make -j "$((PROC_COUNT / 2))" 2>&1

echo ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi

function runTests() {
    local test_log_file
    local test_result_xml_file

    test_log_file="$PYTHON_INSTALL_BASE/python-$PYTHON_VERSION-tests.log"
    test_result_xml_file="$PYTHON_INSTALL_BASE/python-$PYTHON_VERSION-test-results.xml"

    # Turning off exit in case of a failure, so we can explicitly check the exit code of the python -m test command
    set +euo pipefail

    (
        set -o pipefail

        # Needed for some of the tests
        export LC_ALL="en_US.UTF-8"
        export LANG="en_US.UTF-8"

        # unsetting these as they would mess with the tests
        unset PYTHONHTTPSVERIFY DISPLAY

        # Getting rid of some warnings in the tests
        export TK_SILENCE_DEPRECATION=1

        # We don't want to run the Tkinter related tests as they are too unstable
        export UI_TESTS_ENABLED=0

        # --junit-xml is not available for Python 2.7
        EXTRA_TEST_ARGS=()
        if [[ "$PY_POSTFIX" != "2.7" ]]; then
            EXTRA_TEST_ARGS+=("--junit-xml=$test_result_xml_file")
        fi

        # Running the tests
        #
        # * We'll be using half the available cores for the tests
        #
        # * Deliberately not running this on multiple processes with -j,
        # because in that case some of the tests might get skipped
        #
        # * Yes, in its native compiled-only state, it's python.exe :D
        echoAndExec ./python.exe -W default -bb -m test -j "$((PROC_COUNT / 2))" -u all -w "${EXTRA_TEST_ARGS[@]}" 2>&1 | tee "$test_log_file"
    )

    # shellcheck disable=SC2181
    if [[ "$?" -eq 0 ]]; then
        # Waiting for the user's confirmation
        if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
            echo ""
            read -r -p "Press [ENTER] to continue "
        fi

        # Turning on exit code check again
        set -euo pipefail

        # Deleting the test log and test result xml files if we don't want to keep them
        if [[ "$P_KEEP_TEST_RESULTS" -ne 1 ]]; then
            rm -rf "$test_log_file" "$test_result_xml_file"
        fi

        # Nothing else to do here
        return 0
    else
        echo >&2 ""
        echo >&2 "[ERROR] THERE WERE TEST FAILURES"
        if [[ -f "$test_result_xml_file" ]]; then
            echo >&2 "[ERROR] PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $test_log_file,"
            echo >&2 "[ERROR] OR THE TEST RESULT XML FILE: $test_result_xml_file"
        else
            echo >&2 "[ERROR] PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $test_log_file"
        fi
        echo >&2 ""

        # Ask the user if they want to continue
        read -r -p "[install-python-macos] Would you like to continue? ([y]/N) " response

        # If not, then we exit
        if [[ "$response" != "" ]] && [[ ! "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
            exit 1
        fi
    fi
}

if [[ "$P_NON_INTERACTIVE" -eq 1 ]]; then
    # In non-interactive mode we run the tests
    runTests && echo ""
else
    # In interactive mode we ask the user whether they want to run the tests or not
    read -r -p "[install-python-macos] Do you want to run the tests? ([y]/N) " response && echo ""

    if [[ "$response" == "" ]] || [[ "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
        runTests && echo ""
    fi
fi

echo "[install-python-macos] Installing Python into $PYTHON_INSTALL_DIR"
echo ""

# Installing Python to the destination directory
echoAndExec make install 2>&1

# Unsetting the compiler arguments
unset LDFLAGS CPPFLAGS LD_LIBRARY_PATH CC CXX LD

echo ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
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
    if [[ "$P_EXTRA_LINKS" -eq 1 ]]; then
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
    if [[ "$P_EXTRA_LINKS" -eq 1 ]]; then
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
    if [[ "$P_EXTRA_LINKS" -eq 1 ]]; then
        ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv3"
    fi
fi

echo ""
echo "[install-python-macos] It is recommended that you add $PYTHON_INSTALL_BASE to your PATH"
echo "[install-python-macos] For that execute: export PATH=\"$PYTHON_INSTALL_BASE:\$PATH\""

echo ""
echo "[install-python-macos] Python $PY_POSTFIX successfully completed :)"
