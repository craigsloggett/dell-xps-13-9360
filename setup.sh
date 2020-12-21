#!/bin/sh
#
# This is a simple install script written in POSIX shell
# to be used to install KISS Linux (https://k1ss.org).
#
# Created by Craig Sloggett.

# Useful Functions

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

setup_profile() {
	cat <<- 'EOF' > "$HOME/.profile"
		# KISS Repositories
		export KISS_PATH=''
		KISS_PATH=$KISS_PATH:$HOME/.local/repos/kisslinux/personal
		KISS_PATH=$KISS_PATH:$HOME/.local/repos/kisslinux/core
		KISS_PATH=$KISS_PATH:$HOME/.local/repos/kisslinux/extra
		
		# Compiler Options
		export CFLAGS="-O3 -pipe -march=native"
		export CXXFLAGS="$CFLAGS"
		export MAKEFLAGS="-j4"
	EOF
}

main() {
	# Globally disable globbing and enable exit-on-error.
	set -ef
	
	cd "$HOME"
	
	# Remove this by creating dotfiles.
	git config --global pull.rebase false

	# TODO: Make this idempotent.
	setup_repo_directory

	setup_profile

	source ~/.profile

	# TODO: Automatically supply password to su -c ? Use sudo?
	kiss update
	( cd /var/db/kiss/installed && set +f; kiss build * )

	for package in e2fsprogs dosfstools wpa_supplicant dhcpcd; do
		kiss b "$package" && kiss i "$package"
	done

	kiss b linux && kiss i linux
	kiss b efibootmgr && kiss i efibootmgr

	su -c 'efibootmgr --create --disk /dev/nvme0n1 --part 1 --loader /EFI/boot/bootx64.efi --labl "Linux"'

	kiss b baseinit && kiss i baseinit

	ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant /usr/lib/dhcpcd/dhcpcd-hooks/
	ln -s /etc/sv/dhcpcd/ /var/service
}

main "$@"
