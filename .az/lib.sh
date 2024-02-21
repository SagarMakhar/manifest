# shellcheck disable=SC2034

colwhi=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput setaf 15 2>/dev/null) &> /dev/null || true
colred=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput setaf 1 2>/dev/null) &> /dev/null || true
colgre=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput setaf 2 2>/dev/null) &> /dev/null || true
colyel=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput setaf 3 2>/dev/null) &> /dev/null || true
colblu=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput setaf 4 2>/dev/null) &> /dev/null || true
txtcol=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput cols 2>/dev/null) &> /dev/null || true
txtbol=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput bold 2>/dev/null) &> /dev/null || true
txtcle=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput el 2>/dev/null) &> /dev/null || true
coff=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput civis 2>/dev/null) &> /dev/null || true
con=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput cnorm 2>/dev/null) &> /dev/null || true
txtres=$([[ "${TERM}" != "dumb" ]] && hash tput &>/dev/null && tput sgr0 2>/dev/null) &> /dev/null || true

__generate_line() {
	local count="${1}"
	local chars="${2}"

	printf "${chars}%.0s" $(seq 1 "${count}")
}

# prints messages
# example: message -er -sr -g -h Testmessage
# ::
# :: Testmessage :::::::::::::::::::::::::::
# ::
message () {
	local OPTIND OPTARG header spaces

	header=false
	startcolor=""
	endcolor=""
	startline=""
	endline=""
	intro=false
	gap=false

	while getopts ":e:ghis:" opt; do
		case "${opt}" in
			# color of colons at end (for headers)
			e)
				case "${OPTARG}" in
					g) endcolor="${colgre}" ;;
					b) endcolor="${colblu}" ;;
					r) endcolor="${colred}" ;;
					w) endcolor="${colwhi}" ;;
					y) endcolor="${colyel}" ;;
				esac
				;;

			# Blank lines are inserted before and after the first
			# line, starting with 2 colons.
			g) gap=true ;;

			# header & intro mutual exclusive, header wins
			# First line gets colons after the text to the end of
			# the line
			h) header=true ;;

			# header & intro mutual exclusive, header wins
			# two dots at beginning
			i) intro=true ;;

			# color of colons at begin of a line
			s)
				case "${OPTARG}" in
					g) startcolor="${colgre}" ;;
					b) startcolor="${colblu}" ;;
					r) startcolor="${colred}" ;;
					w) startcolor="${colwhi}" ;;
					y) startcolor="${colyel}" ;;
				esac
				;;
			*) ;;
		esac
	done
	shift $(( OPTIND - 1 ))

	${header} && intro=false

	for m in "${@}"; do
		spaces="   "
		${intro} && {
			spaces="${startcolor}::${txtres} "
			# just first line has intromarker
			intro=false
		}
		${header} && {
			spaces=""
			local mlength="${#m}"
			mlength=$((txtcol - mlength - 3 - 1 - 1))
			local line
			line="$(__generate_line ${mlength} ":")"

			${gap} && {
				startline="${startcolor}::${txtres}\n"
				endline="\n${startcolor}::${txtres}"
			}
			printf -v m "${startline}${startcolor}::${txtres} %s %s" "${m}" "${endcolor}${line}${txtres}${endline}"

			# just first line is a header line
			header=false
		}

		echo -e "${spaces}${m}"
	done
}

okay () {
	message -i -sg "${@}"
}

warn () {
	message -i -sy "${@}"
}

error () {
	message -i -sr "${@}"
}

debug () {
	message -i -sb "${@}"
}

# shellcheck disable=SC2317
trace () {
	debug "${@}"
}

info () {
	message -i -sw "${@}"
}

# shellcheck disable=SC2317
gap() {
	message -g -sg -eg "${@}"
}

header() {
	message -h -sg -eg "${@}"
}

function remove_cr() {
	tr -d '\r' <<<"${@}"
}

# print and run a command
# found at https://stackoverflow.com/a/71165011/1069083
function prun() {
	local PS4="${colred}:: cmd# ${txtres}"
	# next line: setting just for the current function and subshells of
	# this function
	local -
	set -o xtrace
	"${@}"
}

# like 'time' command, but with proper formating
function ptime() {
	local start
	local end
	local duration
	local out
	local ret

	start=$(date +%s.%N)
	# shellcheck disable=SC2068
	${@}
	ret=$?
	end=$(date +%s.%N)

	duration=$(echo "${end} - ${start}" | bc)
	printf -v out "Command took %.3f seconds\n" "${duration}"
	debug "${out}"

	return ${ret}
}

