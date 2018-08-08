#!/usr/bin/env bash
#shellcheck disable=SC2034

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set \
	-o errexit \
	-o errtrace \
	-o nounset \
	-o pipefail

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v "BASH_SOURCE[0]" ]; then
	_XML_BASH_RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
	_XML_BASH_RUNTIME_EXECUTABLE_FILENAME="$(basename "${_XML_BASH_RUNTIME_EXECUTABLE_PATH}")"
	_XML_BASH_RUNTIME_EXECUTABLE_NAME="${_XML_BASH_RUNTIME_EXECUTABLE_FILENAME%.*}"
	_XML_BASH_RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${_XML_BASH_RUNTIME_EXECUTABLE_PATH}")"
	_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
	declare -r \
		_XML_BASH_RUNTIME_EXECUTABLE_PATH \
		_XML_BASH_RUNTIME_EXECUTABLE_FILENAME \
		_XML_BASH_RUNTIME_EXECUTABLE_NAME \
		_XML_BASH_RUNTIME_EXECUTABLE_DIRECTORY \
		_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar _XML_BASH_RUNTIME_COMMANDLINE_PARAMETERS=("${@}")

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
_xml_bash_init(){
	if ! _xml_bash_process_commandline_parameters "${@}"; then
		printf\
			'Error: %s: Invalid command-line parameters.\n'\
			"${FUNCNAME[0]}"\
			1>&2
		_xml_bash_print_help
		exit 1
	fi

	exit 0
}; declare -fr _xml_bash_init

_xml_bash_create_temp_file(){
	mktemp\
		--tmpdir\
		bash.xml.XXXXXX.xml
}

# Remove data from XML file specified by XPath
xml_remove_xpath(){
	local -r xml_file="$1"; shift
	local -r node_xpath="$1"

	case "${xml_file}" in
		-)
			xmlstarlet\
				edit\
				--pf\
				--ps\
				--delete\
				"${node_xpath}"
			;;
		*)
			local temp_file
			temp_file="$(_xml_bash_create_temp_file)"; local -r temp_file

			xmlstarlet\
				edit\
				--pf\
				--ps\
				--delete\
				"${node_xpath}"\
				"${xml_file}"\
				>"${temp_file}"

			mv\
				--force\
				"${temp_file}"\
				"${xml_file}"
			;;
	esac
	return
}

# Transform an XML file according to an XSL file
xml_transform_file(){
	local xsl_file="$1"; shift
	local xml_file="$1"

	case "${xml_file}" in
		-)
			xmlstarlet\
				transform\
				"${xsl_file}"
			;;
		*)
			local temp_file
			temp_file="$(_xml_bash_create_temp_file)"; local -r temp_file

			xmlstarlet\
				transform\
				"${xsl_file}"\
				"${xml_file}"\
				>"${temp_file}"

			mv\
				--force\
				"${temp_file}"\
				"${xml_file}"
			;;
	esac
	return
}

# Beautify a XML file(indentation: tabular charactor, currently not adjustable)
xml_beautify_file(){
	local xml_file="$1"

	case "${xml_file}" in
		-)
			xmlstarlet\
				format\
				--indent-tab
			;;
		*)
			local temp_file
			temp_file="$(_xml_bash_create_temp_file)"; local -r temp_file

			xmlstarlet\
				format\
				--indent-tab\
				"${xml_file}"\
				>"${temp_file}"

			mv\
				--force\
				"${temp_file}"\
				"${xml_file}"
			;;
	esac

}

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
_xml_bash_trap_errexit(){
	printf 'An error occurred and the script is prematurely aborted\n' 1>&2
	return 0
}; declare -fr _xml_bash_trap_errexit

_xml_bash_trap_exit(){
	return 0
}; declare -fr _xml_bash_trap_exit

_xml_bash_trap_return(){
	local returning_function="${1}"

	printf 'DEBUG: %s: returning from %s\n' "${FUNCNAME[0]}" "${returning_function}" 1>&2
}; declare -fr _xml_bash_trap_return

