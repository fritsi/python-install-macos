#!/usr/bin/env bash

set -euo pipefail

clear

G_PROG_NAME="$(basename -s ".sh" "$0")"
export G_PROG_NAME

# The directory in which this script lives in
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Importing basic functions
source "$SCRIPTS_DIR/utils/print-func.sh"
source "$SCRIPTS_DIR/utils/exec-func.sh"

SUPPORTED_VERSIONS=("2.7.18" "3.6.15" "3.7.15" "3.8.15" "3.9.15" "3.10.8" "3.11.0")

SUPPORTED_VERSIONS_TEXT="$(versions="${SUPPORTED_VERSIONS[*]}" && echo "${versions// /, }")"

function printUsage() {
    sysout "\033[1m\033[4mUsage:\033[0m ./$G_PROG_NAME.sh {pythonVersion} {installBaseDir}"
    sysout ""
    sysout "This script will download the given version of the Python source code, compile it, and install it to the given location."
    sysout ""
    sysout "\033[1m\033[4mNOTE:\033[0m Currently only macOS is supported!"
    sysout ""
    sysout "\033[1m\033[4mSupported Python versions:\033[0m $SUPPORTED_VERSIONS_TEXT"
    sysout ""
    sysout "The given \033[3m'installBaseDir'\033[0m will not be the final install directory, but a subdirectory in that."
    sysout "For example in case of Python 3.8 it will be \033[1m\033[3m\033[4m{installBaseDir}/python-3.8\033[0m"
    sysout ""
    sysout "The script will ask you whether you want to run the Python tests or not."
    sysout "This can be used to check whether everything is okay with the compiled Python or not."
    sysout ""
    sysout "\033[1mIf you followed the instructions, you should have no failures.\033[0m"
    sysout ""
    sysout "If there are test failures, the script will stop and ask you if you'd like to continue."
    sysout ""
    sysout "\033[1m\033[4mNOTE:\033[0m In case of non-interactive mode, the script will always run these tests."
    sysout ""
    sysout "\033[1m\033[4mNOTE 2:\033[0m While running the tests, you might see a pop-up window asking you to allow Python to connect to the network."
    sysout "These are for the socket/ssl related tests. It's safe to allow."
    sysout ""
    sysout "\033[1m\033[4mNOTE 3:\033[0m Currently the UI (Tkinter) related tests are deliberately skipped as they are unstable."
    sysout ""
    sysout "\033[1m\033[4mOptional arguments:\033[0m"
    sysout ""
    sysout "    \033[1m--non-interactive\033[0m - If given then we won't ask for confirmations."
    sysout ""
    sysout "    \033[1m--extra-links\033[0m - In case of Python 3 besides the pip3.x, python3.x and virtualenv3.x symbolic links,"
    sysout "                    this will also create the pip3, python3 and virtualenv3 links."
    sysout ""
    sysout "    \033[1m--keep-working-dir\033[0m - We'll keep the working directory after the script finished / exited."
    sysout ""
    sysout "    \033[1m--keep-test-results\033[0m - We'll keep the test log and test result xml files even in case everything passed."
    sysout ""

    # Also printing out the preparation steps
    printPreparationSteps
}

function printPreparationSteps() {
    sysout "\033[1m\033[4mAs a preparation we suggest to perform the following:\033[0m"
    sysout ""
    sysout "\033[1mbrew install\033[0m asciidoc autoconf bzip2 coreutils diffutils findutils \\"
    sysout "             gawk gcc gdbm gnu-sed gnu-tar gnu-which gnunet grep jq \\"
    sysout "             libffi libtool libx11 libxcrypt libzip lzo ncurses \\"
    sysout "             openssl@1.1 openssl@3 p7zip pkg-config readline sqlite \\"
    sysout "             tcl-tk unzip wget xz zlib"
    sysout ""
    sysout "\033[1m\033[4mNOTE:\033[0m The above command does \033[1mnot\033[0m only install libraries, but also a couple of \033[1mGNU\033[0m executables."
    sysout "      These will not be used by default, but \033[3msearch-libraries.sh\033[0m will temporarily add it to PATH."
    sysout "      These are useful, because their default macOS counterpart might be very old in some cases."
    sysout ""
}

if [[ "$#" -eq 1 ]] && [[ "$1" == "--help" ]]; then
    printUsage
    exit 0
fi

# Searching for GNU programs and adding them to the PATH
source "$SCRIPTS_DIR/libraries/search-gnu-progs.sh"

# Checking whether we are running the script on macOS or not
if [[ "$(uname)" != "Darwin" ]]; then
    sysout >&2 "[ERROR] This script must be run on macOS"
    sysout >&2 ""
    exit 1
fi

# Checking the architecture type (Intel vs. Apple Silicon)
if [[ "$(uname -m)" == "x86_64" ]]; then
    IS_APPLE_SILICON=0
elif [[ "$(uname -m)" == "arm64" ]]; then
    IS_APPLE_SILICON=1
else
    sysout >&2 "[ERROR] Unsupported OS: $(uname) ($(uname -m))"
    sysout >&2 ""
    exit 1
fi

printPreparationSteps

ask "\033[1m[$G_PROG_NAME]\033[0m Did you perform the above? ([y]/N)" response

# shellcheck disable=SC2154
case "$response" in
    "" | [yY][eE][sS] | [yY])
        sysout ""
        ;;
    *)
        sysout ""
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
            sysout >&2 "[ERROR] Unrecognized argument: '$argument'"
            sysout >&2 ""
            exit 1
            ;;
    esac
