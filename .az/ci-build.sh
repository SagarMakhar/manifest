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

delete-folder-tree() {
	local source_tree="${1}"

	valid-directory-name "${source_tree}" || {
		error "Invalid source tree name: ${source_tree}" \
		      "See message above for details; exiting..."
		return 1
	}

	[ ! -e "${source_tree}" ] && {
		warn "source_tree does not exist: ${source_tree}" \
		     "Nothing to do..."
		return 0
	}

	# delete the whole source tree
	rm -rf "${source_tree}"
}

# Set the default values for the environment variables
delete=false

help() {
	cat <<-EOF
	Usage: $0 [options]

	Options:
	  # Other options
	  -d, --delete  <source_tree>
	                Delete the source tree (can be forced)
	  -h, --help
	                Show this help message and exit
	EOF
}

# command line parsing with getopt
temp=$(getopt \
	-o d:h \
	--long delete: \
	--long help \
	-n "$0" -- "$@")
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then echo "Terminating..." >&2; exit 1; fi
eval set -- "$temp"
unset temp

while true; do
	case "$1" in
		-d | --delete )
			source_tree="${2}"
			shift
			delete=true
			;;

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

${delete} && {
	info "Deleting the source tree: ${source_tree}" \
	     "This may take a while..."
	delete-folder-tree  "${source_tree}" || {
		error "Failed to delete the source tree: ${source_tree}" \
		      "See message above for details; exiting..."
		exit 1
	}
	okay "Deleted the source tree: ${source_tree}"
}

exit 0
