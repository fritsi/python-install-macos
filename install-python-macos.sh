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

SUPPORTED_VERSIONS=("2.7.18" "3.6.15" "3.7.17" "3.8.18" "3.9.18" "3.10.13" "3.11.7" "3.12.1")

SUPPORTED_VERSIONS_TEXT="$(versions="${SUPPORTED_VERSIONS[*]}" && echo "${versions// /, }")"

function printUsage() {
    sysout "${FNT_BLD}${FNT_ULN}Usage:${FNT_RST}"
    sysout ""
    sysout "./$G_PROG_NAME.sh --help"
    sysout ""
    sysout "./$G_PROG_NAME.sh {pythonVersion} {installBaseDir}"
    sysout "                          [--dry-run]"
    sysout "                          [--non-interactive]"
    sysout "                          [--extra-links]"
    sysout "                          [--use-x11]"
    sysout "                          [--keep-working-dir]"
    sysout "                          [--keep-test-logs]"
    sysout ""
    sysout "This script will assist you in compiling Python from source ${FNT_ITC}(including some of the required${FNT_RST}"
    sysout "${FNT_ITC}dependent packages)${FNT_RST} for both Apple Intel and Apple Silicon platforms."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}Supported Python versions:${FNT_RST} $SUPPORTED_VERSIONS_TEXT"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} Currently only macOS is supported!"
    sysout ""
    sysout "The provided ${FNT_ITC}'installBaseDir'${FNT_RST} is not the final installation directory, but a sub-directory within"
    sysout "it. For example, for Python 3.8, the final install directory will be ${FNT_BLD}${FNT_ITC}${FNT_ULN}{installBaseDir}/python-3.8${FNT_RST}"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}Optional arguments:${FNT_RST}"
    sysout ""
    sysout "  ${FNT_BLD}--dry-run${FNT_RST}"
    sysout "      Only the commands that would be executed will be printed. ${FNT_BLD}NOTE:${FNT_RST} Collection of GNU binaries"
    sysout "      will still be performed."
    sysout ""
    sysout "  ${FNT_BLD}--non-interactive${FNT_RST}"
    sysout "      If provided, ${FNT_BLD}no${FNT_RST} confirmation prompts will be displayed."
    sysout ""
    sysout "  ${FNT_BLD}--extra-links${FNT_RST}"
    sysout "      For Python 3, this option creates additional symbolic links for pip3, python3, and"
    sysout "      virtualenv3, in addition to pip3.x, python3.x, and virtualenv3.x."
    sysout ""
    sysout "  ${FNT_BLD}--use-x11${FNT_RST}"
    sysout "      This will instruct the compiler to use X11 instead of the macOS Aqua windowing system."
    sysout "      I ${FNT_BLD}${FNT_ULN}highly advise${FNT_RST} to use this option. ${FNT_ITC}See more information in the README file.${FNT_RST}"
    sysout ""
    sysout "  ${FNT_BLD}--keep-working-dir${FNT_RST}"
    sysout "      The temporary working directory will be retained after script completion or exit."
    sysout ""
    sysout "  ${FNT_BLD}--keep-test-logs${FNT_RST}"
    sysout "      The test log file will be preserved even if all tests pass."
    sysout ""
    sysout "The script will prompt you to choose whether you want to run the Python tests or not. This allows"
    sysout "you to verify the integrity of the compiled Python installation."
    sysout ""
    sysout "${FNT_BLD}If you followed the instructions, there should be no failures.${FNT_RST} In case of any test failures, the"
    sysout "script will halt and prompt you for further action."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} In non-interactive mode, the script will always run the tests."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE 2:${FNT_RST} During the test execution, you may see a pop-up window requesting permission for Python"
    sysout "to connect to the network. This is related to socket/ssl tests and is safe to allow."
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
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} The above command ${FNT_BLD}not${FNT_RST} only installs libraries but also some ${FNT_BLD}GNU${FNT_RST} executables. These"
    sysout "executables are not used by default, but ${FNT_ITC}search-libraries.sh${FNT_RST} will temporarily add them to"
    sysout "the ${FNT_BLD}PATH${FNT_RST}. These dependencies are helpful because the default macOS counterparts may be"
    sysout "outdated in certain cases, and may not work as expected."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE 2:${FNT_RST} Some additional dependencies will be automatically installed by the installer script"
    sysout "itself. ${FNT_ITC}See more information in the README file.${FNT_RST}"
    sysout ""
    sysout "I also ${FNT_BLD}recommend${FNT_RST} executing ${FNT_ITC}${FNT_ULN}brew update${FNT_RST} and ${FNT_ITC}${FNT_ULN}brew upgrade${FNT_RST} as well."
    sysout ""
}

