##################################################################################
### This script will find all the necessary libraries required to build Python ###
##################################################################################

# Initializing the compiler "flags" as empty strings
export LDFLAGS=""
export CFLAGS=""
export CPPFLAGS=""
export CPATH=""
export LIBRARY_PATH=""
export PKG_CONFIG_PATH=""

# The list of libraries we need to look-up, and set include / lib directories based on them for the compiler
# Some of them are definitely mandatory, others are optional for the Python build
export T_LIBRARIES_TO_LOOKUP="zlib xz tcl-tk-fritsi sqlite-fritsi readline-fritsi openssl@3.0 ncurses-fritsi mpdecimal libzip-fritsi libxcrypt libffi gdbm expat bzip2 gettext-fritsi"

# Adding OpenSSL to the libraries to look-up when we are compiling Python
if $G_PYTHON_COMPILE; then
    if [[ "$PY_VERSION_NUM" -ge 308 ]]; then
        # We replace some of the libraries compiled with OpenSSL with their OpenSSL 3 compilation counterparts
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//libzip-fritsi/libzip-fritsi-with-openssl3}"
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//sqlite-fritsi/sqlite-fritsi-with-openssl3}"
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//tcl-tk-fritsi/tcl-tk-fritsi-with-openssl3}"
    else
        # For older Python versions we still need OpenSSL 1.1 :(
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//openssl@3.0/openssl@1.1}"

        # Also, for Python versions smaller than 3.8, we need to use an older libffi library :(
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//libffi/libffi33}"
    fi

    # User wants to use X11, let's use that version of SQLite and Tcl-Tk
    if $P_USE_X11; then
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//sqlite-fritsi/sqlite-fritsi-with-x11}"
        export T_LIBRARIES_TO_LOOKUP="${T_LIBRARIES_TO_LOOKUP//tcl-tk-fritsi/tcl-tk-fritsi-with-x11}"

        # Let's also add libx11 and xorgproto as dependent libraries
        export T_LIBRARIES_TO_LOOKUP="$T_LIBRARIES_TO_LOOKUP libx11 xorgproto"
    fi
fi

# Extra paths we'll add to the 'PATH' variable
export T_EXTRA_PATH=""

sysout "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Searching for libraries ..."
sysout ""

function prependIncludeDir() {
    if [[ ! -d "$2" ]]; then
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Could not find $2, did you install $1 correctly?"
        sysout >&2 ""
        return 1
    else
        prependVar CFLAGS ' ' "-I$2"
        prependVar CPPFLAGS ' ' "-I$2"
        prependVar CPATH ':' "$2"
    fi
}

# Iterating over all libraries we are interested in
for libraryName in $T_LIBRARIES_TO_LOOKUP; do
    # Getting their base directory
    libraryDir="$(brew --prefix "$libraryName" 2> /dev/null || true)"

    # Validating the library
    if [[ "$libraryDir" == "" ]] || [[ ! -d "$libraryDir" ]] || { [[ "$libraryName" != "xorgproto" ]] && [[ ! -d "$libraryDir/lib" ]]; } || [[ ! -d "$libraryDir/include" ]]; then
        if [[ "$libraryName" == *fritsi* ]]; then
            sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Could not find $libraryName, did you install it with ${FNT_ITC}brew install --formula --build-from-source \"$SCRIPTS_DIR/formulas/$libraryName.rb\"${FNT_RST} ?"
        else
            sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Could not find $libraryName, did you install it with ${FNT_ITC}brew install $libraryName${FNT_RST} ?"
        fi

        sysout >&2 ""
        exit 1
    fi

    # If the library has a bin folder, we add it to 'T_EXTRA_PATH'
    if [[ -d "$libraryDir/bin" ]]; then
        prependVar T_EXTRA_PATH ':' "$libraryDir/bin"
    fi

    # Adding the library to the compiler flags
    if [[ -d "$libraryDir/lib" ]]; then
        prependVar LDFLAGS ' ' "-Wl,-rpath,$libraryDir/lib" "-L$libraryDir/lib"
        prependVar LIBRARY_PATH ':' "$libraryDir/lib"
    fi

    # OpenSSL also has an include/openssl sub-directory, handling that
    # NOTE: This needs to be before the regular include directories
    if [[ "$libraryName" =~ ^openssl.*$ ]]; then
        prependIncludeDir "$libraryName" "$libraryDir/include/openssl"
    fi

    # Adding the include directory itself to the compiler flags
    prependIncludeDir "$libraryName" "$libraryDir/include"

    # ncurses also has an include/ncursesw sub-directory, handling that
    # NOTE: This needs to be after the regular include directories
    if [[ "$libraryName" == "ncurses-fritsi" ]]; then
        prependIncludeDir "$libraryName" "$libraryDir/include/ncursesw"
    fi

    # Adding the optional package config to 'PKG_CONFIG_PATH'
    if [[ -d "$libraryDir/lib/pkgconfig" ]]; then
        prependVar PKG_CONFIG_PATH ':' "$libraryDir/lib/pkgconfig"
    fi

    # Some of the library locations are also needed by install-python-macos.sh directly, so saving those
    case "$libraryName" in
        openssl*)
            export L_OPENSSL_BASE="$libraryDir"
            ;;
        tcl-tk*)
            export L_TCL_TK_BASE="$libraryDir"
            ;;
    esac
done

# We no longer need this function, and we don't want to expose it
unset prependIncludeDir

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
    sysout "    * ${FNT_BLD}LIBRARY_PATH:${FNT_RST} $LIBRARY_PATH"
    sysout ""
    sysout "    * ${FNT_BLD}CFLAGS:${FNT_RST} $CFLAGS"
    sysout ""
    sysout "    * ${FNT_BLD}CPPFLAGS:${FNT_RST} $CPPFLAGS"
    sysout ""
    sysout "    * ${FNT_BLD}CPATH:${FNT_RST} $CPATH"
    sysout ""
    sysout "    * ${FNT_BLD}PKG_CONFIG_PATH:${FNT_RST} $PKG_CONFIG_PATH"
    sysout ""
else
    {
        echo "export PATH=\"$G_PY_COMPILE_GNU_PROG_PATH:$T_EXTRA_PATH:\$PATH\""
        echo ""
        echo "export LDFLAGS=\"$LDFLAGS\""
        echo ""
        echo "export LIBRARY_PATH=\"$LIBRARY_PATH\""
        echo ""
        echo "export CFLAGS=\"$CFLAGS\""
        echo ""
        echo "export CPPFLAGS=\"$CPPFLAGS\""
        echo ""
        echo "export CPATH=\"$CPATH\""
        echo ""
        echo "export PKG_CONFIG_PATH=\"$PKG_CONFIG_PATH\""
        echo ""
    } >> "$G_PY_COMPILE_COMMANDS_FILE"
fi

# Prepending 'PATH' with 'T_EXTRA_PATH' which we've assembled based on the libraries
prependVar PATH ':' "$T_EXTRA_PATH"

# And finally, unsetting 'T_EXTRA_PATH' as we don't need it anymore
unset T_EXTRA_PATH

if ! ${P_NON_INTERACTIVE:-false}; then
    ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to continue"
fi