done

# Exporting this as we need to use it in "trap"
export P_KEEP_WORKING_DIR

# Validating the installation base directory
if [[ ! -d "$PYTHON_INSTALL_BASE" ]]; then
    sysout >&2 "[ERROR] The install base directory does not exists: '$PYTHON_INSTALL_BASE'"
    sysout >&2 ""
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
    sysout >&2 "[ERROR] Invalid Python versions: '$PYTHON_VERSION'. Supported versions are: $SUPPORTED_VERSIONS_TEXT"
    sysout >&2 ""
    exit 1
fi

# Splitting up the Python version at the dots
IFS='.' read -ra python_version_parts <<< "$PYTHON_VERSION"

# Keeping only the major and minor version
# E.g.: '3.9.14' becomes '3.9'
PY_POSTFIX="${python_version_parts[0]}.${python_version_parts[1]}"

# Converting the Python major.minor version into its numeric representation
# E.g.: 2.7 -> 207; 3.6 -> 306; 3.9 -> 309; 3.10 -> 310
PY_VERSION_NUM="$((python_version_parts[0] * 100 + python_version_parts[1]))"

# We no longer need this
unset python_version_parts

# Validating the --extra-links argument's purpose
if [[ "$P_EXTRA_LINKS" -eq 1 ]] && [[ "$PY_VERSION_NUM" -lt 300 ]]; then
    sysout >&2 "[ERROR] --extra-links can only be used with Python 3"
    sysout >&2 ""
    exit 1
fi

# Assembling the final installation directory
PYTHON_INSTALL_DIR="$PYTHON_INSTALL_BASE/python-$PY_POSTFIX"

# Function to check whether a given path is not a file/directory/link
function checkNotExists() {
    if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
        sysout >&2 "[ERROR] The following file or directory already exists: $1"
        sysout >&2 ""
        return 1
    fi
}

WORKING_DIR="$(cd "$TMPDIR" && pwd)/python-$PYTHON_VERSION-temp.$(date "+%s")"
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

sysout "\033[1m[$G_PROG_NAME]\033[0m Will install Python version: \033[1m$PYTHON_VERSION\033[0m into \033[1m$PYTHON_INSTALL_DIR\033[0m"
sysout ""

sysout "\033[1m[$G_PROG_NAME]\033[0m Using working directory: \033[1m$WORKING_DIR\033[0m"
sysout ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "\033[1m[$G_PROG_NAME]\033[0m Do you want to continue? ([y]/N)" response

    case "$response" in
        "" | [yY][eE][sS] | [yY])
            sysout ""
            ;;
        *)
            sysout ""
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
    sysout ""

    if [[ "$P_KEEP_WORKING_DIR" -ne 1 ]]; then
        sysout "[EXIT] Deleting $WORKING_DIR"
        rm -rf "$WORKING_DIR"
    else
        sysout "[EXIT] Keeping $WORKING_DIR"
    fi
}

export -f deleteWorkingDirectory

trap "deleteWorkingDirectory" EXIT

# We are compiling Python here (needed for libraries/search-libraries.sh)
# shellcheck disable=SC2034
G_PYTHON_COMPILE=1

# Searching for the necessary libraries to compile Python
source "$SCRIPTS_DIR/libraries/search-libraries.sh"

# Begin installation

sysout "\033[1m[$G_PROG_NAME]\033[0m Downloading https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz into $WORKING_DIR/Python-$PYTHON_VERSION.tgz"
sysout ""

wget --no-verbose --no-check-certificate "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -O "$WORKING_DIR/Python-$PYTHON_VERSION.tgz"

