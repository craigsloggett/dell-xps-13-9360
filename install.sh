#!/bin/sh
#
# This is a simple install script written in POSIX shell
# to be used to install KISS Linux (https://k1ss.org).
#
# Created by Craig Sloggett.


# Configuration Parameters

efi_system_partition=/dev/nvme0n1p1
root_partition=/dev/nvme0n1p2
root_mount_point=/mnt
hostname=xps
ssid=Jupiter-WiFi-5GHz

# Useful Functions

prepare_disk() {
    # Format the drive using either nvme format or dd.
    # Partition the disk (using GPT).
    # Format the EFI partition as FAT.
    # Format the root partition as ext4.
    :
}

mount_disk() {
    # Mount the root partition to /mnt
    # Create the /boot directory.
    # Mount the EFI partition to /mnt/boot 
    :
}

create_swapfile() {
    root=$root_mount_point
    block_size=$(stat -fc %s $root)
    block_count="4M"

    # Create the /var directory.
    mkdir -p "$root/var"

    # Generate the swapfile.
    dd if=/dev/zero of="$root/var/swapfile" bs=$block_size count=$block_count

    # Set the permissions on the swapfile to 600.
    chmod 600 "$root/var/swapfile"
    mkswap "$root/var/swapfile"
}

create_cmdline() {
    line=$(blkid $1)
    id=${line#*PARTUUID=\"}
    id=${id%%\"*}

    printf '%s\n' "root=PARTUUID=$id" > ${root_mount_point:-}/boot/cmdline.txt
}

chroot_command() {

	# getopts /optstring/ /name/ [/arg/...]
	while getopts :abc:u: name
	do
		case $name in
			c)	testing="$OPTARG" ;;
			u)	username="$OPTARG" ;;
			?)   	printf '%s: Invalid option.' "$OPTARG" ;;
			:)	printf '%s: Option argument is missing.' "$OPTARG" ;;
		esac
	done
	
	
#	# A simple chroot wrapper to execute commands in the new environment.	
#	chroot "$root_mount_point" /usr/bin/env -i \
#		HOME=/root \
#		TERM="$TERM" \
#		SHELL=/bin/sh \
#		USER=root \
#		CFLAGS="${CFLAGS:--march=x86-64 -mtune=generic -pipe -Os}" \
#		CXXFLAGS="${CXXFLAGS:--march=x86-64 -mtune=generic -pipe -Os}" \
#		MAKEFLAGS="${MAKEFLAGS:--j$(nproc 2>/dev/null || echo 1)}" \
#		/bin/sh -c "$*"
}

setup_repo_directory() {
	# Source Directories
	mkdir -p "$HOME/.local/src/github.com/kisslinux"
	mkdir -p "$HOME/.local/src/github.com/nerditup"

	# Repo Directory
	mkdir -p "$HOME/.local/repos/kisslinux"

	# Clone the source repositories.
	( cd "$HOME/.local/src/github.com/kisslinux" && git clone https://github.com/kisslinux/repo.git )
	( cd "$HOME/.local/src/github.com/nerditup" && git clone https://github.com/nerditup/kisslinux.git )

	ln -s "$HOME/.local/src/github.com/nerditup/kisslinux/" "$HOME/.local/repos/kisslinux/personal"
	ln -s "$HOME/.local/src/github.com/kisslinux/repo/core/" "$HOME/.local/repos/kisslinux/core"
	ln -s "$HOME/.local/src/github.com/kisslinux/repo/extra/" "$HOME/.local/repos/kisslinux/extra"
}

main() {
    # Globally disable globbing and enable exit-on-error.
    set -ef

    # Set the log colours.
    lcol='\033[1;33m' lcol2='\033[1;34m' lclr='\033[m'

    cd $HOME

    create_swapfile
    create_cmdline $root_partition

    # Download the kiss-chroot.
    url=https://github.com/kisslinux/repo/releases/download/2020.9-2
    curl -L -O "$url/kiss-chroot-2020.9-2.tar.xz"

    ( cd /mnt && tar xvf "$HOME/kiss-chroot-2020.9-2.tar.xz" )

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