if [[ "$#" -eq 1 ]] && [[ "$1" == "--help" ]]; then
    printUsage | less -iR
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
if [[ "$response" != "" ]] && [[ ! "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
    exit 0
fi

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
export P_USE_X11=false

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
        --use-x11)
            # Validating that XQuartz is installed via checking some of its programs
            for x11ProgName in xauth xclipboard xset xsetroot; do
                if [[ "$(command -v "$x11ProgName" 2> /dev/null || true)" == "" ]]; then
                    sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} You have set --use-x11, but XQuartz does not seem to be installed"
                    sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Could not find $x11ProgName; did you install it with Homebrew?"
                    sysout >&2 ""
                    exit 1
                fi
            done
            unset x11ProgName

            # Setting that we want to use X11
            export P_USE_X11=true
            ;;
        *)
            sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Unrecognized argument: '$argument'"
            sysout >&2 ""
            exit 1
            ;;
    esac
done

if $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}!!! YOU ARE IN DRY RUN MODE${FNT_RST}"
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

    if [[ "$response" != "" ]] && [[ ! "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
        exit 0
    fi
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

# We need to check (and install in non dry run mode) the custom dependencies
{
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Checking whether the custom Homebrew formulas are installed or not"

    # In non dry run mode, we ask for confirmation if we are in interactive mode
    if ! $P_DRY_RUN_MODE && ! $P_NON_INTERACTIVE; then
        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} This will install missing custom ${FNT_ITC}(*-fritsi)${FNT_RST} Homebrew formulas"
        ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Do you want to continue? ([y]/N)" response

        if [[ "$response" != "" ]] && [[ ! "$response" =~ ^(([yY][eE][sS])|([yY]))$ ]]; then
            exit 0
        fi
    else
        sysout ""
    fi

    # Getting the already installed Homebrew packages
    T_ALREADY_INSTALLED="$({ brew list -1 2> /dev/null || true; } | xargs)"
    if [[ "$T_ALREADY_INSTALLED" == "" ]]; then
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Failed to get the already installed Homebrew packages"
        sysout >&2 ""
        exit 1
    fi
    # Prepending and appending a space for simpler searchability
    T_ALREADY_INSTALLED=" $T_ALREADY_INSTALLED "

    # Assembling the internal dependencies we need to install
    # We need to install them in the exact same order as we put them into the array
    T_DEPENDENCIES=("ncurses-fritsi" "readline-fritsi" "gettext-fritsi" "zstd-fritsi")
    if [[ "$PY_VERSION_NUM" -ge 308 ]]; then
        T_DEPENDENCIES+=("libzip-fritsi-with-openssl3")
        if ! $P_USE_X11; then
            T_DEPENDENCIES+=("tcl-tk-fritsi-with-openssl3" "sqlite-fritsi-with-openssl3")
        else
            T_DEPENDENCIES+=("tcl-tk-fritsi-with-x11-with-openssl3" "sqlite-fritsi-with-x11-with-openssl3")
        fi
    else
        T_DEPENDENCIES+=("libzip-fritsi")
        if ! $P_USE_X11; then
            T_DEPENDENCIES+=("tcl-tk-fritsi" "sqlite-fritsi")
        else
            T_DEPENDENCIES+=("tcl-tk-fritsi-with-x11" "sqlite-fritsi-with-x11")
        fi
        T_DEPENDENCIES+=("libffi33")
        T_DEPENDENCIES+=("expat25")
    fi

    # We'll collect the missing package here in case of dry run mode
    T_MISSING_PACKAGES=()

    # Checking each dependency and if one is not installed, then we install it
    for searchPackage in "${T_DEPENDENCIES[@]}"; do
        # The package is already installed, we can continue ...
        if [[ "$T_ALREADY_INSTALLED" == *" $searchPackage "* ]]; then
            sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Package ${FNT_BLD}$searchPackage${FNT_RST} ... ${FNT_ITC}INSTALLED${FNT_RST}"
            sysout ""

            continue
        fi

        # In dry run mode we simply ignore this for now
        if $P_DRY_RUN_MODE; then
            sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Package ${FNT_BLD}$searchPackage${FNT_RST} ... ${FNT_BLD}NOT INSTALLED${FNT_RST}"
            sysout ""

            # Adding the missing package
            T_MISSING_PACKAGES+=("$searchPackage")

            continue
        fi

        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Package ${FNT_BLD}$searchPackage${FNT_RST} ... ${FNT_BLD}NOT INSTALLED${FNT_RST}; installing it now ..."
        sysout ""

        # Otherwise, we install it
        brew install --formula --build-from-source "$SCRIPTS_DIR/formulas/$searchPackage.rb" && sysout ""
    done

    # If we are in dry run mode, then we cannot continue until these are installed
    if $P_DRY_RUN_MODE && [[ "${#T_MISSING_PACKAGES[@]}" -gt 0 ]]; then
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} There is at least one missing pacakge you need to install"
        sysout >&2 ""
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Please install them with the following command(s) ${FNT_BLD}${FNT_ULN}${FNT_ITC}in this order${FNT_RST}:"
        sysout >&2 ""
        for searchPackage in "${T_MISSING_PACKAGES[@]}"; do
            sysout >&2 "  • ${FNT_ITC}brew install --formula --build-from-source \"$SCRIPTS_DIR/formulas/$searchPackage.rb\"${FNT_RST}"
        done
        sysout >&2 ""
        exit 1
    fi

    # We no longer need these
    unset T_ALREADY_INSTALLED T_DEPENDENCIES T_MISSING_PACKAGES searchPackage
}

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
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"
fi

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Configuring the Compiler"
    sysout ""

    # These are needed, so the gcc coming from Homebrew does not get picked-up
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

