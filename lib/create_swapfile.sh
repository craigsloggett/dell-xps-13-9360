#!/bin/sh
#
# Create a swapfile for a given root.

create_swapfile() {
    # Check the blocksize of the given root filesystem.
    block_size="$(stat -fc %s $1)"

    # Create a swapfile with a size equal to double the amount of memory of the system.
    mem_total_kb="$( grep MemTotal /proc/meminfo | awk '{print $2}' )"
    block_count="$(( mem_total_kb * 1024 / block_size * 2 ))"

    mkdir -p "$1/var"

    dd if=/dev/zero of="$1/var/swapfile" bs="$block_size" count="$block_count"

    chmod 600 "$1/var/swapfile"
    mkswap "$1/var/swapfile"
}
