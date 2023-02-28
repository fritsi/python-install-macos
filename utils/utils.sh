# Prepends the given value to the given variable using the given separator
# NOTE: The variable will be exported at the end
# You can specify multiple values to prepend in which case the last value you specify
# will be at the beginning of your variable
# Example:
# fooBar='Value1:Value2'
# prependVar fooBar ':' NewValue1 NewValue2
# After this the value of fooBar will be: "NewValue2:NewValue1:Value1:Value2"
function prependVar() {
    # Making sure we are using the function in the correct way
    if [[ "$#" -lt 3 ]]; then
        echo >&2 -e "\n[FATAL ERROR] Usage: prependVar {variableName} {separator} {valueToPrepend} [valueToPrepend] ...\n"
        return 1
    fi

    local variable_name
    local separator
    local values_to_prepend
    local value_to_prepend
    local current_value
    local new_value

    variable_name="$1"
    separator="$2"

    # Skipping the first 2 parameters
    shift 2

    # Adding the values to prepend to an array
    values_to_prepend=("$@")

    # Getting the current value of the variable
    # Initializing this as an empty string if the variable was not set
    current_value="${!variable_name:-}"

    # new_value should be the same as current_value at the beginning
    new_value="$current_value"

    # Iterating over each value we need to prepend
    for value_to_prepend in "${values_to_prepend[@]}"; do
        # The variable already contains this value
        if [[ "$separator$new_value$separator" == *"$separator$value_to_prepend$separator"* ]]; then
            continue
        fi

        # Prepending the value, but keeping in mind that if the value was
        # empty or not set, then we don't add a separator
        new_value="$value_to_prepend${new_value:+$separator$new_value}"
    done

    # Exporting the variable with its new value if it has been changed
    if [[ "$new_value" != "$current_value" ]]; then
        declare -xg "$variable_name"="$new_value"
    fi
}

export -f prependVar
