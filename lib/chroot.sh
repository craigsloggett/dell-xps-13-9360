#!/bin/sh
#
# A simple chroot helper script.

# NAME
#   chroot_helper - run a command or interactive shell with special root directory
#
# SYNOPSIS
#   chroot [OPTION] NEWROOT [COMMAND [ARG]...]
#
# This helper wraps the GNU chroot command and adds environment variables for
# convenience.

chroot_helper() {
    # getopts /optstring/ /name/ [/arg/...]
    while getopts :u: name; do
        case $name in
            u  )  username="$OPTARG" ;;
            :  )  printf '%s: Argument is missing.\n' "$OPTARG" ;;
            \? )  printf '%s: Invalid option.\n' "$OPTARG" ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    newroot="$1"
    [ -z "$1" ] || shift 1

    # Send a command if present, otherwise use the defaults (interactive).
    [ -n "${*:-}" ] && set -- -c "$*"
    set -- /bin/sh -i -l "$@"

    set -- HOME="${username:+/home}/${username:-root}" "$@"
    set -- TERM="$TERM" "$@"
    set -- SHELL=/bin/sh "$@"
    set -- USER="${username:-root}" "$@"
    set -- CFLAGS="${CFLAGS:--march=native -mtune=generic -pipe -Os}" "$@"
    set -- CXXFLAGS="${CXXFLAGS:--march=native -mtune=generic -pipe -Os}" "$@"
    set -- MAKEFLAGS="${MAKEFLAGS:--j$(nproc 2>/dev/null || printf '1')}" "$@"
    set -- /usr/bin/env -i "$@"

    set -- "$newroot" "$@"

    # Specify the username if present, otherwise use the defaults (root).
    [ -n "${username:-}" ] && set -- --userspec "$username" -- "$@"

    # chroot [OPTION] newroot [COMMAND [ARG]...]
    chroot "$@"
}
