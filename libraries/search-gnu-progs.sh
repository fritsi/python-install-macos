#############################################################################
### This script will look-up GNU libraries installed via Homebrew         ###
### Then it will all them to 'PATH'                                       ###
### These are useful, because the corresponding default binaries in macOS ###
### are too old in some cases, and they don't support many features       ###
#############################################################################

# Extra paths we'll add to 'PATH'
export G_PY_COMPILE_GNU_PROG_PATH=""

# Iterating over some programs which should be present on the PATH
for programName in pkg-config asciidoc autoconf coreutils findutils gawk gnu-sed gnu-tar gnu-which grep jq wget; do
    # Getting their base directory
    programDir="$(brew --prefix "$programName" 2> /dev/null || true)"

    # Validating the external program
    if [[ "$programDir" == "" ]] || [[ ! -d "$programDir" ]] || { [[ ! -d "$programDir/libexec/gnubin" ]] && [[ ! -d "$programDir/bin" ]]; }; then
        sysout >&2 "${FNT_BLD}[ERROR]${FNT_RST} Could not find $programName, did you install it with brew install $programName?"
        sysout >&2 ""
        exit 1
    fi

    # Adding it to 'G_PY_COMPILE_GNU_PROG_PATH'
    if [[ -d "$programDir/libexec/gnubin" ]]; then
        prependVar G_PY_COMPILE_GNU_PROG_PATH ':' "$programDir/libexec/gnubin"
    elif [[ -d "$programDir/bin" ]]; then
        prependVar G_PY_COMPILE_GNU_PROG_PATH ':' "$programDir/bin"
    fi
done

# Unsetting the loop variables
unset programName programDir

# Printing our 'G_PY_COMPILE_GNU_PROG_PATH' variable
sysout "${FNT_BLD}GNU_PROG_PATHS:${FNT_RST} $G_PY_COMPILE_GNU_PROG_PATH" && sysout ""

# Prepending 'PATH' with 'G_PY_COMPILE_GNU_PROG_PATH' which we've assembled based on the libraries
prependVar PATH ':' "$G_PY_COMPILE_GNU_PROG_PATH"

# No longer unsetting this as we need it in case of dry run mode
# unset G_PY_COMPILE_GNU_PROG_PATH