# From Python 3.12 we need to set the LIBFFI_LIBS and LIBFFI_CFLAGS variables
if [[ "$PY_VERSION_NUM" -ge 312 ]]; then
    if ! $P_DRY_RUN_MODE; then
        export LIBFFI_LIBS="-L$L_LIBFFI_BASE/lib -Wl,-rpath,$L_LIBFFI_BASE/lib -lffi"
        export LIBFFI_CFLAGS="-I$L_LIBFFI_BASE/include"

        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} export LIBFFI_LIBS=\"$LIBFFI_LIBS\""
        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} export LIBFFI_CFLAGS=\"$LIBFFI_CFLAGS\""
        sysout ""
    else
        {
            echo "export LIBFFI_LIBS=\"-L$L_LIBFFI_BASE/lib -Wl,-rpath,$L_LIBFFI_BASE/lib -lffi\""
            echo "export LIBFFI_CFLAGS=\"-I$L_LIBFFI_BASE/include\""
            echo ""
        } >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
fi

# Parameters used for ./configure
CONFIGURE_PARAMS=(
    "--prefix=$PYTHON_INSTALL_DIR"
    "--with-ensurepip=install"
    "--enable-optimizations"
    "--enable-ipv6"
    "--with-system-expat"
)

# --enable-unicode=ucs4 is only available for Python 2
if [[ "$PY_VERSION_NUM" -lt 300 ]]; then
    CONFIGURE_PARAMS+=("--enable-unicode=ucs4")
