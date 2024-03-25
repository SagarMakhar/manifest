#!/usr/bin/env bash
#
# vim: set ft=bash sw=8 ts=8 noet ai smartindent:
set -o errexit \
    -o nounset \
    -o pipefail \
    -o noclobber

PS4='+ ${BASH_SOURCE#"$PWD/"}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): $?} '
SCRIPTDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"


# shellcheck disable=SC1091
source ${SCRIPTDIR}/lib.sh
LIB_MM=">"

used_tools=()
used_tools+=("ln" "realpath" "readlink" "tr")

for tool in "${used_tools[@]}"; do
	check-tool-exists "${tool}"
done

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
			delete-folder-tree  "${source_tree}" || {
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

build-do() {
	local phone="${1}"
	local buildcleanout=${2}
	local buildcleansources=${3}
	local cleanstring=""

	[ -z "${phone}" ] && {
		error "Phone target not set, but needed (-p)"
		exit 1
	}

	${buildcleanout} && {
		cleanstring="${cleanstring} -d out"
	}

	${buildcleansources} && {
		cleanstring="${cleanstring} -d sources"
	}

	./softing-build.sh ${cleanstring} -p ${phone} -b -n "${buildidentifier}"
}

buildtree_setup() {
	buildtreeproblemfound=false
	if [ -z "${buildtreesupportpath}" ]; then
		warn "No build support path given"
		buildtreeproblemfound=true
	fi

	if [ ! -e "${buildtreesupportpath}" ]; then
		warn "build support path does not exist: ${buildtreesupportpath}"
		buildtreeproblemfound=true
	fi

	if [ -z "${buildtreebase}" ]; then
		warn "No build tree base given"
		buildtreeproblemfound=true
	fi

	${buildtreeproblemfound} && {
		error "Problems with the build tree setup found" \
		      "See message above for details; exiting..."
		exit 1
	}

	mkdir -p "${buildtreebase}"
	buildtreesupportpath="$(realpath --relative-to "${buildtreebase}"  "${buildtreesupportpath}")"

	info "Setting up the build tree base: ${buildtreebase} with support:${buildtreesupportpath}" \
	     "This may take a while..."

	(
		cd "${buildtreebase}"  || exit 1
		ln -sf "${buildtreesupportpath}"/softing-build.sh
	)
}

buildtree_perform_checkout() {
	local phonetarget="${1}"
	local buildtreecheckoutpath="${2}"

	[ -z "${phonetarget}" ] && {
		error "Phone target not set, but needed (-p)"
		exit 1
	}

	[ -z "${buildtreecheckoutpath}" ] && {
		error "No build tree checkout path given"
		exit 1
	}

	[ ! -d "${buildtreecheckoutpath}" ] && {
		error "build tree path isn't a directory: ${buildtreecheckoutpath}"
		exit 1
	}

	(
		cd "${buildtreecheckoutpath}" || exit 1
		./softing-build.sh -p "${phonetarget}" -S
	)
}

check-folder-exists() {
	local folders=("${@}")
	local somethingnotfound=false

	[ ${#folders[@]} -eq 0 ] && {
		warn "No folders to check" \
		     "Nothing to do..."
		return 0
	}

	for folder in "${folders[@]}"; do
		[ ! -e "${folder}" ] && {
			error "Folder does not exist: ${folder}"
			somethingnotfound=true
		}
	done

	${somethingnotfound} && return 1
	return 0
}

lm_setup() {
	local lmfile="${1}"
	local lmfolder=$(dirname "${lmfile}")

	[ -z "${lmfile}" ] && {
		error "No local manifest file given"
		exit 1
	}

	[ ! -e "${lmfolder}" ] && mkdir -p "${lmfolder}"

	cat <<-EOF >| "${lmfile}"
	<?xml version="1.0" encoding="UTF-8"?>
	<manifest>
	EOF
	for entry in "${lmentries[@]}"; do
		echo "${entry}" >> "${lmfile}"
	done
	cat <<-EOF >> "${lmfile}"
	</manifest>
	EOF
}

# Set the default values for the environment variables
build=false
buildcleanout=false
buildcleansources=false
buildconfpath=""
buildidentifier="develop"
buildtreesetup=false
buildtreesupportpath=""
buildtreebase=""
buildtreecheckout=false
buildtreecheckoutpath=""
create=false
delete=false
force=false
checkfolderexists=false
checkfolders=()
lmmanipulation=false
lmentries=()
phone=false
phonetarget=""
updatecomponent=false
updatecomponentnames=("")

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

	  # Build configuration
	  --build
	                Build the sources.
	                ⚠️  You have to set the phone via -p.
	  --build-clean-sources  <bool>
	                Clean the sources before build. Default: false
	                Usefull only with --build.
	  --build-clean-out  <bool>
	                Clean the output before build. Default: false
	                Means removing of out folder / clean build.
	                Usefull only with --build.
	  --build-identifier <string>
	                Identifier for the build. This is used to identify the
	                build in the build system. Default: develop

	  # Build tree setup
	  # All options must be used at least once.
	  --buildtree-buildsupport  <path>
	                Path to the build support scripts. This is the path to
	                the folder where the build support scripts are located
	                which are used to setup a whole build infrastrukture.
	  --buildtree-prepare-base  <tree>
	                Prepare the build tree base in folder <tree>. <tree> is
	                the root of the build tree, eg. '/path/to/tree/lynx'.
	                ⚠️  Currently only useable with the
	                --buildtree-buildsupport option.
	  -S, --buildtree-performe-checkout
	                Perform the checkout of the source tree.
	                ⚠️  This is a long running operation.
	                Only useable with --buildtree-prepare-base and -p.

	  # Remote information
	  --lm-file  <file>
	                Local manifest file to use. The whole path to the
	                <file> must exists. The file themselves will be
	                re-created.
	  --lm-add-entry "<string>"
	                Add a line with content <string> into a local manifest file.
	                Example:
	                  --lm-add-entry '<remote name="softingorigin" fetch="https://dev.azure.com/SoftingAutomotiveElectronics/Automotive/_git />'
	                  --lm-add-entry '<extend-project name="VCPI.BMW.VCPI-device" remote="softingorigin" revision="refs/heads/feso/testbranch" />'
	                🔁 Can be used more than once.

	  # Other options
	  -c, --create  <source_tree>
	                Create the source tree
	  --check-folder-exists  <source_tree> ...
	                Check if the source tree exists. This option can be
	                used more than once. Only when all folders exist, the
	                script will exit with 0.
	                🔁 Can be used more than once.
	  -d, --delete  <source_tree>
	                Delete the source tree (can be forced)
	  -f, --force
	                Force some operations
	  -h, --help
	                Show this help message and exit
	  -p, --phone   <phone>
	                Set target phone.
	  --update-component  <component> ...
	                Update the component <component> in the source tree.
	                This could a long running operation. The sources has to
	                be checkout already.
	                🔁 Can be used more than once.
	EOF
}

# command line parsing with getopt
temp=$(getopt \
	-o B:c:d:fhp:S: \
	--long build \
	--long build-clean-sources: \
	--long build-clean-out: \
	--long build-config: \
	--long build-config-add: \
	--long build-identifier: \
	--long buildtree-buildsupport: \
	--long buildtree-prepare-base: \
	--long buildtree-perform-checkout \
	--long create: \
	--long check-folder-exists: \
	--long delete: \
	--long force \
	--long help \
	--long lm-add-entry: \
	--long lm-file: \
	--long phone: \
	--long update-component: \
	-n "$0" -- "$@")
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then echo "Terminating..." >&2; exit 1; fi
eval set -- "$temp"
unset temp

while true; do
	case "$1" in
		--build )
			build=true
			;;

		--build-clean-sources )
			buildcleansources=$(make-string-to-boolean "${2}")
			shift
			;;

		--build-clean-out )
			buildcleanout=$(make-string-to-boolean "${2}")
			shift
			;;

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

		--build-identifier )
			buildidentifier="${2}"
			shift
			;;

		--buildtree-buildsupport )
			buildtreesupportpath="${2}"
			shift
			buildtreesetup=true
			;;

		--buildtree-prepare-base )
			buildtreebase="${2}"
			shift
			buildtreesetup=true
			;;

		-S | --buildtree-perform-checkout )
			buildtreecheckout=true
			;;

		-c | --create )
			source_tree="${2}"
			shift
			create=true
			;;

		--check-folder-exists )
			checkfolders+=("${2}")
			shift
			checkfolderexists=true
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

		--lm-add-entry )
			lmentries+=("${2}")
			shift
			lmmanipulation=true
			;;

		--lm-file )
			lmfile="${2}"
			shift
			lmmanipulation=true
			;;

		-p | --phone )
			phonetarget="${2}"
			shift
			phone=true
			;;

		--update-component )
			updatecomponentnames+=("${2}")
			shift
			updatecomponent=true
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

${checkfolderexists} && {
	info "Checking if the folders in source tree exists"
	check-folder-exists  "${checkfolders[@]}" || {
		error "Some folders do not exist" \
		      "See message above for details; exiting..."
		exit 1
	}
	okay "All folders exist"
}

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

${buildtreesetup} && {
	buildtree_setup
}

${buildtreecheckout} && {
	buildtree_perform_checkout "${phonetarget}" "${buildtreebase}"
}

${updatecomponent} && {
	info "Updating the components: ${updatecomponentnames[@]}"
	./softing-build.sh -p "${phonetarget}" -c "repo sync --no-repo-verify -v ${updatecomponentnames[*]}"
}

${lmmanipulation} && {
	lm_setup "${lmfile}"
}

${build} && {
	build-do "${phonetarget}" "${buildcleanout}" "${buildcleansources}"
}

exit 0
