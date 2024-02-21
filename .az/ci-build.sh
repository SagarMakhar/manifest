#!/usr/bin/env bash
#
# vim: set ft=bash sw=8 ts=8 noet ai smartindent:
set -o errexit \
    -o nounset \
    -o pipefail \
    -o noclobber

PS4='+ ${BASH_SOURCE#"$PWD/"}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): $?} '

# shellcheck disable=SC1091
source lib.sh

# Set the default values for the environment variables

help() {
	cat <<-EOF
	Usage: $0 [options]

	Options:
	  # Other options
	  -h, --help
	                Show this help message and exit
	EOF
}

# command line parsing with getopt
temp=$(getopt \
	-o h \
	--long help \
	-n "$0" -- "$@")
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then echo "Terminating..." >&2; exit 1; fi
eval set -- "$temp"
unset temp

while true; do
	case "$1" in
		-h | --help )
			help
			exit 0
			;;

		-- )
			break
			;;

		* )
			error "Internal error!" \
			      "Unknown option: $1"
			exit 1
			;;
	esac

	shift
done

exit 0
