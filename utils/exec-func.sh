# Prints a command line and then executes it
function echoAndExec() {
    local param
    local index
    index=0

    echo -n ">> "

    # First item (assuming it's the executable) will be printed without quotes
    # The rest of the parameters with quotes
    for param in "$@"; do
        if [[ "$index" -eq 0 ]]; then
            echo -n "$param"
        else
            echo -n " \"$param\""
        fi
        index=$((index + 1))
    done

    sysout ""
    sysout ""

    if [[ "${P_NON_INTERACTIVE:-}" -ne 1 ]]; then
        ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to execute the above command" && sysout ""
    fi

    "$@"
}

export -f echoAndExec
