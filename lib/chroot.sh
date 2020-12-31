#!/bin/sh
#
# A simple chroot helper script.

chroot_helper() {
    # getopts /optstring/ /name/ [/arg/...]
    while getopts :t:u: name; do
        case $name in
            t  )  target="$OPTARG" ;; 
            u  )  username="$OPTARG" ;;
            :  )  printf '%s: Argument is missing.\n' "$OPTARG" ;;
            \? )  printf '%s: Invalid option.\n' "$OPTARG" ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    # Target must be present and valid.
    [ -z "${target:-}" ] && { printf 'Target must be present.\n'; return 1; }
    [ -d "${target:-}" ] || { printf 'Target must be a valid directory.\n'; return 1; }

    # Send a command if present, otherwise use the defaults (interactive).
    [ -n "${*:-}" ] && set -- -c "$*"
    set -- /bin/sh -l "$@"

    set -- HOME="${username:+/home}/${username:-root}" "$@"
    set -- TERM="$TERM" "$@"
    set -- SHELL=/bin/sh "$@"
    set -- USER="${username:-root}" "$@"
    set -- CFLAGS="${CFLAGS:--march=native -mtune=generic -pipe -Os}" "$@"
    set -- CXXFLAGS="${CXXFLAGS:--march=native -mtune=generic -pipe -Os}" "$@"
    set -- MAKEFLAGS="${MAKEFLAGS:--j$(nproc 2>/dev/null || printf '1')}" "$@"
    set -- /usr/bin/env -i "$@"

    set -- "$target" "$@"

    # Specify the username if present, otherwise use the defaults (root).
    [ -n "${username:-}" ] && set -- --userspec "$username" -- "$@"

    chroot "$@"
}
