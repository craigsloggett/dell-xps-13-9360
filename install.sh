#!/bin/sh
#
# This is a simple install script written in POSIX shell
# to be used to install KISS Linux (https://k1ss.org).

# Configuration Parameters

NEW_ROOT=/mnt
HOSTNAME=xps
USERNAME=nerditup

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
    block_size="$( stat -fc %s ${NEW_ROOT:-}/. )"

    # Create a swapfile with a size equal to double the amount of memory of the system.
    mem_total_kb="$( grep MemTotal /proc/meminfo | awk '{print $2}' )"
    block_count="$(( mem_total_kb * 1024 / block_size * 2 ))"

    mkdir -p "${NEW_ROOT:-}/var"

    dd if=/dev/zero of="${NEW_ROOT:-}/var/swapfile" bs="$block_size" count="$block_count"

    chmod 600 "${NEW_ROOT:-}/var/swapfile"
    mkswap "${NEW_ROOT:-}/var/swapfile"
}

create_cmdline () {
    root_partition="$( mount | grep "${NEW_ROOT:-/} " | awk '{print $1}' )"

    line="$( blkid $root_partition )"
    id="${line#*PARTUUID=\"}"
    id="${id%%\"*}"

    printf '%s\n' "root=PARTUUID=$id" > ${NEW_ROOT:-}/boot/cmdline.txt
}

