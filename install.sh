#!/bin/sh
#
# This is a simple install script written in POSIX shell
# to be used to install KISS Linux (https://k1ss.org).

# Configuration Parameters

NEW_ROOT=/mnt
EFI_PARTITION=/dev/nvme0n1p1
ROOT_PARTITION=/dev/nvme0n1p2

# Useful Functions

nchroot() {
    while getopts :u: name; do
        case $name in
            u  )  username="$OPTARG" ;;
            :  )  printf '%s: Argument is missing.\n' "$OPTARG" ;;
            \? )  printf '%s: Invalid option.\n' "$OPTARG" ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    [ -d "$1" ] && new_root="$1" || new_root="NEW_ROOT"
    [ -n "$1" ] && shift 1

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

    set -- "$new_root" "$@"

    # Specify the username if present, otherwise use the defaults (root).
    [ -n "${username:-}" ] && set -- --userspec "$username" -- "$@"

    chroot "$@"
}

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

create_cmdline () {
    line=$(blkid $1)
    id=${line#*PARTUUID=\"}
    id=${id%%\"*}

    printf '%s\n' "root=PARTUUID=$id" > ${root_mount_point:-}/boot/cmdline.txt
}

setup_repo_directory() {
	# Source Directories
	chroot_helper -u nerditup /mnt mkdir -p "$1/.local/src/github.com/kisslinux"
	chroot_helper -u nerditup /mnt mkdir -p "$1/.local/src/github.com/nerditup"

	# Repo Directory
    chroot_helper -u nerditup /mnt mkdir -p "$1/.local/repos/kisslinux"

	# Clone the source repositories.
	chroot_helper -u nerditup /mnt cd "$1/.local/src/github.com/kisslinux" && git clone https://github.com/kisslinux/repo.git
	chroot_helper -u nerditup /mnt cd "$1/.local/src/github.com/nerditup" && git clone https://github.com/nerditup/kisslinux.git

	chroot_helper -u nerditup /mnt ln -s "~/.local/src/github.com/nerditup/kisslinux/" "~/.local/repos/kisslinux/personal"
	chroot_helper -u nerditup /mnt ln -s "~/.local/src/github.com/kisslinux/repo/core/" "~/.local/repos/kisslinux/core"
	chroot_helper -u nerditup /mnt ln -s "~/.local/src/github.com/kisslinux/repo/extra/" "~/.local/repos/kisslinux/extra"
}

main() {
    # Globally disable globbing and enable exit-on-error.
    set -ef

    cd $HOME

    # prepare the disk
    # mount the disk
    create_swapfile $root_mount_point
    create_cmdline $root_partition

    # Download the kiss-chroot.
    url=https://github.com/kisslinux/repo/releases/download/2020.9-2
    curl -L -O "$url/kiss-chroot-2020.9-2.tar.xz"

    ( cd /mnt && tar xvf "$HOME/kiss-chroot-2020.9-2.tar.xz" )

    # Create regular user.
    nchroot /mnt adduser nerditup

    # Setup repos?
    setup_repo_directory /mnt/home/nerditup

    # Set the hostname.
    printf '%s\n' "$hostname" > /mnt/etc/hostname
    
    # Download firmware.
    url=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot
    ( 
      cd /mnt/root && 
      curl -L -O "$url/linux-firmware-20201218.tar.gz" &&
      tar xvf linux-firmware-20201218.tar.gz
    )
    
    # Install ath10k wireless firmware.
    firmware_dir=/mnt/usr/lib/firmware
    mkdir -p "$firmware_dir/ath10k/QCA6174"
    cp -r /mnt/root/linux-firmware-20201218/ath10k/QCA6174/hw3.0 "$firmware_dir/ath10k/QCA6174"

    # Load the ath10k wireless drivers on boot.
    mkdir -p /mnt/etc/rc.d
    printf '%s\n%s\n' "modprobe ath10k_core" "modprobe ath10k_pci" > /mnt/etc/rc.d/ath10k.boot

    # Setup wpa_supplicant
    mkdir -p /mnt/etc/wpa_supplicant
    printf '%s\n\n' "ctrl_interface=DIR=/var/run/wpa_supplicant" > /mnt/etc/wpa_supplicant/wpa_supplicant.conf
    wpa_passphrase "$ssid" >> /etc/wpa_supplicant/wpa_supplicant.conf

    # Generate the fstab file.
    genfstab > /mnt/etc/fstab
}

main "$@"
