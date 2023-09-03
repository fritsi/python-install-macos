#!/usr/bin/env bash

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

SUPPORTED_VERSIONS=("2.7.18" "3.6.15" "3.7.17" "3.8.18" "3.9.18" "3.10.13" "3.11.5")

SUPPORTED_VERSIONS_TEXT="$(versions="${SUPPORTED_VERSIONS[*]}" && echo "${versions// /, }")"

function printUsage() {
    sysout "${FNT_BLD}${FNT_ULN}Usage:${FNT_RST} ./$G_PROG_NAME.sh {pythonVersion} {installBaseDir}"
    sysout ""
    sysout "This script will assist you in compiling Python from source for both Apple Intel and Apple Silicon platforms"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} Currently only macOS is supported!"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}Supported Python versions:${FNT_RST} $SUPPORTED_VERSIONS_TEXT"
    sysout ""
    sysout "The provided ${FNT_ITC}'installBaseDir'${FNT_RST} is not the final installation directory, but a subdirectory within it."
    sysout "For example, for Python 3.8, it will be ${FNT_BLD}${FNT_ITC}${FNT_ULN}{installBaseDir}/python-3.8${FNT_RST}"
    sysout ""
    sysout "The script will prompt you to choose whether you want to run the Python tests or not."
    sysout "This allows you to verify the integrity of the compiled Python installation."
    sysout ""
    sysout "${FNT_BLD}If you followed the instructions, there should be no failures.${FNT_RST}"
    sysout ""
    sysout "If any test failures occur, the script will pause and ask if you want to proceed."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} In non-interactive mode, the script will always run the tests."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE 2:${FNT_RST} During the test execution, you may see a pop-up window requesting permission for Python to connect to the network."
    sysout "This is related to socket/ssl tests and is safe to allow."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}Optional arguments:${FNT_RST}"
    sysout ""
    sysout "    ${FNT_BLD}--non-interactive${FNT_RST} - If provided, no confirmation prompts will be displayed."
    sysout ""
    sysout "    ${FNT_BLD}--extra-links${FNT_RST} - For Python 3, this option creates additional symbolic links for pip3.x, python3.x,"
    sysout "                     and virtualenv3.x, in addition to pip3, python3, and virtualenv3."
    sysout ""
    sysout "    ${FNT_BLD}--keep-working-dir${FNT_RST} - The working directory will be retained after script completion or exit."
    sysout ""
    sysout "    ${FNT_BLD}--keep-test-logs${FNT_RST} - The test log file will be preserved even if all tests pass."
    sysout ""
    sysout "    ${FNT_BLD}--dry-run${FNT_RST} - Only the commands that would be executed will be printed."
    sysout "                ${FNT_BLD}NOTE:${FNT_RST} Collection of GNU binaries will still be performed."
    sysout ""

    # Also printing out the preparation steps
    printPreparationSteps
}

function printPreparationSteps() {
    sysout "${FNT_BLD}${FNT_ULN}You need to install several dependencies using Homebrew:${FNT_RST}"
    sysout ""
    sysout "${FNT_BLD}brew install${FNT_RST} asciidoc autoconf bzip2 coreutils diffutils expat findutils gawk \\"
    sysout "             gcc gdbm gnu-sed gnu-tar gnu-which gnunet grep jq libffi libtool \\"
    sysout "             libx11 libxcrypt lzo mpdecimal openssl@1.1 openssl@3.0 p7zip \\"
    sysout "             pkg-config unzip wget xz zlib"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} The above command ${FNT_BLD}not${FNT_RST} only installs libraries but also some ${FNT_BLD}GNU${FNT_RST} executables."
    sysout "      These executables are not used by default, but ${FNT_ITC}search-libraries.sh${FNT_RST} will temporarily add them to the PATH."
    sysout "      These dependencies are helpful because the default macOS counterparts may be outdated in certain cases."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} Once you have completed the above steps, you also need to install additional formulas:"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/ncurses-fritsi-mod.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/readline-fritsi-mod.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/gettext-fritsi-mod.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/zstd-fritsi-mod.rb\"${FNT_RST}"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}IMPORTANT:${FNT_RST} Please ensure that you install them in the specified order mentioned above."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} Finally, depending on the Python version you are compiling, you'll need:"
    sysout ""
    sysout "${FNT_BLD}a)${FNT_RST} for Python ${FNT_BLD}${FNT_ULN}3.8${FNT_RST}${FNT_BLD} or above:${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/libzip-fritsi-mod-with-openssl3.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/tcl-tk-fritsi-mod-with-openssl3.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/sqlite-fritsi-mod-with-openssl3.rb\"${FNT_RST}"
    sysout ""
    sysout "${FNT_BLD}b)${FNT_RST} for Python ${FNT_BLD}${FNT_ULN}3.7${FNT_RST}${FNT_BLD} or below:${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/libzip-fritsi-mod.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/tcl-tk-fritsi-mod.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/sqlite-fritsi-mod.rb\"${FNT_RST}"
    sysout "      >> ${FNT_ITC}brew install --formula --build-from-source \"formulas/libffi33.rb\"${FNT_RST}"
    sysout ""
}

