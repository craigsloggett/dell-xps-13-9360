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
    shift $(( $OPTIND - 1 ))

    # Target must be present and valid.
    [ -z "${target:-}" ] && { printf 'Target must be present.\n'; return 1; }
    [ -d "${target:-}" ] || { printf 'Target must be a valid directory.\n'; return 1; }

    # Specify the username if present, otherwise use the defaults (root).
    [ -n "${username:-}" ] && chroot_args=(--userspec $username)

    # Set the environment variables.
    env=( HOME="${username:+/home}/${username:-root}" \
          TERM="$TERM" \
          SHELL=/bin/sh \
          USER="${username:-root}" \
          CFLAGS="${CFLAGS:--march=x86-64 -mtune=generic -pipe -Os}" \
          CXXFLAGS="${CXXFLAGS:--march=x86-64 -mtune=generic -pipe -Os}" \
          MAKEFLAGS="${MAKEFLAGS:--j$(nproc 2>/dev/null || printf '1')}"
        )

    # Send a command based on what was supplied as input parameters.
    [ -n "${*:-}" ] && cmd=(-c "$*")

    # A simple chroot wrapper to execute commands in the new environment.	
    chroot "${chroot_args[@]}" -- "$target" \
        /usr/bin/env -i "${env[@]}" \
        /bin/sh -l "${cmd[@]}"
}

chroot_helper "$@"
