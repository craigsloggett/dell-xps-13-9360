#!/bin/sh

testing() {
	while getopts :abc:u: name; do
		echo "$name"
		echo "$OPTARG"
		echo "$OPTIND"
		case $name in
			z)	b="$OPTARG" ;;
			c)	c="$OPTARG" ;;
			u)	u="$OPTARG" ;;
			:)	printf '%s: Option argument is missing.' "$OPTARG" ;;
			?)	printf '%s: Invalid option.' "$OPTARG" ;;
		esac
	done
}

testing -u nerditup
