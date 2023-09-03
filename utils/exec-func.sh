function __internalShowCommandToBeExecuted() {
    local param
    local index
    index=0

    if ! ${P_DRY_RUN_MODE:-false}; then
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

export -f __internalShowCommandToBeExecuted

# Prints a command line and then executes it
function echoAndExec() {
    if ! ${P_DRY_RUN_MODE:-false}; then
        __internalShowCommandToBeExecuted "$@"

        sysout ""
        sysout ""

        if ! ${P_NON_INTERACTIVE:-false}; then
            ask "${FNT_BLD}[$G_PROG_NAME]${FNT_RST} Press [ENTER] to execute the above command"
        fi

        "$@"
    else
        {
            __internalShowCommandToBeExecuted "$@"
            echo ""
        } >> "$G_PY_COMPILE_COMMANDS_FILE"
    fi
}

export -f echoAndExec