cd "$WORKING_DIR"

sysout ""
sysout "\033[1m[$G_PROG_NAME]\033[0m Extracting Python-$PYTHON_VERSION.tgz"
sysout ""

tar xzf "Python-$PYTHON_VERSION.tgz"

cd "$WORKING_DIR/Python-$PYTHON_VERSION"

sysout "\033[1m[$G_PROG_NAME]\033[0m Applying the patch file onto the Python source code"

# Copying the patch file to our working directory as we need to replace '__openssl_install_dir__' in it
cp "$SCRIPTS_DIR/patches/Python-$PYTHON_VERSION.patch" "$WORKING_DIR/Python-$PYTHON_VERSION.patch"

# Function to replace variables with a value in the patch file
function substituteVariableInPatch() {
    local variableName
    local variableValue

    variableName="$1"
    variableValue="$2"

    sysout "\033[1m[$G_PROG_NAME]\033[0m Substituting '$variableName' with '$variableValue' in the patch file"

    sed -i "s/$variableName/$(echo "$variableValue" | sed 's/\//\\\//g' | sed 's/\./\\\./g')/g" "$WORKING_DIR/Python-$PYTHON_VERSION.patch"
}

sysout ""

# Substituting some variable in the patch file
substituteVariableInPatch "__openssl_install_dir__" "$L_OPENSSL_BASE"
substituteVariableInPatch "__readline_install_dir__" "$L_READLINE_BASE"
substituteVariableInPatch "__tcl_tk_install_dir__" "$L_TCL_TK_BASE"
substituteVariableInPatch "__zlib_install_dir__" "$L_ZLIB_BASE"

sysout ""

# Applying the patch file
patch -p1 < "$WORKING_DIR/Python-$PYTHON_VERSION.patch"

sysout ""

# But after all files have been patched, we do ask for one if we need to
if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "\033[1m[$G_PROG_NAME]\033[0m Press [ENTER] to continue" && sysout ""
fi

sysout "\033[1m[$G_PROG_NAME]\033[0m Configuring the Compiler"
sysout ""

# These are needed, so the gcc coming from brew does not get picked-up
export CC="/usr/bin/gcc"
export CXX="/usr/bin/g++"
export LD="/usr/bin/g++"

# Parameters used for ./configure
CONFIGURE_PARAMS=(
    "--prefix=$PYTHON_INSTALL_DIR"
    "--with-ensurepip=install"
    "--enable-optimizations"
    "--with-system-ffi"
    "--with-dbmliborder=gdbm:ndbm"
)

# --enable-loadable-sqlite-extensions is only available from Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    CONFIGURE_PARAMS+=("--enable-loadable-sqlite-extensions")
fi

# --with-openssl is only available from Python 3.7
if [[ "$PY_VERSION_NUM" -ge 307 ]]; then
    CONFIGURE_PARAMS+=("--with-openssl=$L_OPENSSL_BASE")
fi

# --with-tcltk-includes and --with-tcltk-libs is NOT available since Python 3.11
if [[ "$PY_VERSION_NUM" -lt 311 ]]; then
    CONFIGURE_PARAMS+=("--with-tcltk-includes=-I$L_TCL_TK_BASE/include")
    CONFIGURE_PARAMS+=("--with-tcltk-libs=-L$L_TCL_TK_BASE/lib -ltk8.6 -ltcl8.6 -DWITH_APPINIT")
fi

# On non Apple-Silicon machines if the Python version is >= 3.7, then
# we add --enable-universalsdk and --with-universal-archs=intel-64 as well
if [[ "$IS_APPLE_SILICON" -ne 1 ]] && [[ "$PY_VERSION_NUM" -ge 307 ]]; then
    CONFIGURE_PARAMS+=("--enable-universalsdk")
    CONFIGURE_PARAMS+=("--with-universal-archs=intel-64")
fi

# Configuring Python
echoAndExec ./configure "${CONFIGURE_PARAMS[@]}" 2>&1

sysout ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "\033[1m[$G_PROG_NAME]\033[0m Press [ENTER] to continue" && sysout ""
fi

# Saving the number of processors
PROC_COUNT="$(nproc)"

sysout "\033[1m[$G_PROG_NAME]\033[0m Compiling Python"
sysout ""

# Compiling Python
# We'll be using half the available cores for make
echoAndExec make -j "$((PROC_COUNT / 2))" 2>&1