main() {
    # Globally disable globbing and enable exit-on-error.
    set -ef

    ################
    # Prepare Disk #
    ################

    # prepare the disk
    # mount the disk

    [ -z "$NEW_ROOT" ] && return 1

    create_swapfile
    create_cmdline

    #############
    # Prepare / #
    #############

    # TODO: Check if $NEW_ROOT already contains a base filesystem layout.

    # Download the kiss-chroot.
    cd $HOME
    url=https://github.com/kisslinux/repo/releases/download/2020.9-2
    curl -L -O "$url/kiss-chroot-2020.9-2.tar.xz"

    ( cd "$NEW_ROOT" && tar xvf "$HOME/kiss-chroot-2020.9-2.tar.xz" )

    ################
    # Configure OS #
    ################

    # /etc/hostname
    printf '%s\n' "$HOSTNAME" > "$NEW_ROOT/etc/hostname"

    # /etc/hosts
    cat <<- EOF > "$NEW_ROOT/etc/hosts"
        127.0.0.1   localhost
        127.0.1.1   $HOSTNAME.nerditup.ca $HOSTNAME
    EOF

    # Generate the fstab file.
    # TODO: Write my own genfstab.
    genfstab -U "$NEW_ROOT" > "$NEW_ROOT/etc/fstab"

    ##########################
    # Configure Regular User #
    ##########################

    # TODO: Check if $NEW_ROOT already has $USERNAME created.

    # Create regular user.
    nchroot "$NEW_ROOT" adduser "$USERNAME"

    # Add dotfiles to home

    #
    # KISS Specific implementation.
    #

    # ~/.profile
    cat <<- 'EOF' > "$NEW_ROOT/home/$USERNAME/.profile"
        # Compiler Options
        export CFLAGS="-O3 -pipe -march=native"
        export CXXFLAGS="$CFLAGS"
        export MAKEFLAGS="-j4"

        # KISS Repositories
        export KISS_PATH=''
        KISS_PATH=$KISS_PATH:$HOME/.local/repos/kisslinux/personal
        KISS_PATH=$KISS_PATH:$HOME/.local/repos/kisslinux/core
        KISS_PATH=$KISS_PATH:$HOME/.local/repos/kisslinux/extra
    EOF
    
    #############################
    # Configure Package Manager #
    #############################

    #
    # Setup Repositories
    #

    # Single quoting arguments/commands that contain variables to ensure the value is taken from 
    # within the new environment.

	# Source Directories
    repo_src='$HOME/.local/src/github.com/kisslinux'
    repo_src_personal='$HOME/.local/src/github.com/nerditup'

	nchroot -u $USERNAME $NEW_ROOT mkdir -p "$repo_src"
	nchroot -u $USERNAME $NEW_ROOT mkdir -p "$repo_src_personal"

	# Clone the source repositories.
    repo_url=https://github.com/kisslinux/repo.git
    repo_url_personal=https://github.com/nerditup/kisslinux.git

	nchroot -u $USERNAME $NEW_ROOT cd "$repo_src" && git clone "$repo_url"
	nchroot -u $USERNAME $NEW_ROOT cd "$repo_src_personal" && git clone "$repo_url_personal" 

	# Repo Directory
    repo_dir='$HOME/.local/repos/kisslinux/core'
    repo_dir_extra='$HOME/.local/repos/kisslinux/extra'
    repo_dir_personal='$HOME/.local/repos/kisslinux/personal'

    ( set +f; nchroot -u $USERNAME $NEW_ROOT mkdir -p "${repo_dire%/*}"; set -f; )

	nchroot -u $USERNAME $NEW_ROOT ln -s "$repo_src/repo/core" "$repo_dir"
	nchroot -u $USERNAME $NEW_ROOT ln -s "$repo_src/repo/extra" "$repo_dir_extra"
	nchroot -u $USERNAME $NEW_ROOT ln -s "$repo_src_personal/kisslinux" "$repo_dir_personal"

    # Update the package manager
    nchroot -u $USERNAME $NEW_ROOT kiss update

    # Rebuild all "installed" packages.
    nchroot -u $USERNAME $NEW_ROOT ( cd /var/db/kiss/installed && set +f; kiss build * )

    # Install additional system administration utilities.
    nchroot -u $USERNAME $NEW_ROOT kiss b e2fsprogs
    nchroot -u $USERNAME $NEW_ROOT kiss b dosfstools
    nchroot -u $USERNAME $NEW_ROOT kiss b efibootmgr
    nchroot -u $USERNAME $NEW_ROOT kiss i e2fsprogs
    nchroot -u $USERNAME $NEW_ROOT kiss i dosfstools
    nchroot -u $USERNAME $NEW_ROOT kiss i efibootmgr

    # Install the Linux kernel.
    nchroot -u $USERNAME $NEW_ROOT kiss b linux
    nchroot -u $USERNAME $NEW_ROOT kiss i linux

    nchroot /mnt efibootmgr --create --disk /dev/nvme0n1 --part 1 --loader /EFI/boot/bootx64.efi --label "Linux"

    # Install an init system.
    nchroot -u $USERNAME $NEW_ROOT kiss b baseinit
    nchroot -u $USERNAME $NEW_ROOT kiss i baseinit

    ######################
    # Configure Hardware #
    ######################

    # Download firmware.
    url=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot
    ( 
      cd "$NEW_ROOT/root" && 
      curl -L -O "$url/linux-firmware-20201218.tar.gz" &&
      tar xvf linux-firmware-20201218.tar.gz
    )
    
    # Install ath10k wireless firmware.
    ath10k_firmware_dir="$NEW_ROOT/root/linux-firmware-20201218/ath10k/QCA6174/hw3.0"
    system_firmware_dir="$NEW_ROOT/lib/firmware"
    mkdir -p "$system_firmware_dir/ath10k/QCA6174"
    cp -r "$ath10k_firmware_dir" "$system_firmware_dir/ath10k/QCA6174"

    # Load the ath10k wireless drivers on boot.
    mkdir -p "$NEW_ROOT/etc/rc.d"
    printf '%s\n' "modprobe ath10k_core" > "$NEW_ROOT/etc/rc.d/ath10k.boot"
    printf '%s\n' "modprobe ath10k_pci" >> "$NEW_ROOT/etc/rc.d/ath10k.boot"

    #####################
    # Configure Network #
    #####################

    # Setup wpa_supplicant
    mkdir -p /mnt/etc/wpa_supplicant
    printf '%s\n\n' "ctrl_interface=DIR=/var/run/wpa_supplicant" > /mnt/etc/wpa_supplicant/wpa_supplicant.conf

    wpa_passphrase "$ssid" >> /etc/wpa_supplicant/wpa_supplicant.conf
}

main "$@"
