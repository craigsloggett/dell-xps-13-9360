#!/bin/sh
#
# Create a swapfile for a given root.

create_swapfile() {
    # Check the blocksize of the given root filesystem.
    block_size="$(stat -fc %s $1)"

    mkdir -p "$1/var"

    dd if=/dev/zero of="$1/var/swapfile" bs=$block_size count=$(( block_size * 1024 ))

    chmod 600 "$1/var/swapfile"
    mkswap "$1/var/swapfile"
}