sysout ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "\033[1m[$G_PROG_NAME]\033[0m Press [ENTER] to continue" && sysout ""
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

        # --junit-xml is not available for Python 2.7, so for Python 2.7 we use verbose test output,
        # and for Python 3.x we use non-verbose output with --junit-xml
        EXTRA_TEST_ARGS=()
        if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
            EXTRA_TEST_ARGS+=("-w")
            EXTRA_TEST_ARGS+=("--junit-xml=$test_result_xml_file")
        else
            EXTRA_TEST_ARGS+=("--verbose")
        fi

        # Running the tests
        #
        # * We'll be using half the available cores for the tests
        #
        # * Deliberately not running this on multiple processes with -j,
        # because in that case some of the tests might get skipped
        #
        # * Yes, in its native compiled-only state, it's python.exe :D
        echoAndExec ./python.exe -W default -bb -m test -j "$((PROC_COUNT / 2))" -u all "${EXTRA_TEST_ARGS[@]}" 2>&1 | tee "$test_log_file"
    )

    # shellcheck disable=SC2181
    if [[ "$?" -eq 0 ]]; then
        # Waiting for the user's confirmation
        if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
            sysout ""
            ask "\033[1m[$G_PROG_NAME]\033[0m Press [ENTER] to continue"
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
        sysout >&2 ""
        sysout >&2 "[ERROR] THERE WERE TEST FAILURES"
        if [[ -f "$test_result_xml_file" ]]; then
            sysout >&2 "[ERROR] PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $test_log_file,"
            sysout >&2 "[ERROR] OR THE TEST RESULT XML FILE: $test_result_xml_file"
        else
            sysout >&2 "[ERROR] PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $test_log_file"
        fi
        sysout >&2 ""

        # Ask the user if they want to continue
        ask "\033[1m[$G_PROG_NAME]\033[0m Would you like to continue? ([y]/N)" response

        # If not, then we exit
        if [[ "$response" != "" ]] && [[ ! "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
            exit 1
        fi
    fi
}

if [[ "$P_NON_INTERACTIVE" -eq 1 ]]; then
    # In non-interactive mode we run the tests
    runTests && sysout ""
else
    # In interactive mode we ask the user whether they want to run the tests or not
    ask "\033[1m[$G_PROG_NAME]\033[0m Do you want to run the tests? ([y]/N)" response && sysout ""

    if [[ "$response" == "" ]] || [[ "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
        runTests && sysout ""
    fi
fi

sysout "\033[1m[$G_PROG_NAME]\033[0m Installing Python into $PYTHON_INSTALL_DIR"
sysout ""

# Installing Python to the destination directory
echoAndExec make install 2>&1

# Unsetting the compiler arguments
unset LDFLAGS CPPFLAGS LD_LIBRARY_PATH CC CXX LD

sysout ""

if [[ "$P_NON_INTERACTIVE" -ne 1 ]]; then
    ask "\033[1m[$G_PROG_NAME]\033[0m Press [ENTER] to continue" && sysout ""
fi

sysout "\033[1m[$G_PROG_NAME]\033[0m Creating links"
sysout ""

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

sysout "\033[1m[$G_PROG_NAME]\033[0m Locations:"
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    sysout "    * python2: $(which "python2")"
    sysout "    * pip2: $(which "pip2")"
else
    sysout "    * python$PY_POSTFIX: $(which "python$PY_POSTFIX")"
    sysout "    * pip$PY_POSTFIX: $(which "pip$PY_POSTFIX")"

    # If --extra-links was given, then we also print the python3 and pip3 links
    if [[ "$P_EXTRA_LINKS" -eq 1 ]]; then
        sysout "    * python3: $(which "python3")"
        sysout "    * pip3: $(which "pip3")"
    fi
fi
sysout ""

sysout "\033[1m[$G_PROG_NAME]\033[0m Upgrading pip and setuptools"
sysout ""

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

sysout ""
sysout "\033[1m[$G_PROG_NAME]\033[0m Installing virtualenv"
sysout ""

# Installing virtualenv
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    pip2 install virtualenv
else
    "pip$PY_POSTFIX" install virtualenv
fi

sysout ""
sysout "\033[1m[$G_PROG_NAME]\033[0m Creating a link for virtualenv"

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

sysout ""
sysout "\033[1m[$G_PROG_NAME]\033[0m It is recommended that you add $PYTHON_INSTALL_BASE to your PATH"
sysout "\033[1m[$G_PROG_NAME]\033[0m For that execute: export PATH=\"$PYTHON_INSTALL_BASE:\$PATH\""

sysout ""
sysout "\033[1m[$G_PROG_NAME]\033[0m Python $PY_POSTFIX successfully completed :)"