if [[ "$#" -eq 1 ]] && [[ "$1" == "--help" ]]; then
    printUsage
    exit 0
fi

# Searching for GNU programs and adding them to the PATH
source "$SCRIPTS_DIR/libraries/search-gnu-progs.sh"

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

printPreparationSteps

ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Did you perform the above? ([y]/N)" response

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

# Checking whether the version provided to the script is a valid version or not
{
    __isValidVersion=false
    for __supportedVersion in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$__supportedVersion" == "$PYTHON_VERSION" ]]; then
            __isValidVersion=true
            break
        fi
    done
    if ! $__isValidVersion; then
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Invalid Python versions: '$PYTHON_VERSION'. Supported versions are: $SUPPORTED_VERSIONS_TEXT"
        sysout >&2 ""
        exit 1
    fi
    unset __isValidVersion __supportedVersion
}

# Validating the installation base directory
if [[ ! -d "$PYTHON_INSTALL_BASE" ]]; then
    sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} The install base directory does not exists: '$PYTHON_INSTALL_BASE'"
    sysout >&2 ""
    exit 1
fi

# Splitting up the Python version at the dots
IFS='.' read -ra __pythonVersionParts <<< "$PYTHON_VERSION"

# Keeping only the major and minor version
# E.g.: '3.9.14' becomes '3.9'
PY_POSTFIX="${__pythonVersionParts[0]}.${__pythonVersionParts[1]}"

# Converting the Python major.minor version into its numeric representation
# E.g.: 2.7 -> 207; 3.6 -> 306; 3.9 -> 309; 3.10 -> 310
PY_VERSION_NUM="$((__pythonVersionParts[0] * 100 + __pythonVersionParts[1]))"

# We no longer need this
unset __pythonVersionParts

shift 2

# Getting the current millis which can be used across the scripts
G_PY_COMPILE_CURRENT_MILLIS="$(date "+%s")"
export G_PY_COMPILE_CURRENT_MILLIS

export P_NON_INTERACTIVE=false
export P_EXTRA_LINKS=false
export P_KEEP_WORKING_DIR=false
export P_KEEP_TEST_LOGS=false
export P_DRY_RUN_MODE=false

# Checking the rest of the arguments
while [[ "$#" -gt 0 ]]; do
    # Getting the next argument
    argument="$1"
    shift

    case "$argument" in
        --non-interactive)
            export P_NON_INTERACTIVE=true
            ;;
        --extra-links)
            export P_EXTRA_LINKS=true
            ;;
        --keep-working-dir)
            export P_KEEP_WORKING_DIR=true
            ;;
        --keep-test-logs)
            export P_KEEP_TEST_LOGS=true
            ;;
        --dry-run)
            export P_DRY_RUN_MODE=true
            # Setting the name of the temporary file where we'll store the commands we'd execute
            G_PY_COMPILE_COMMANDS_FILE="$(cd "$TMPDIR" && pwd)/python-$PYTHON_VERSION-install-commands.$G_PY_COMPILE_CURRENT_MILLIS.sh"
            export G_PY_COMPILE_COMMANDS_FILE
            ;;
        *)
            sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Unrecognized argument: '$argument'"
            sysout >&2 ""
            exit 1
            ;;
    esac
