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

    local variableName
    local separator
    local valuesToPrepend
    local valueToPrepend
    local currentValue
    local newValue

    variableName="$1"
    separator="$2"

    # Skipping the first 2 parameters
    shift 2

    # Adding the values to prepend to an array
    valuesToPrepend=("$@")

    # Getting the current value of the variable
    # Initializing this as an empty string if the variable was not set
    currentValue="${!variableName:-}"

    # newValue should be the same as currentValue at the beginning
    newValue="$currentValue"

    # Iterating over each value we need to prepend
    for valueToPrepend in "${valuesToPrepend[@]}"; do
        # The variable already contains this value
        if [[ "$separator$newValue$separator" == *"$separator$valueToPrepend$separator"* ]]; then
            continue
        fi

        # Prepending the value, but keeping in mind that if the value was
        # empty or not set, then we don't add a separator
        newValue="$valueToPrepend${newValue:+$separator$newValue}"
    done

    # Exporting the variable with its new value if it has been changed
    if [[ "$newValue" != "$currentValue" ]]; then
        declare -xg "$variableName"="$newValue"
    fi
}

export -f prependVar
