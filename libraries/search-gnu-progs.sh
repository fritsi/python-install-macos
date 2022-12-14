#############################################################################
### This script will look-up GNU libraries installed via brew             ###
### Then it will all them to 'PATH'                                       ###
### These are useful, because the corresponding default binaries in macOS ###
### are too old in some cases, and they don't support many features       ###
#############################################################################

# Extra paths we'll add to 'PATH'
G_PY_COMPILE_GNU_PROG_PATH=""

# Iterating over some programs which should be present on the PATH
for programName in wget jq grep gnu-which gnu-tar gnu-sed gawk findutils coreutils autoconf asciidoc pkg-config; do
    # Getting their base directory
    programDir="$(brew --prefix "$programName" 2> /dev/null || true)"

    # Validating the external program
    if [[ "$programDir" == "" ]] || [[ ! -d "$programDir" ]] || { [[ ! -d "$programDir/libexec/gnubin" ]] && [[ ! -d "$programDir/bin" ]]; }; then
        sysout >&2 "[ERROR] Could not find $programName, did you install it with brew install $programName ?"
        sysout >&2 ""
        exit 1
    fi

    # Adding it to 'G_PY_COMPILE_GNU_PROG_PATH'
    if [[ -d "$programDir/libexec/gnubin" ]]; then
        G_PY_COMPILE_GNU_PROG_PATH="$programDir/libexec/gnubin${G_PY_COMPILE_GNU_PROG_PATH:+:$G_PY_COMPILE_GNU_PROG_PATH}"
    elif [[ -d "$programDir/bin" ]]; then
        G_PY_COMPILE_GNU_PROG_PATH="$programDir/bin${G_PY_COMPILE_GNU_PROG_PATH:+:$G_PY_COMPILE_GNU_PROG_PATH}"
    fi
done

# Unsetting the loop variables
unset programName programDir

# Printing our 'G_PY_COMPILE_GNU_PROG_PATH' variable
sysout "${FNT_BLD}GNU_PROG_PATHS:${FNT_RST} $G_PY_COMPILE_GNU_PROG_PATH" && sysout ""

# Prepending 'PATH' with 'G_PY_COMPILE_GNU_PROG_PATH' which we've assembled based on the libraries
export PATH="$G_PY_COMPILE_GNU_PROG_PATH:$PATH"

# No longer unsetting this as we need it in case of dry run mode
# unset G_PY_COMPILE_GNU_PROG_PATH
