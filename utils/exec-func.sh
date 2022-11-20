function __internal_echoAndExec_echo() {
    local param
    local index
    index=0

    if [[ -z "${G_PY_COMPILE_COMMANDS_FILE:-}" ]]; then
        echo -n ">> "
    fi

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
}

export -f __internal_echoAndExec_echo

# Prints a command line and then executes it
function echoAndExec() {
    if [[ -z "${G_PY_COMPILE_COMMANDS_FILE:-}" ]]; then
        __internal_echoAndExec_echo "$@"

        sysout ""
        sysout ""

        if [[ "${P_NON_INTERACTIVE:-}" -ne 1 ]]; then
            ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to execute the above command" && sysout ""
        fi

        "$@"
    else
        {
            __internal_echoAndExec_echo "$@"
            echo ""
        } >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
}

export -f echoAndExec
