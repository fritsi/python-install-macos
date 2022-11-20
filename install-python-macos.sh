#!/usr/bin/env bash

set -euo pipefail

clear

G_PROG_NAME="$(basename -s ".sh" "$0")"
export G_PROG_NAME

# The directory in which this script lives in
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Importing basic functions
source "$SCRIPTS_DIR/utils/fonts.sh"
source "$SCRIPTS_DIR/utils/print-func.sh"
source "$SCRIPTS_DIR/utils/exec-func.sh"

SUPPORTED_VERSIONS=("2.7.18" "3.6.15" "3.7.15" "3.8.15" "3.9.15" "3.10.8" "3.11.0")

SUPPORTED_VERSIONS_TEXT="$(versions="${SUPPORTED_VERSIONS[*]}" && echo "${versions// /, }")"

function printUsage() {
    sysout "${FNT_BLD}${FNT_ULN}Usage:${FNT_RST} ./$G_PROG_NAME.sh {pythonVersion} {installBaseDir}"
    sysout ""
    sysout "This script will download the given version of the Python source code, compile it, and install it to the given location."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} Currently only macOS is supported!"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}Supported Python versions:${FNT_RST} $SUPPORTED_VERSIONS_TEXT"
    sysout ""
    sysout "The given ${FNT_ITC}'installBaseDir'${FNT_RST} will not be the final install directory, but a subdirectory in that."
    sysout "For example in case of Python 3.8 it will be ${FNT_BLD}${FNT_ITC}${FNT_ULN}{installBaseDir}/python-3.8${FNT_RST}"
    sysout ""
    sysout "The script will ask you whether you want to run the Python tests or not."
    sysout "This can be used to check whether everything is okay with the compiled Python or not."
    sysout ""
    sysout "${FNT_BLD}If you followed the instructions, you should have no failures.${FNT_RST}"
    sysout ""
    sysout "If there are test failures, the script will stop and ask you if you'd like to continue."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} In case of non-interactive mode, the script will always run these tests."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE 2:${FNT_RST} While running the tests, you might see a pop-up window asking you to allow Python to connect to the network."
    sysout "These are for the socket/ssl related tests. It's safe to allow."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE 3:${FNT_RST} Currently the UI (Tkinter) related tests are deliberately skipped as they are unstable."
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}Optional arguments:${FNT_RST}"
    sysout ""
    sysout "    ${FNT_BLD}--non-interactive${FNT_RST} - If given then we won't ask for confirmations."
    sysout ""
    sysout "    ${FNT_BLD}--extra-links${FNT_RST} - In case of Python 3 besides the pip3.x, python3.x and virtualenv3.x symbolic links,"
    sysout "                    this will also create the pip3, python3 and virtualenv3 links."
    sysout ""
    sysout "    ${FNT_BLD}--keep-working-dir${FNT_RST} - We'll keep the working directory after the script finished / exited."
    sysout ""
    sysout "    ${FNT_BLD}--keep-test-results${FNT_RST} - We'll keep the test log and test result xml files even in case everything passed."
    sysout ""
    sysout "    ${FNT_BLD}--dry-run${FNT_RST} - We'll only print out the commands which would be executed."
    sysout "                ${FNT_BLD}NOTE:${FNT_RST} Collecting GNU binaries will still be executed."
    sysout ""

    # Also printing out the preparation steps
    printPreparationSteps
}

function printPreparationSteps() {
    sysout "${FNT_BLD}${FNT_ULN}As a preparation we suggest to perform the following:${FNT_RST}"
    sysout ""
    sysout "${FNT_BLD}brew install${FNT_RST} asciidoc autoconf bzip2 coreutils diffutils expat findutils gawk \\"
    sysout "             gcc gdbm gnu-sed gnu-tar gnu-which gnunet grep jq libffi libtool \\"
    sysout "             libx11 libxcrypt libzip lzo mpdecimal ncurses openssl@1.1 openssl@3 \\"
    sysout "             p7zip pkg-config readline sqlite tcl-tk unzip wget xz zlib"
    sysout ""
    sysout "${FNT_BLD}${FNT_ULN}NOTE:${FNT_RST} The above command does ${FNT_BLD}not${FNT_RST} only install libraries, but also a couple of ${FNT_BLD}GNU${FNT_RST} executables."
    sysout "      These will not be used by default, but ${FNT_ITC}search-libraries.sh${FNT_RST} will temporarily add it to PATH."
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
    IS_APPLE_SILICON=false
elif [[ "$(uname -m)" == "arm64" ]]; then
    IS_APPLE_SILICON=true
else
    sysout >&2 "[ERROR] Unsupported OS: $(uname) ($(uname -m))"
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
        sysout >&2 "[ERROR] Invalid Python versions: '$PYTHON_VERSION'. Supported versions are: $SUPPORTED_VERSIONS_TEXT"
        sysout >&2 ""
        exit 1
    fi
    unset __isValidVersion __supportedVersion
}