done

if $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}!!! WE ARE IN DRY RUN MODE${FNT_RST}"
    sysout ""

    # Deleting the temporary command file on exit
    trap 'rm -rf "$G_PY_COMPILE_COMMANDS_FILE"' EXIT

    # When we are in dry run mode, then we control these variables
    export P_NON_INTERACTIVE=true
    export P_KEEP_WORKING_DIR=false
    export P_KEEP_TEST_LOGS=false

    {
        echo "export WORKING_DIR=\"{SET THIS TO A TEMPORARY DIRECTORY}\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Validating the --extra-links argument's purpose
if $P_EXTRA_LINKS && [[ "$PY_VERSION_NUM" -lt 300 ]]; then
    sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} --extra-links can only be used with Python 3"
    sysout >&2 ""
    exit 1
fi

# Assembling the final installation directory
PYTHON_INSTALL_DIR="$PYTHON_INSTALL_BASE/python-$PY_POSTFIX"

# Function to check whether a given path is not a file/directory/link
function checkNotExists() {
    if [[ -f "$1" ]] || [[ -d "$1" ]] || [[ -L "$1" ]]; then
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} The following file or directory already exists: $1"
        sysout >&2 ""
        return 1
    fi
}

WORKING_DIR="$(cd "$TMPDIR" && pwd)/python-$PYTHON_VERSION-temp.$G_PY_COMPILE_CURRENT_MILLIS"
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
    if $P_EXTRA_LINKS; then
        checkNotExists "$PYTHON_INSTALL_BASE/python3"
        checkNotExists "$PYTHON_INSTALL_BASE/pip3"
        checkNotExists "$PYTHON_INSTALL_BASE/virtualenv3"
    fi
fi

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Will install Python version: ${FNT_BLD}$PYTHON_VERSION${FNT_RST} into ${FNT_BLD}$PYTHON_INSTALL_DIR${FNT_RST}"
    sysout ""

    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Using working directory: ${FNT_BLD}$WORKING_DIR${FNT_RST}"
    sysout ""
fi

if ! $P_NON_INTERACTIVE; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Do you want to continue? ([y]/N)" response

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

if ! $P_DRY_RUN_MODE; then
    mkdir -p "$WORKING_DIR"

    # This method will be invoked when we exit from the script
    # This will eventually delete our temporary directory
    function deleteWorkingDirectory() {
        sysout ""

        if ! $P_KEEP_WORKING_DIR; then
            sysout "${FNT_BLD}[EXIT]${FNT_RST} Deleting $WORKING_DIR"
            rm -rf "$WORKING_DIR"
        else
            sysout "${FNT_BLD}[EXIT]${FNT_RST} Keeping $WORKING_DIR"
        fi
    }

    export -f deleteWorkingDirectory

    trap "deleteWorkingDirectory" EXIT
fi

# We are compiling Python here (needed for libraries/search-libraries.sh)
# shellcheck disable=SC2034
G_PYTHON_COMPILE=true

# Searching for the necessary libraries to compile Python
source "$SCRIPTS_DIR/libraries/search-libraries.sh"

# Begin installation

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Downloading https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz into $WORKING_DIR/Python-$PYTHON_VERSION.tgz"
    sysout ""

    wget --no-verbose --no-check-certificate --no-hsts "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -O "$WORKING_DIR/Python-$PYTHON_VERSION.tgz"

    cd "$WORKING_DIR"
