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

create-folder-tree() {
	local source_tree="${1}"
	local recreate=${2}

	valid-directory-name "${source_tree}" || {
		error "Invalid source tree name: ${source_tree}" \
		      "See message above for details; exiting..."
		return 1
	}

	[ -e "${source_tree}" ] &&   {
		if ${recreate}; then
			info "Recreating the source tree: ${source_tree}" \
			     "This may take a while..."
			ptime delete-folder-tree  "${source_tree}" || {
				error "Failed to delete the source tree: ${source_tree}" \
				      "See message above for details; exiting..."
				return 1
			}
		else
			warn "source_tree does already exist: ${source_tree}" \
			     "Nothing to do..."
			return 0
		fi
	}

	# create the source tree
	mkdir -p "${source_tree}"
}

# Set the default values for the environment variables
buildconfpath=""
create=false
delete=false
force=false

help() {
	cat <<-EOF
	Usage: $0 [options]

	Options:
	  # Build configuration file creation
	  -B, --build-config <buildconfig>
	                Build configuration file creation enabled. You need the
	                option(s) --add-build-config.
	  --build-config-add  <buildoption> ...
	                Add a build option to the build configuration file.
	                format: "option=value". This is 1 to 1 added to the
	                build configuration file.
	                🔁 Can be used more than once.

	  # Other options
	  -c, --create  <source_tree>
	                Create the source tree
	  -d, --delete  <source_tree>
	                Delete the source tree (can be forced)
	  -f, --force
	                Force some operations
	  -h, --help
	                Show this help message and exit
	EOF
}

# command line parsing with getopt
temp=$(getopt \
	-o B:c:d:fh \
	--long build-config: \
	--long build-config-add: \
	--long create: \
	--long delete: \
	--long force \
	--long help \
	-n "$0" -- "$@")
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then echo "Terminating..." >&2; exit 1; fi
eval set -- "$temp"
unset temp

while true; do
	case "$1" in
		-B | --build-config )
			buildconfpath="${2}"
			shift
			info "Preparing the build configuration: ${buildconfpath}"
			[ -e "${buildconfpath}" ] && {
				warn "buildconfpath does already exist: ${buildconfpath}, recreating..."
				rm -f "${buildconfpath}"
			}
			touch "${buildconfpath}" || {
				error "Failed to create the build configuration: ${buildconfpath}" \
				      "See (possible) message above for details; exiting..."
				exit 1
			}
			;;

		--build-config-add )
			buildoption="${2}"
			shift
			echo "${buildoption}" >> "${buildconfpath}"
			;;

		-c | --create )
			source_tree="${2}"
			shift
			create=true
			;;

		-d | --delete )
			source_tree="${2}"
			shift
			delete=true
			;;

		--force )
			force=true
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

${create} && {
	info "Creating the source tree: ${source_tree}"
	create-folder-tree  "${source_tree}" "${force}" || {
		error "Failed to create the source tree: ${source_tree}" \
		      "See message above for details; exiting..."
		exit 1
	}
	okay "done for source tree: ${source_tree}"
}

exit 0