fi

# --with-system-libmpdec is only available from Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    CONFIGURE_PARAMS+=("--with-system-libmpdec")
fi

# --with-system-ffi is not available since Python 3.12
if [[ "$PY_VERSION_NUM" -lt 312 ]]; then
    CONFIGURE_PARAMS+=("--with-system-ffi")
fi

# From Python 3.10 we set the --with-readline parameter, but it's different from Python 3.12
if [[ "$PY_VERSION_NUM" -ge 312 ]]; then
    CONFIGURE_PARAMS+=("--with-readline=readline")
elif [[ "$PY_VERSION_NUM" -ge 310 ]]; then
    CONFIGURE_PARAMS+=("--with-readline")
fi

# Using a different --with-dbmliborder value since Python 3.11
if [[ "$PY_VERSION_NUM" -ge 311 ]]; then
    CONFIGURE_PARAMS+=("--with-dbmliborder=ndbm")
else
    CONFIGURE_PARAMS+=("--with-dbmliborder=gdbm:ndbm")
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

    # --with-tcltk-libs will be different when using X11
    if ! $P_USE_X11; then
        CONFIGURE_PARAMS+=("--with-tcltk-libs=-L$L_TCL_TK_BASE/lib -ltk8.6 -ltcl8.6 -DWITH_APPINIT")
    else
        CONFIGURE_PARAMS+=("--with-tcltk-libs=-L$L_TCL_TK_BASE/lib -ltk8.6 -ltcl8.6 -lX11 -DWITH_APPINIT")
    fi
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
    # Sonoma:   "14"
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
    if ! $P_USE_X11; then
        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} export EXT_COMPILER_FLAGS=\"\$CPPFLAGS \$LDFLAGS\""
    else
        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} export EXT_COMPILER_FLAGS=\"\$CPPFLAGS \$LDFLAGS -lX11\""
    fi
    sysout ""

    export EXT_COMPILER_FLAGS="$CPPFLAGS $LDFLAGS"

    # Adding -lX11
    if $P_USE_X11; then
        export EXT_COMPILER_FLAGS="$EXT_COMPILER_FLAGS -lX11"
    fi
else
    {
        if ! $P_USE_X11; then
            echo "export EXT_COMPILER_FLAGS=\"\$CPPFLAGS \$LDFLAGS\""
        else
            echo "export EXT_COMPILER_FLAGS=\"\$CPPFLAGS \$LDFLAGS -lX11\""
        fi
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
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Successfully configured Python $PYTHON_VERSION"
    sysout ""

    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"
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
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Successfully compiled Python $PYTHON_VERSION"
    sysout ""

    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"
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
            export LC_CTYPE="UTF-8"
            export LANG="en_US.UTF-8"
            export LANGUAGE="en_US:en"

            # Unsetting these as they would mess with the tests
            unset PYTHONHTTPSVERIFY
            if ! $P_USE_X11; then
                unset DISPLAY
            fi

            # Getting rid of some warnings in the tests
            export TK_SILENCE_DEPRECATION=1
        else
            {
                echo "# To run the tests, execute:"
                echo ""
                echo "("
                echo "    export LC_ALL=\"en_US.UTF-8\""
                echo "    export LC_CTYPE=\"UTF-8\""
                echo "    export LANG=\"en_US.UTF-8\""
                echo "    export LANGUAGE=\"en_US:en\""
                echo ""
                if ! $P_USE_X11; then
                    echo "    unset PYTHONHTTPSVERIFY DISPLAY"
                else
                    echo "    unset PYTHONHTTPSVERIFY"
                fi
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

    # Nothing more to do when we are in dry run mode
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
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Do you want to run the tests? ([y]/N)" response

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
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"
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
