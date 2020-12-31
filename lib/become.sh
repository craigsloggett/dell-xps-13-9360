#!/bin/sh
#
# This script is used to showcase privilege escalation
# in a POSIX shell script without utilities like sudo
# or doas.
#
# Created by Craig Sloggett.

main() {
	su="$(command -v su)"

	# Using `su` to execute the command `-c command`.

	# stdin is set to the tty to ensure the command executed
	# by `su` retains the original stdin (e.g. when stdin is
	# a pipe). This ensures the pipe output isn't passed in
	# as the password value to `su`.
	"$su" -c "$1" "${2:-root}" </dev/tty
}

main "$@"
