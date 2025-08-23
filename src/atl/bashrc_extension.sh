# AtlantisOS - atl shell integration
# intercept every command and pass it through atl

# function that passes every command to atl
atl_preexec() {
    # the complete command entered
    local CMDLINE="$BASH_COMMAND"
    local CMD="${CMDLINE%% *}"
    local ARGS="${CMDLINE#* }"

    # check if atl is running
    if [[ "$CMD" == "atl" || "$CMD" == "atl-internal" ]]; then
        return 0
    fi

    # transfer of command to atl
    /usr/bin/atl "$CMD" $ARGS

    # prevent Bash from executing the command again itself
    false
}

# DEBUG trap: start atl_preexec before each command
trap 'atl_preexec' DEBUG

