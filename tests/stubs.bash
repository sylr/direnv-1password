# `op-cached` is only visible to the script when a test opts in, so the rest of
# the suite keeps exercising the `op inject` path.
STUB_VALUE=""

has() {
    case $1 in
        op) return 0 ;;
        op-cached) [[ -n ${STUB_OP_CACHED:-} ]] ;;
        *) return 1 ;;
    esac
}

watch_file() {
    printf '%s\n' "$1" >>"${WATCH_FILE_LOG:?}"
}

log_error() {
    printf 'ERROR: %s\n' "$*" >&2
}

log_status() {
    printf 'STATUS: %s\n' "$*" >&2
}

direnv() {
    printf 'unexpected direnv invocation: %s\n' "$*" >&2
    return 1
}

dotenv_if_exists() {
    :
}

# Mimics `op inject`: replaces secret references, passes all other text
# through verbatim.
op() {
    if [[ $1 != inject ]]; then
        printf 'unexpected op invocation: %s\n' "$*" >&2
        return 1
    fi

    shift
    printf '%s\n' "$*" >>"${OP_ARGS_LOG:?}"

    local line reference value
    while IFS= read -r line; do
        while [[ $line =~ op://[^[:space:]]+ ]]; do
            reference=${BASH_REMATCH[0]}
            stub_secret_value "$reference" || return 1
            value=$STUB_VALUE
            line=${line/"$reference"/$value}
        done
        printf '%s\n' "$line"
    done
}

# The secret values both stubs resolve, returned in STUB_VALUE rather than on
# stdout: command substitution strips trailing newlines, and several of these
# values carry one deliberately.
stub_secret_value() {
    local value
    case $1 in
        op://vault/item/field) value=single-secret ;;
        op://vault/first/field) value=first-secret ;;
        op://vault/other/field) value=other-secret ;;
        op://vault/file/field) value=file-secret ;;
        op://vault/dollar/field) value=pa\$\$word\$with\$dollars ;;
        op://vault/quotes/field) value=$'it\'s "quoted" \\back\\slash `cmd`' ;;
        op://vault/empty/field) value= ;;
        op://vault/spaces/field) value=$' \tpadded secret \t' ;;
        op://vault/percent/field) value=$'100%\r\n' ;;
        op://vault/multiline/field) value=$'-----BEGIN KEY-----\nline1\n\nOTHER_SECRET=not-a-var\n-----END KEY-----\n' ;;
        op://vault/missing/field) return 1 ;;
        *) value="value-for-${1}" ;;
    esac
    STUB_VALUE=$value
}

# Mimics `op-cached read`: one reference at a time, and like `op read` it
# appends a newline to whatever the field holds.
op-cached() {
    if [[ $1 != read ]]; then
        printf 'unexpected op-cached invocation: %s\n' "$*" >&2
        return 1
    fi

    shift
    printf '%s\n' "${OP_ACCOUNT:-<no-account>} $*" >>"${OP_CACHED_ARGS_LOG:?}"

    stub_secret_value "$1" || return 1
    printf '%s\n' "$STUB_VALUE"
}