_xml_bash_trap_interrupt(){
	printf 'Recieved SIGINT, script is interrupted.\n' 1>&2
	return 0
}; declare -fr _xml_bash_trap_interrupt

_xml_bash_print_help(){
	# Backticks in Markdown is <code> syntax
	# shellcheck disable=SC2016
	{
		printf -- "%s's Help Information\\n" "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf -- '===========================\n'
		printf -- 'HINT: This help info is in Markdown syntax, redirect the stderr output to a file and read it using your preferred Markdown reader!\n\n'
		printf -- '``````bash\n'
		printf -- '"%s" --help 2> "%s.help.markdown"\n' "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}" "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf -- 'xdg-open "%s.help.markdown"\n' "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf -- '``````\n\n'
		printf -- 'Synopsis\n'
		printf -- '--------\n'
		printf -- '### Library Call Mode ###\n'
		printf -- 'Source this script in a script and directly call all the functions defined in the %s library.\n\n' "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf -- '````````````````bash\n'
		printf -- 'source "%s"\n' "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf -- 'xml_beautify_file to_be_beautified.xml\n'
		printf -- '````````````````````\n\n'
		printf -- '### Direct Execution Mode ###\n'
		printf -- 'Directly execute xml.bash and use it under the command-line interface.\n\n'
		printf -- '````````````````bash\n'
		printf -- '"%s" --beautify-file to_be_beautified.xml\n' "${_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf -- '````````````````````\n\n'
		printf -- 'Implemented Functions\n'
		printf -- '---------------------\n'
		printf -- 'Specify single dash(`-`) for input XML file to indicate input from standard input device(stdin) and output to standard output device(stdout)\n\n'
		printf -- '### xml_beautify_file / --beautify-file _xml_file_to_be_beautified_ ###\n'
		printf -- 'Beautify the specified XML file.\n\n'
		printf -- '### xml_remove_xpath / --remove-xpath _xml_file_ _xpath_to_be_removed_ ###\n'
		printf -- 'Remove the specified element using XPath.\n\n'
		printf -- '### xml_transform_file / --transform-file _xsl_file_ _xml_file_to_be_transformed\n'
		printf -- 'Transform the specified XML file using a XSL file\n\n'
		printf -- 'Support\n'
		printf -- '-------\n'
		printf -- 'Please visit our issue tracker:  \n'
		printf -- '<https://github.com/Lin-Buo-Ren/xml.bash/issues>\n\n'
	} 1>&2
	return 0
}; declare -fr _xml_bash_print_help;

_xml_bash_process_commandline_parameters() {
	if [ "${#_XML_BASH_RUNTIME_COMMANDLINE_PARAMETERS[@]}" -eq 0 ]; then
		return 0
	fi

	# modifyable parameters for parsing by consuming
	local -a parameters=("${@}")

	# Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer it activation till returning(Y: Do debug)
	local enable_debug=N

	while true; do
		if [ "${#parameters[@]}" -eq 0 ]; then
			break
		else
			case "${parameters[0]}" in
					--help\
					|-h)
					_xml_bash_print_help
					exit 0
					;;
					--debug\
					|-d)
					enable_debug=Y
					;;
				*)
					printf 'ERROR: Unknown command-line argument "%s"\n' "${parameters[0]}" >&2
					return 1
					;;
			esac
			# shift array by 1 = unset 1st then repack
			unset 'parameters[0]'
			if [ "${#parameters[@]}" -ne 0 ]; then
				parameters=("${parameters[@]}")
			fi
		fi
	done

	if [ "${enable_debug}" = Y ]; then
		trap 'trap_return "${FUNCNAME[0]}"' RETURN
		set -o xtrace
	fi
	return 0
}; declare -fr _xml_bash_process_commandline_parameters

if [ "${#BASH_SOURCE[*]}" = 1 ]; then
	_xml_bash_init "${@}"
fi

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
declare -r META_BASED_ON_GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION=v1.26.0-32-g317af27-dirty
## You may rebase your script to incorporate new features and fixes from the template