else
    {
        echo "wget --no-verbose --no-check-certificate --no-hsts \"https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz\" -O \"\$WORKING_DIR/Python-$PYTHON_VERSION.tgz\""
        echo ""
        echo "cd \"\$WORKING_DIR\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

if ! $P_DRY_RUN_MODE; then
    sysout ""
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Extracting Python-$PYTHON_VERSION.tgz"
    sysout ""

    tar xzf "Python-$PYTHON_VERSION.tgz"

    cd "$WORKING_DIR/Python-$PYTHON_VERSION"
else
    {
        echo "tar xzf \"Python-$PYTHON_VERSION.tgz\""
        echo ""
        echo "cd \"\$WORKING_DIR/Python-$PYTHON_VERSION\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Applying the patch file

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Applying the patch file onto the Python source code"
    sysout ""

    patch -p1 < "$SCRIPTS_DIR/patches/Python-$PYTHON_VERSION.patch"

    sysout ""
else
    {
        echo "patch -p1 < \"$SCRIPTS_DIR/patches/Python-$PYTHON_VERSION.patch\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# But after all files have been patched, we do ask for one if we need to
if ! $P_NON_INTERACTIVE; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Configuring the Compiler"
    sysout ""

    # These are needed, so the gcc coming from brew does not get picked-up
    export CC="/usr/bin/gcc"
    export CXX="/usr/bin/g++"
    export LD="/usr/bin/g++"

    # Unset these if they are set
    unset PYTHONHOME PYTHONPATH
else
    {
        echo "export CC=\"/usr/bin/gcc\""
        echo "export CXX=\"/usr/bin/g++\""
        echo "export LD=\"/usr/bin/g++\""
        echo ""
        echo "unset PYTHONHOME PYTHONPATH"
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Override the auto-detection in setup.py, which assumes a universal build
# This is only available since Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    if $IS_APPLE_SILICON; then
        if ! $P_DRY_RUN_MODE; then
            export PYTHON_DECIMAL_WITH_MACHINE="uint128"
        else
            echo "export PYTHON_DECIMAL_WITH_MACHINE=\"uint128\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi
    else
        if ! $P_DRY_RUN_MODE; then
            export PYTHON_DECIMAL_WITH_MACHINE="x64"
        else
            echo "export PYTHON_DECIMAL_WITH_MACHINE=\"x64\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi
    fi

    if ! $P_DRY_RUN_MODE; then
        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} export PYTHON_DECIMAL_WITH_MACHINE=\"$PYTHON_DECIMAL_WITH_MACHINE\""
        sysout ""
    else
        echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
fi

# Parameters used for ./configure
CONFIGURE_PARAMS=(
    "--prefix=$PYTHON_INSTALL_DIR"
    "--with-ensurepip=install"
    "--enable-optimizations"
    "--enable-ipv6"
    "--with-dbmliborder=gdbm:ndbm"
    "--with-system-expat"
    "--with-system-ffi"
)

# --enable-unicode=ucs4 is only available for Python 2
if [[ "$PY_VERSION_NUM" -lt 300 ]]; then
    CONFIGURE_PARAMS+=("--enable-unicode=ucs4")
fi

# --with-system-libmpdec is only available from Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    CONFIGURE_PARAMS+=("--with-system-libmpdec")
fi

# --with-openssl is only available from Python 3.7
if [[ "$PY_VERSION_NUM" -ge 307 ]]; then
    CONFIGURE_PARAMS+=("--with-openssl=$L_OPENSSL_BASE")
fi

# --enable-loadable-sqlite-extensions is only available from Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    CONFIGURE_PARAMS+=("--enable-loadable-sqlite-extensions")
fi

# --with-tcltk-includes and --with-tcltk-libs is NOT available since Python 3.11
if [[ "$PY_VERSION_NUM" -lt 311 ]]; then
    CONFIGURE_PARAMS+=("--with-tcltk-includes=-I$L_TCL_TK_BASE/include")
    CONFIGURE_PARAMS+=("--with-tcltk-libs=-L$L_TCL_TK_BASE/lib -ltk8.6 -ltcl8.6 -DWITH_APPINIT")
fi

function macOsVersion() {
    local macOsVersionName
    local macOsVersionParts

    # Getting the full version, e.g.: '11.6.8'
    macOsVersionName="$(sw_vers -productVersion)"

    # Splitting the version by dots
    IFS='.' read -ra macOsVersionParts <<< "$macOsVersionName"

    # 11 is BigSur
    # For that and above that we only need the major version, because they mean:
    # Big Sur:  "11"
    # Monterey: "12"
    # Ventura:  "13"
    if [[ "${macOsVersionParts[0]}" -ge 11 ]]; then
        echo -n "${macOsVersionParts[0]}"
    # Below that we need that major and minor versions, because for these the versions means:
    # El Capitan:  "10.11"
    # Sierra:      "10.12"
    # High Sierra: "10.13"
    # Mojave:      "10.14"
    # Catalina:    "10.15"
    else
        echo -n "${macOsVersionParts[0]}.${macOsVersionParts[1]}"
    fi
}

# Avoid linking to libgcc https://mail.python.org/pipermail/python-dev/2012-February/116205.html
CONFIGURE_PARAMS+=("MACOSX_DEPLOYMENT_TARGET=$(macOsVersion)")

# Setting the extra compiler flags we use in the setup files
if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} export EXT_COMPILER_FLAGS=\"\$CPPFLAGS \$LDFLAGS\""
    sysout ""

    export EXT_COMPILER_FLAGS="$CPPFLAGS $LDFLAGS"
else
    {
        echo "export EXT_COMPILER_FLAGS=\"\$CPPFLAGS \$LDFLAGS\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Configuring Python
echoAndExec ./configure "${CONFIGURE_PARAMS[@]}" 2>&1

if ! $P_DRY_RUN_MODE; then
    sysout ""
else
    echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

if ! $P_NON_INTERACTIVE; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi

# Saving the number of processors
PROC_COUNT="$(nproc)"

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Compiling Python"
    sysout ""
fi

# Compiling Python
# We'll be using half the available cores for make
echoAndExec make "-j$((PROC_COUNT / 2))" 2>&1

if ! $P_DRY_RUN_MODE; then
    sysout ""

    # No longer need this
    unset EXT_COMPILER_FLAGS
else
    {
        echo ""
        echo "unset EXT_COMPILER_FLAGS"
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

if ! $P_NON_INTERACTIVE; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi

function runTests() {
    local testLogDir
    local testLogFile
    local testsExitCode

    # The directory where we'll put the test log
    testLogDir="$PYTHON_INSTALL_BASE/python-install-logs"

    # Creating the directory if it does not exist
    if [[ ! -d "$testLogDir" ]]; then
        mkdir "$testLogDir"
    fi

    testLogFile="$testLogDir/python-$PYTHON_VERSION-tests.log"

    # Turning off exit in case of a failure, so we can explicitly check the exit code of the python -m test command
    set +euo pipefail

    (
        set -o pipefail

        if ! $P_DRY_RUN_MODE; then
            # Needed for some of the tests
            export LC_ALL="en_US.UTF-8"
            export LANG="en_US.UTF-8"

            # unsetting these as they would mess with the tests
            unset PYTHONHTTPSVERIFY DISPLAY

            # Getting rid of some warnings in the tests
            export TK_SILENCE_DEPRECATION=1
        else
            {
                echo "# To run the tests, execute:"
                echo ""
                echo "("
                echo "    export LC_ALL=\"en_US.UTF-8\""
                echo "    export LANG=\"en_US.UTF-8\""
                echo ""
                echo "    unset PYTHONHTTPSVERIFY DISPLAY"
                echo ""
                echo "    export TK_SILENCE_DEPRECATION=1"
                echo ""
            } >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi

        # Running the tests
        #
        # * We'll be using half the available cores for the tests
        #
        # * Deliberately not running this on multiple processes with -j,
        # because in that case some of the tests might get skipped
        #
        # * Yes, in its native compiled-only state, it's python.exe :D
        if ! $P_DRY_RUN_MODE; then
            echoAndExec ./python.exe -W default -bb -m test "-j$((PROC_COUNT / 2))" -w -u all 2>&1 | tee "$testLogFile"
        else
            {
                echo "    ./python.exe -W default -bb -m test -j$((PROC_COUNT / 2)) -w -u all"
                echo ")"
            } >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi
    )

    # Saving the exit code of the above block in a variable
    testsExitCode="$?"

    # Nothing more to do when we are in dry-run mode
    if $P_DRY_RUN_MODE; then
        return 0
    fi

    if [[ "$testsExitCode" -eq 0 ]]; then
        # Waiting for the user's confirmation
        if ! $P_NON_INTERACTIVE; then
            sysout ""
            ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"
        fi

        # Turning on exit code check again
        set -euo pipefail

        # Deleting the test log if we don't want to keep it
        if ! $P_KEEP_TEST_LOGS; then
            rm -rf "$testLogFile"
        fi

        # Nothing else to do here
        return 0
    else
        sysout >&2 ""
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} THERE WERE TEST FAILURES"
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $testLogFile"
        sysout >&2 ""

        # Ask the user if they want to continue
        ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Would you like to continue? ([y]/N)" response

        # If not, then we exit
        if [[ "$response" != "" ]] && [[ ! "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
            exit 1
        fi
    fi
}

if $P_NON_INTERACTIVE; then
    # In non-interactive mode we run the tests
    runTests && sysout ""
else
    # In interactive mode we ask the user whether they want to run the tests or not
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Do you want to run the tests? ([y]/N)" response && sysout ""

    if [[ "$response" == "" ]] || [[ "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
        runTests && sysout ""
    fi
fi

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Installing Python into $PYTHON_INSTALL_DIR"
    sysout ""
else
    echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Installing Python to the destination directory
echoAndExec make install 2>&1

# Unsetting the compiler arguments
if ! $P_DRY_RUN_MODE; then
    sysout ""

    unset LDFLAGS CFLAGS CPPFLAGS CPATH LIBRARY_PATH PKG_CONFIG_PATH CC CXX LD
else
    {
        echo ""
        echo "unset LDFLAGS CFLAGS CPPFLAGS CPATH LIBRARY_PATH PKG_CONFIG_PATH CC CXX LD"
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

if ! $P_NON_INTERACTIVE; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Creating links"
    sysout ""
fi

# Creating symbolic links for pip and the python command
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    if ! $P_DRY_RUN_MODE; then
        ln -s "$PYTHON_INSTALL_DIR/bin/python2" "$PYTHON_INSTALL_BASE/python2"
        ln -s "$PYTHON_INSTALL_DIR/bin/pip2" "$PYTHON_INSTALL_BASE/pip2"
    else
        {
            echo "ln -s \"$PYTHON_INSTALL_DIR/bin/python2\" \"$PYTHON_INSTALL_BASE/python2\""
            echo "ln -s \"$PYTHON_INSTALL_DIR/bin/pip2\" \"$PYTHON_INSTALL_BASE/pip2\""
        } >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
else
    if ! $P_DRY_RUN_MODE; then
        ln -s "$PYTHON_INSTALL_DIR/bin/python3" "$PYTHON_INSTALL_BASE/python$PY_POSTFIX"
        ln -s "$PYTHON_INSTALL_DIR/bin/pip3" "$PYTHON_INSTALL_BASE/pip$PY_POSTFIX"
    else
        {
            echo "ln -s \"$PYTHON_INSTALL_DIR/bin/python3\" \"$PYTHON_INSTALL_BASE/python$PY_POSTFIX\""
            echo "ln -s \"$PYTHON_INSTALL_DIR/bin/pip3\" \"$PYTHON_INSTALL_BASE/pip$PY_POSTFIX\""
        } >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi

    # If --extra-links was given, then we also create the python3 and pip3 symbolic links
    if $P_EXTRA_LINKS; then
        if ! $P_DRY_RUN_MODE; then
            ln -s "$PYTHON_INSTALL_DIR/bin/python3" "$PYTHON_INSTALL_BASE/python3"
            ln -s "$PYTHON_INSTALL_DIR/bin/pip3" "$PYTHON_INSTALL_BASE/pip3"
        else
            {
                echo "ln -s \"$PYTHON_INSTALL_DIR/bin/python3\" \"$PYTHON_INSTALL_BASE/python3\""
                echo "ln -s \"$PYTHON_INSTALL_DIR/bin/pip3\" \"$PYTHON_INSTALL_BASE/pip3\""
            } >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi
    fi
fi

if ! $P_DRY_RUN_MODE; then
    # Adding our new and shiny Python installation to the PATH
    prependVar PATH ':' "$PYTHON_INSTALL_BASE"

    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Locations:"

    if [[ "$PY_POSTFIX" == "2.7" ]]; then
        sysout "    * python2: $(command -v "python2")"
        sysout "    * pip2: $(command -v "pip2")"
    else
        sysout "    * python$PY_POSTFIX: $(command -v "python$PY_POSTFIX")"
        sysout "    * pip$PY_POSTFIX: $(command -v "pip$PY_POSTFIX")"

        # If --extra-links was given, then we also print the python3 and pip3 links
        if $P_EXTRA_LINKS; then
            sysout "    * python3: $(command -v "python3")"
            sysout "    * pip3: $(command -v "pip3")"
        fi
    fi

    sysout ""

    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Upgrading pip, setuptools and wheel"
    sysout ""
else
    {
        echo ""
        echo "export PATH=\"$PYTHON_INSTALL_BASE:\$PATH\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Upgrading pip
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    if ! $P_DRY_RUN_MODE; then
        pip2 install --upgrade pip
    else
        echo "pip2 install --upgrade pip" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
else
    if ! $P_DRY_RUN_MODE; then
        "pip$PY_POSTFIX" install --upgrade pip
    else
        echo "pip$PY_POSTFIX install --upgrade pip" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
fi

# Upgrading setuptools and wheel
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    if ! $P_DRY_RUN_MODE; then
        pip2 install --upgrade setuptools wheel
    else
        echo "pip2 install --upgrade setuptools wheel" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
else
    if ! $P_DRY_RUN_MODE; then
        "pip$PY_POSTFIX" install --upgrade setuptools wheel
    else
        echo "pip$PY_POSTFIX install --upgrade setuptools wheel" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
fi

if ! $P_DRY_RUN_MODE; then
    sysout ""
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Installing virtualenv"
    sysout ""
fi

# Installing virtualenv
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    if ! $P_DRY_RUN_MODE; then
        pip2 install virtualenv
    else
        echo "pip2 install virtualenv" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
else
    if ! $P_DRY_RUN_MODE; then
        "pip$PY_POSTFIX" install virtualenv
    else
        echo "pip$PY_POSTFIX install virtualenv" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
fi

if ! $P_DRY_RUN_MODE; then
    sysout ""
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Creating a link for virtualenv"
else
    echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Creating a symbolic link for virtualenv
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    if ! $P_DRY_RUN_MODE; then
        ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv2"
    else
        echo "ln -s \"$PYTHON_INSTALL_DIR/bin/virtualenv\" \"$PYTHON_INSTALL_BASE/virtualenv2\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
else
    if ! $P_DRY_RUN_MODE; then
        ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv$PY_POSTFIX"
    else
        echo "ln -s \"$PYTHON_INSTALL_DIR/bin/virtualenv\" \"$PYTHON_INSTALL_BASE/virtualenv$PY_POSTFIX\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi

    # If --extra-links was given, then we also create the virtualenv3 symbolic link
    if $P_EXTRA_LINKS; then
        if ! $P_DRY_RUN_MODE; then
            ln -s "$PYTHON_INSTALL_DIR/bin/virtualenv" "$PYTHON_INSTALL_BASE/virtualenv3"
        else
            echo "ln -s \"$PYTHON_INSTALL_DIR/bin/virtualenv\" \"$PYTHON_INSTALL_BASE/virtualenv3\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi
    fi
fi

if ! $P_DRY_RUN_MODE; then
    sysout ""
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} It is recommended that you add $PYTHON_INSTALL_BASE to your PATH"
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} For that execute: export PATH=\"$PYTHON_INSTALL_BASE:\$PATH\""

    sysout ""
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Python $PY_POSTFIX installation successfully completed :)"
else
    sysout "${FNT_BLD}${FNT_ULN}THE PYTHON INSTALL SCRIPT:${FNT_RST}"
    sysout ""

    cat "$G_PY_COMPILE_COMMANDS_FILE"

    sysout ""
fi