# Validating the installation base directory
if [[ ! -d "$PYTHON_INSTALL_BASE" ]]; then
    sysout >&2 "[ERROR] The install base directory does not exists: '$PYTHON_INSTALL_BASE'"
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
export P_KEEP_TEST_RESULTS=false
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
        --keep-test-results)
            export P_KEEP_TEST_RESULTS=true
            ;;
        --dry-run)
            export P_DRY_RUN_MODE=true
            # Setting the name of the temporary file where we'll store the commands we'd execute
            G_PY_COMPILE_COMMANDS_FILE="$(cd "$TMPDIR" && pwd)/python-$PYTHON_VERSION-install-commands.$G_PY_COMPILE_CURRENT_MILLIS.sh"
            export G_PY_COMPILE_COMMANDS_FILE
            ;;
        *)
            sysout >&2 "[ERROR] Unrecognized argument: '$argument'"
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
    export P_KEEP_TEST_RESULTS=false

    {
        echo "export WORKING_DIR=\"{SET THIS TO A TEMPORARY DIRECTORY}\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Validating the --extra-links argument's purpose
if $P_EXTRA_LINKS && [[ "$PY_VERSION_NUM" -lt 300 ]]; then
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
            sysout "[EXIT] Deleting $WORKING_DIR"
            rm -rf "$WORKING_DIR"
        else
            sysout "[EXIT] Keeping $WORKING_DIR"
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

    wget --no-verbose --no-check-certificate "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz" -O "$WORKING_DIR/Python-$PYTHON_VERSION.tgz"

    cd "$WORKING_DIR"
else
    {
        echo "wget --no-verbose --no-check-certificate \"https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz\" -O \"\$WORKING_DIR/Python-$PYTHON_VERSION.tgz\""
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

if ! $P_DRY_RUN_MODE; then
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Applying the patch file onto the Python source code"

    # Copying the patch file to our working directory as we need to replace '__openssl_install_dir__' in it
    cp "$SCRIPTS_DIR/patches/Python-$PYTHON_VERSION.patch" "$WORKING_DIR/Python-$PYTHON_VERSION.patch"
else
    echo "cp \"$SCRIPTS_DIR/patches/Python-$PYTHON_VERSION.patch\" \"\$WORKING_DIR/Python-$PYTHON_VERSION.patch\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Function to replace variables with a value in the patch file
function substituteVariableInPatch() {
    local variableName
    local variableValue

    variableName="$1"
    variableValue="$2"

    if ! $P_DRY_RUN_MODE; then
        sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Substituting '$variableName' with '$variableValue' in the patch file"

        sed -i "s/$variableName/$(echo "$variableValue" | sed 's/\//\\\//g' | sed 's/\./\\\./g')/g" "$WORKING_DIR/Python-$PYTHON_VERSION.patch"
    else
        echo "sed -i \"s/$variableName/$(echo "$variableValue" | sed 's/\//\\\//g' | sed 's/\./\\\./g')/g\" \"\$WORKING_DIR/Python-$PYTHON_VERSION.patch\"" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
}

if ! $P_DRY_RUN_MODE; then
    sysout ""
else
    echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Substituting some variable in the patch file
substituteVariableInPatch "__openssl_install_dir__" "$L_OPENSSL_BASE"
substituteVariableInPatch "__readline_install_dir__" "$L_READLINE_BASE"
substituteVariableInPatch "__tcl_tk_install_dir__" "$L_TCL_TK_BASE"
substituteVariableInPatch "__zlib_install_dir__" "$L_ZLIB_BASE"

if ! $P_DRY_RUN_MODE; then
    sysout ""
else
    echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Applying the patch file

if ! $P_DRY_RUN_MODE; then
    patch -p1 < "$WORKING_DIR/Python-$PYTHON_VERSION.patch"

    sysout ""
else
    {
        echo "patch -p1 < \"\$WORKING_DIR/Python-$PYTHON_VERSION.patch\""
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

# --with-system-libmpdec is only available from Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    CONFIGURE_PARAMS+=("--with-system-libmpdec")
fi

# --with-openssl is only available from Python 3.7
if [[ "$PY_VERSION_NUM" -ge 307 ]]; then
    CONFIGURE_PARAMS+=("--with-openssl=$L_OPENSSL_BASE")
fi

# --with-dtrace is only available from Python 3.9
if [[ "$PY_VERSION_NUM" -ge 309 ]]; then
    CONFIGURE_PARAMS+=("--with-dtrace")
fi

# --enable-loadable-sqlite-extensions is only available from Python 3
if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
    CONFIGURE_PARAMS+=("--enable-loadable-sqlite-extensions")
fi

# On non Apple-Silicon machines if the Python version is >= 3.7, then
# we add --enable-universalsdk and --with-universal-archs=intel-64 as well
if ! $IS_APPLE_SILICON && [[ "$PY_VERSION_NUM" -ge 307 ]]; then
    CONFIGURE_PARAMS+=("--enable-universalsdk")
    CONFIGURE_PARAMS+=("--with-universal-archs=intel-64")
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
echoAndExec make -j "$((PROC_COUNT / 2))" 2>&1

if ! $P_DRY_RUN_MODE; then
    sysout ""
else
    echo "" >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

if ! $P_NON_INTERACTIVE; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi

function runTests() {
    local testLogFile
    local testResultXmlFile
    local testsExitCode

    testLogFile="$PYTHON_INSTALL_BASE/python-$PYTHON_VERSION-tests.log"
    testResultXmlFile="$PYTHON_INSTALL_BASE/python-$PYTHON_VERSION-test-results.xml"

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

            # We don't want to run the Tkinter related tests as they are too unstable
            export UI_TESTS_ENABLED=0
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
                echo "    export UI_TESTS_ENABLED=0"
                echo ""
            } >> "$G_PY_COMPILE_COMMANDS_FILE"
        fi

        EXTRA_TEST_ARGS=()

        # --junit-xml is not available for Python 2.7, so for Python 2.7 we use verbose test output,
        # and for Python 3.x we use non-verbose output with --junit-xml
        if [[ "$PY_VERSION_NUM" -ge 300 ]]; then
            EXTRA_TEST_ARGS+=("-w")

            if ! $P_DRY_RUN_MODE; then
                EXTRA_TEST_ARGS+=("--junit-xml=$testResultXmlFile")
            else
                EXTRA_TEST_ARGS+=("--junit-xml=\"{SET THE JUNIT XML FILENAME}\"")
            fi
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
        if ! $P_DRY_RUN_MODE; then
            echoAndExec ./python.exe -W default -bb -m test -j "$((PROC_COUNT / 2))" -u all "${EXTRA_TEST_ARGS[@]}" 2>&1 | tee "$testLogFile"
        else
            {
                echo "    ./python.exe -W default -bb -m test -j $((PROC_COUNT / 2)) -u all ${EXTRA_TEST_ARGS[*]}"
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

        # Deleting the test log and test result xml files if we don't want to keep them
        if ! $P_KEEP_TEST_RESULTS; then
            rm -rf "$testLogFile" "$testResultXmlFile"
        fi

        # Nothing else to do here
        return 0
    else
        sysout >&2 ""
        sysout >&2 "[ERROR] THERE WERE TEST FAILURES"
        if [[ -f "$testResultXmlFile" ]]; then
            sysout >&2 "[ERROR] PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $testLogFile,"
            sysout >&2 "[ERROR] OR THE TEST RESULT XML FILE: $testResultXmlFile"
        else
            sysout >&2 "[ERROR] PLEASE CHECK THE FOLLOWING LOG FILE FOR MORE INFORMATION: $testLogFile"
        fi
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

    unset LDFLAGS CPPFLAGS LD_LIBRARY_PATH PKG_CONFIG_PATH CC CXX LD
else
    {
        echo ""
        echo "unset LDFLAGS CPPFLAGS LD_LIBRARY_PATH PKG_CONFIG_PATH CC CXX LD"
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
    export PATH="$PYTHON_INSTALL_BASE:$PATH"

    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Locations:"
    if [[ "$PY_POSTFIX" == "2.7" ]]; then
        sysout "    * python2: $(which "python2")"
        sysout "    * pip2: $(which "pip2")"
    else
        sysout "    * python$PY_POSTFIX: $(which "python$PY_POSTFIX")"
        sysout "    * pip$PY_POSTFIX: $(which "pip$PY_POSTFIX")"

        # If --extra-links was given, then we also print the python3 and pip3 links
        if $P_EXTRA_LINKS; then
            sysout "    * python3: $(which "python3")"
            sysout "    * pip3: $(which "pip3")"
        fi
    fi
    sysout ""

    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Upgrading pip and setuptools"
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

# Upgrading setuptools
if [[ "$PY_POSTFIX" == "2.7" ]]; then
    if ! $P_DRY_RUN_MODE; then
        pip2 install --upgrade setuptools
    else
        echo "pip2 install --upgrade setuptools" >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
else
    if ! $P_DRY_RUN_MODE; then
        "pip$PY_POSTFIX" install --upgrade setuptools
    else
        echo "pip$PY_POSTFIX install --upgrade setuptools" >> "$G_PY_COMPILE_COMMANDS_FILE"
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
    sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Python $PY_POSTFIX successfully completed :)"
else
    sysout "${FNT_BLD}${FNT_ULN}THE PYTHON INSTALL SCRIPT:${FNT_RST}"
    sysout ""

    cat "$G_PY_COMPILE_COMMANDS_FILE"

    sysout ""
fi
