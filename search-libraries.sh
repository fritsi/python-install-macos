# This function will search for a library, and validate that it's properly installed
function searchLibrary() {
    local _lib_base
    local _is_openssl_10

    # This will be set to 1 when we are searching for OpenSSL for Python 3.4,
    # because in that case we'll need to override it to openssl-1.0.2u
    _is_openssl_10=0

    # shellcheck disable=SC2154
    if [[ "$_python_compile" -eq 1 ]]; then
        # Handling OpenSSL for Python 3.4 as a special case
        if [[ "$1" == "openssl@1.1" ]] && [[ "$PY_POSTFIX" == "3.4" ]]; then
            _lib_base="$HOME/Library/openssl-1.0.2u"

            # Setting the flag that we've overridden OpenSSL 1.1 to 1.0
            _is_openssl_10=1
        else
            _lib_base="$(brew --prefix "$1")"
        fi
    else
        _lib_base="$(brew --prefix "$1")"
    fi

    if [[ ! -d "$_lib_base" ]] || [[ ! -d "$_lib_base/lib" ]] || [[ ! -d "$_lib_base/include" ]]; then
        if [[ "$_is_openssl_10" -eq 1 ]]; then
            echo >&2 "[ERROR] Could not find $_lib_base or $_lib_base/lib or $_lib_base/include"
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
            if [[ ! -d "$_lib_base/$extra_expected_dir" ]]; then
                echo >&2 "[ERROR] Could not find $_lib_base/$extra_expected_dir"
                echo >&2 ""
                return 1
            fi
        done
    fi

    # "Returning" the base directory for the library
    echo -n "$_lib_base"
}

# For Python compilation we need OpenSSL as well
if [[ "$_python_compile" -eq 1 ]]; then
    _openssl_base=$(searchLibrary "openssl@1.1" "include/openssl" "bin")
fi

# Searching for the rest of the libraries
_bzip2_base="$(searchLibrary "bzip2" "bin")"
_gdbm_base="$(searchLibrary "gdbm" "bin")"
_ncurses_base="$(searchLibrary "ncurses" "bin")"
_readline_base="$(searchLibrary "readline")"
_sqlite_base="$(searchLibrary "sqlite" "bin")"
_tcl_tk_base="$(searchLibrary "tcl-tk" "bin")"
_xz_base="$(searchLibrary "xz" "bin")"
_zlib_base="$(searchLibrary "zlib")"

# Adding the libraries (which have executables) to the PATH as well
export PATH="$_bzip2_base/bin:$_gdbm_base/bin:$_ncurses_base/bin:$_sqlite_base/bin:$_tcl_tk_base/bin:$_xz_base/bin:$PATH"

# Adding OpenSSL to the PATH as well
if [[ "$_python_compile" -eq 1 ]]; then
    export PATH="$_openssl_base/bin:$PATH"
fi

# Printing the libraries' locations
echo "Libraries:"
echo "    * bzip2: $_bzip2_base"
echo "    * gdbm: $_gdbm_base"
echo "    * ncurses: $_ncurses_base"
if [[ "$_python_compile" -eq 1 ]]; then
    echo "    * openssl: $_openssl_base"
fi
echo "    * readline: $_readline_base"
echo "    * sqlite: $_sqlite_base"
echo "    * tcl-tk: $_tcl_tk_base"
echo "    * xz: $_xz_base"
echo "    * zlib: $_zlib_base"
echo ""

# Exporting compiler arguments
export LDFLAGS="-L$_bzip2_base/lib -L$_gdbm_base/lib -L$_ncurses_base/lib -L$_readline_base/lib -L$_sqlite_base/lib -L$_tcl_tk_base/lib -L$_xz_base/lib -L$_zlib_base/lib"
export CPPFLAGS="-I$_bzip2_base/include -I$_gdbm_base/include -I$_ncurses_base/include -I$_readline_base/include -I$_sqlite_base/include -I$_tcl_tk_base/include -I$_xz_base/include -I$_zlib_base/include"

if [[ "$_python_compile" -eq 1 ]]; then
    # Adding OpenSSL lib and includes
    export LDFLAGS="-L$_openssl_base/lib $LDFLAGS"
    export CPPFLAGS="-I$_openssl_base/include -I$_openssl_base/include/openssl $CPPFLAGS"

    # For Python compilation we need to set the LD_LIBRARY_PATH as well
    export LD_LIBRARY_PATH="$_openssl_base/lib:${LD_LIBRARY_PATH:-}"
else
    # For OpenSSL compilation we don't need it
    unset LD_LIBRARY_PATH
fi

echo "Environment:"
echo "    * LDFLAGS: $LDFLAGS"
echo "    * CPPFLAGS: $CPPFLAGS"
if [[ "$_python_compile" -eq 1 ]]; then
    echo "    * LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
fi
echo ""

if [[ "${_non_interactive:-0}" -ne 1 ]]; then
    read -r -p "Press [ENTER] to continue " && echo ""
fi
