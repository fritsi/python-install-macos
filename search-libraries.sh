# This function will search for a library, and validate that it's properly installed
function searchLibrary() {
    local lib_base
    local is_openssl_10

    # This will be set to 1 when we are searching for OpenSSL for Python 3.4,
    # because in that case we'll need to override it to openssl-1.0.2u
    is_openssl_10=0

    # shellcheck disable=SC2154
    if [[ "$G_PYTHON_COMPILE" -eq 1 ]]; then
        # Handling OpenSSL for Python 3.4 as a special case
        if [[ "$1" == "openssl@1.1" ]] && [[ "$PY_POSTFIX" == "3.4" ]]; then
            lib_base="$HOME/Library/openssl-1.0.2u"

            # Setting the flag that we've overridden OpenSSL 1.1 to 1.0
            is_openssl_10=1
        else
            lib_base="$(brew --prefix "$1")"
        fi
    else
        lib_base="$(brew --prefix "$1")"
    fi

    if [[ ! -d "$lib_base" ]] || [[ ! -d "$lib_base/lib" ]] || [[ ! -d "$lib_base/include" ]]; then
        if [[ "$is_openssl_10" -eq 1 ]]; then
            echo >&2 "[ERROR] Could not find $lib_base or $lib_base/lib or $lib_base/include"
            echo >&2 ""
        else
            echo >&2 "[ERROR] Could not find $1, did you install it with brew install $1 ?"
            echo >&2 ""
        fi
        return 1
    fi

    shift

    # Validating the extra expected directories
    if [[ "$#" -gt 0 ]]; then
        local extra_expected_dir

        for extra_expected_dir in "$@"; do
            if [[ ! -d "$lib_base/$extra_expected_dir" ]]; then
                echo >&2 "[ERROR] Could not find $lib_base/$extra_expected_dir"
                echo >&2 ""
                return 1
            fi
        done
    fi

    # "Returning" the base directory for the library
    echo -n "$lib_base"
}

# For Python compilation we need OpenSSL as well
if [[ "$G_PYTHON_COMPILE" -eq 1 ]]; then
    L_OPENSSL_BASE=$(searchLibrary "openssl@1.1" "include/openssl" "bin" "lib/pkgconfig")
fi

# Searching for the rest of the libraries
L_BZIP2_BASE="$(searchLibrary "bzip2" "bin")"
L_GDBM_BASE="$(searchLibrary "gdbm" "bin")"
L_NCURSES_BASE="$(searchLibrary "ncurses" "bin" "lib/pkgconfig")"
L_READLINE_BASE="$(searchLibrary "readline" "lib/pkgconfig")"
L_SQLITE_BASE="$(searchLibrary "sqlite" "bin" "lib/pkgconfig")"
L_TCL_TK_BASE="$(searchLibrary "tcl-tk" "bin" "lib/pkgconfig")"
L_XZ_BASE="$(searchLibrary "xz" "bin" "lib/pkgconfig")"
L_ZLIB_BASE="$(searchLibrary "zlib" "lib/pkgconfig")"

# Adding the libraries (which have executables) to the PATH as well
export PATH="$L_BZIP2_BASE/bin:$L_GDBM_BASE/bin:$L_NCURSES_BASE/bin:$L_SQLITE_BASE/bin:$L_TCL_TK_BASE/bin:$L_XZ_BASE/bin:$PATH"

# Adding OpenSSL to the PATH as well
if [[ "$G_PYTHON_COMPILE" -eq 1 ]]; then
    export PATH="$L_OPENSSL_BASE/bin:$PATH"
fi

# Printing the libraries' locations
echo -e "\033[1m\033[4mLibraries:\033[0m"
echo ""
echo -e "    * \033[1mbzip2:\033[0m $L_BZIP2_BASE"
echo -e "    * \033[1mgdbm:\033[0m $L_GDBM_BASE"
echo -e "    * \033[1mncurses:\033[0m $L_NCURSES_BASE"
if [[ "$G_PYTHON_COMPILE" -eq 1 ]]; then
    echo -e "    * \033[1mopenssl:\033[0m $L_OPENSSL_BASE"
fi
echo -e "    * \033[1mreadline:\033[0m $L_READLINE_BASE"
echo -e "    * \033[1msqlite:\033[0m $L_SQLITE_BASE"
echo -e "    * \033[1mtcl-tk:\033[0m $L_TCL_TK_BASE"
echo -e "    * \033[1mxz:\033[0m $L_XZ_BASE"
echo -e "    * \033[1mzlib:\033[0m $L_ZLIB_BASE"
echo ""

# Exporting compiler arguments
export LDFLAGS="-L$L_BZIP2_BASE/lib -L$L_GDBM_BASE/lib -L$L_NCURSES_BASE/lib -L$L_READLINE_BASE/lib -L$L_SQLITE_BASE/lib -L$L_TCL_TK_BASE/lib -L$L_XZ_BASE/lib -L$L_ZLIB_BASE/lib"
export CPPFLAGS="-I$L_BZIP2_BASE/include -I$L_GDBM_BASE/include -I$L_NCURSES_BASE/include -I$L_READLINE_BASE/include -I$L_SQLITE_BASE/include -I$L_TCL_TK_BASE/include -I$L_XZ_BASE/include -I$L_ZLIB_BASE/include"
export LD_LIBRARY_PATH="$L_BZIP2_BASE/lib:$L_GDBM_BASE/lib:$L_NCURSES_BASE/lib:$L_READLINE_BASE/lib:$L_SQLITE_BASE/lib:$L_TCL_TK_BASE/lib:$L_XZ_BASE/lib:$L_ZLIB_BASE/lib"
export PKG_CONFIG_PATH="$L_NCURSES_BASE/lib/pkgconfig:$L_READLINE_BASE/lib/pkgconfig:$L_SQLITE_BASE/lib/pkgconfig:$L_TCL_TK_BASE/lib/pkgconfig:$L_XZ_BASE/lib/pkgconfig:$L_ZLIB_BASE/lib/pkgconfig"

if [[ "$G_PYTHON_COMPILE" -eq 1 ]]; then
    # Adding OpenSSL libs and includes in case we are compiling Python
    export LDFLAGS="-L$L_OPENSSL_BASE/lib $LDFLAGS"
    export CPPFLAGS="-I$L_OPENSSL_BASE/include -I$L_OPENSSL_BASE/include/openssl $CPPFLAGS"
    export LD_LIBRARY_PATH="$L_OPENSSL_BASE/lib:$LD_LIBRARY_PATH"
    export PKG_CONFIG_PATH="$L_OPENSSL_BASE/lib/pkgconfig:$PKG_CONFIG_PATH"
fi

echo -e "\033[1m\033[4mEnvironment:\033[0m"
echo ""
echo -e "    * \033[1mLDFLAGS:\033[0m $LDFLAGS"
echo ""
echo -e "    * \033[1mCPPFLAGS:\033[0m $CPPFLAGS"
echo ""
echo -e "    * \033[1mLD_LIBRARY_PATH:\033[0m $LD_LIBRARY_PATH"
echo ""
echo -e "    * \033[1mPKG_CONFIG_PATH:\033[0m $PKG_CONFIG_PATH"
echo ""

if [[ "${P_NON_INTERACTIVE:-0}" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi
