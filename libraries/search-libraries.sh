##################################################################################
### This script will find all the necessary libraries required to build Python ###
##################################################################################

# Initializing the compiler "flags" as empty strings
export LDFLAGS=""
export CPPFLAGS=""
export LD_LIBRARY_PATH=""
export PKG_CONFIG_PATH=""

# The list of libraries we need to look-up, and set include / lib directories based on them for the compiler
# Some of them are definitely mandatory, others are optional for the Python build
T_LIBRARIES_TO_LOOKUP="bzip2 expat gdbm libxcrypt libzip mpdecimal ncurses readline sqlite tcl-tk xz zlib"

# Checking which version of libffi we need to use, and whether we need to install an older version or not
source "$SCRIPTS_DIR/libraries/setup-libffi.sh"

# Adding OpenSSL to the libraries to look-up when we are compiling Python
if $G_PYTHON_COMPILE; then
    # From Python 3.8 we can use OpenSSL 3
    if [[ "$PY_VERSION_NUM" -ge 308 ]]; then
        T_LIBRARIES_TO_LOOKUP="openssl@3 $T_LIBRARIES_TO_LOOKUP"
    # For older Python versions we need OpenSSL 1.1
    else
        T_LIBRARIES_TO_LOOKUP="openssl@1.1 $T_LIBRARIES_TO_LOOKUP"
    fi
fi

# From Python 3.10 we should use libedit instead of readline
if $G_PYTHON_COMPILE && [[ "$PY_VERSION_NUM" -ge 310 ]]; then
    T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//readline/libedit}"
fi

# Extra paths we'll add to the 'PATH' variable
T_EXTRA_PATH=""

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Searching for libraries ..."
sysout ""

# Iterating over all libraries we are interested in
for libraryName in $T_LIBRARIES_TO_LOOKUP; do
    # Getting their base directory
    libraryDir="$(brew --prefix "$libraryName" 2> /dev/null || true)"

    # Validating the library
    if [[ "$libraryDir" == "" ]] || [[ ! -d "$libraryDir" ]] || [[ ! -d "$libraryDir/lib" ]] || [[ ! -d "$libraryDir/include" ]]; then
        sysout >&2 "[ERROR] Could not find $libraryName, did you install it with brew install $libraryName ?"
        sysout >&2 ""
        exit 1
    fi

    # If the library has a bin folder, we add it to 'T_EXTRA_PATH'
    if [[ -d "$libraryDir/bin" ]]; then
        T_EXTRA_PATH="${T_EXTRA_PATH:+$T_EXTRA_PATH:}$libraryDir/bin"
    fi

    # Adding the library to the compiler flags
    export LDFLAGS="${LDFLAGS:+$LDFLAGS }-L$libraryDir/lib"
    export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-I$libraryDir/include"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$libraryDir/lib"

    # Adding the optional package config to 'PKG_CONFIG_PATH'
    if [[ -d "$libraryDir/lib/pkgconfig" ]]; then
        export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:+$PKG_CONFIG_PATH:}$libraryDir/lib/pkgconfig"
    fi

    # OpenSSL also has an include/openssl subdirectory, handling that
    if [[ "$libraryName" =~ ^openssl.*$ ]]; then
        if [[ ! -d "$libraryDir/include/openssl" ]]; then
            sysout >&2 "[ERROR] Could not find $libraryDir/include/openssl, did you install $libraryName correctly ?"
            sysout >&2 ""
            exit 1
        else
            export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-I$libraryDir/include/openssl"
        fi
    fi

    # For libedit we also need to include libedit/editline
    if [[ "$libraryName" == "libedit" ]]; then
        if [[ ! -d "$libraryDir/include/editline" ]]; then
            sysout >&2 "[ERROR] Could not find $libraryDir/include/editline, did you install $libraryName correctly ?"
            sysout >&2 ""
            exit 1
        else
            export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-I$libraryDir/include/editline"
        fi
    fi

    # Some of the library locations are also needed by install-python-macos.sh directly, so saving those
    case "$libraryName" in
        openssl*)
            export L_OPENSSL_BASE="$libraryDir"
            ;;
        readline | libedit)
            if [[ "${L_READLINE_BASE:-}" != "" ]]; then
                sysout >&2 "[ERROR] L_READLINE_BASE was already set"
                sysout >&2 ""
                exit 1
            fi
            export L_READLINE_BASE="$libraryDir"
            ;;
        tcl-tk)
            export L_TCL_TK_BASE="$libraryDir"
            ;;
        zlib)
            export L_ZLIB_BASE="$libraryDir"
            ;;
    esac
done

# Unsetting the loop variables
unset T_LIBRARIES_TO_LOOKUP libraryName libraryDir

if ! ${P_DRY_RUN_MODE:-false}; then
    # Printing the environment variables we've set
    sysout "${FNT_BLD}${FNT_ULN}Environment:${FNT_RST}"
    sysout ""
    sysout "    * ${FNT_BLD}EXTRA_PATH:${FNT_RST} $T_EXTRA_PATH"
    sysout ""
    sysout "    * ${FNT_BLD}LDFLAGS:${FNT_RST} $LDFLAGS"
    sysout ""
    sysout "    * ${FNT_BLD}CPPFLAGS:${FNT_RST} $CPPFLAGS"
    sysout ""
    sysout "    * ${FNT_BLD}LD_LIBRARY_PATH:${FNT_RST} $LD_LIBRARY_PATH"
    sysout ""
    sysout "    * ${FNT_BLD}PKG_CONFIG_PATH:${FNT_RST} $PKG_CONFIG_PATH"
    sysout ""
else
    {
        echo "export PATH=\"$G_PY_COMPILE_GNU_PROG_PATH:$T_EXTRA_PATH:\$PATH\""
        echo ""
        echo "export LDFLAGS=\"$LDFLAGS\""
        echo ""
        echo "export CPPFLAGS=\"$CPPFLAGS\""
        echo ""
        echo "export LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH\""
        echo ""
        echo "export PKG_CONFIG_PATH=\"$PKG_CONFIG_PATH\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Prepending 'PATH' with 'T_EXTRA_PATH' which we've assembled based on the libraries
export PATH="$T_EXTRA_PATH:$PATH"

# And finally, unsetting 'T_EXTRA_PATH' as we don't need it anymore
unset T_EXTRA_PATH

if ! ${P_NON_INTERACTIVE:-false}; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue" && sysout ""
fi
