###########################################################################################
### This utility script contains print to console related functions                     ###
### For example we determine whether our echo is a GNU echo or not                      ###
### The way we do that is we simply issue an `echo --help` as GNU echo supports that    ###
### The default macOS echo simply prints out "--help"                                   ###
### The reason we need this is because GNU echo support formatting (bold, italic, etc.) ###
###########################################################################################

# If the echo command does not seem to be a GNU echo, then we check whether we have
# coreutils installed with brew or not, and if we do have, then we prepend the 'PATH'
# with it
if [[ "$(enable -n echo && echo --help)" == "--help" ]]; then
    __coreUtilsPrefix=$(brew --prefix coreutils 2> /dev/null || true)
    if [[ "$__coreUtilsPrefix" != "" ]] && [[ -d "$__coreUtilsPrefix/libexec/gnubin" ]]; then
        export PATH="$__coreUtilsPrefix/libexec/gnubin:$PATH"
    fi
    unset __coreUtilsPrefix
fi

# Checking whether the echo command is still not a GNU echo, or now we have a GNU one
if [[ "$(enable -n echo && echo --help)" == "--help" ]]; then
    # The echo command does NOT support formatting, so declaring a sysout
    # which will remove the formatting and then print the text
    function sysout() {
        # shellcheck disable=SC2001
        echo "$1" | sed "s/\\\\033\[[0-9]m//g"
    }
else
    # The echo command does support formatting, so we can print out a formatted text
    function sysout() {
        echo -e "$1"
    }
fi

export -f sysout

# Instead of simply using 'read -r -p "message " {variable_name}',
# this method will use sysout to print the message so that you can have
# formatting in the message, and then use 'read -r -p', but with a simple space
# as the message
function ask() {
    # Printing the question test
    echo -n "$(sysout "$1")"

    if [[ "$#" -eq 2 ]]; then
        # We want to store the response in a variable
        read -r -p " " "$2"
    else
        # We don't need to store the response in a variable
        read -r -p " "
    fi
}

export -f ask
