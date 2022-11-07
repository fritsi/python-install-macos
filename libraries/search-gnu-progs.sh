#############################################################################
### This script will look-up GNU libraries installed via brew             ###
### Then it will all them to 'PATH'                                       ###
### These are useful, because the corresponding default binaries in macOS ###
### are too old in some cases, and they don't support many features       ###
#############################################################################

# Extra paths we'll add to 'PATH'
T_GNU_PROG_PATHS=""

# Iterating over some programs which should be present on the PATH
for program_name in wget jq grep gnu-which gnu-tar gnu-sed gawk findutils coreutils autoconf asciidoc pkg-config; do
    # Getting their base directory
    program_dir="$(brew --prefix "$program_name" 2> /dev/null)"

    # Validating the external program
    if [[ ! -d "$program_dir" ]] || { [[ ! -d "$program_dir/libexec/gnubin" ]] && [[ ! -d "$program_dir/bin" ]]; }; then
        sysout >&2 "[ERROR] Could not find $program_name, did you install it with brew install $program_name ?"
        sysout >&2 ""
        exit 1
    fi

    # Adding it to 'T_GNU_PROG_PATHS'
    if [[ -d "$program_dir/libexec/gnubin" ]]; then
        T_GNU_PROG_PATHS="$program_dir/libexec/gnubin${T_GNU_PROG_PATHS:+:$T_GNU_PROG_PATHS}"
    elif [[ -d "$program_dir/bin" ]]; then
        T_GNU_PROG_PATHS="$program_dir/bin${T_GNU_PROG_PATHS:+:$T_GNU_PROG_PATHS}"
    fi
done

# Unsetting the loop variables
unset program_name program_dir

# Printing our 'T_GNU_PROG_PATHS' variable
sysout "\033[1mGNU_PROG_PATHS:\033[0m $T_GNU_PROG_PATHS" && sysout ""

# Prepending 'PATH' with 'T_GNU_PROG_PATHS' which we've assembled based on the libraries
export PATH="$T_GNU_PROG_PATHS:$PATH"

# We don't need this anymore
unset T_GNU_PROG_PATHS
