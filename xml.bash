#!/usr/bin/env bash
# A Bourn-again Shell(bash) library and console utility to manipulate XML markup documents
# 林博仁 © 2018

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set \
	-o errexit \
	-o errtrace \
	-o nounset \
	-o pipefail

## Runtime Dependencies Checking
declare\
	runtime_dependency_checking_result=still-pass\
	required_software

for required_command in \
	basename \
	dirname \
	realpath \
	xmlstarlet; do
	if ! command -v "${required_command}" &>/dev/null; then
		runtime_dependency_checking_result=fail

		case "${required_command}" in
			basename \
			|dirname \
			|realpath)
				required_software='GNU Coreutils'
				;;
			xmlstarlet)
				required_software='XMLStarlet command line XML toolkit'
				;;
			*)
				required_software="${required_command}"
				;;
		esac

		printf -- \
			'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n' \
			"${required_software}" \
			1>&2
		unset required_software
	fi
done; unset required_command required_software

if [ "${runtime_dependency_checking_result}" = fail ]; then
	printf -- \
		'Error: Runtime dependency checking fail, the progrom cannot continue.\n' \
		1>&2
	exit 1
fi; unset runtime_dependency_checking_result

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v 'BASH_SOURCE[0]' ]; then
	_XML_BASH_RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
	_XML_BASH_RUNTIME_EXECUTABLE_FILENAME="$(basename "${_XML_BASH_RUNTIME_EXECUTABLE_PATH}")"
	_XML_BASH_RUNTIME_EXECUTABLE_NAME="${_XML_BASH_RUNTIME_EXECUTABLE_FILENAME%.*}"
	_XML_BASH_RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${_XML_BASH_RUNTIME_EXECUTABLE_PATH}")"
	_XML_BASH_RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
	# shellcheck disable=SC2034
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
	local \
		mode=default \
		xsl_file \
		xml_file \
		xpath

	if ! \
		_xml_bash_process_commandline_parameters \
		mode \
		xsl_file \
		xml_file \
		xpath \
		"${@}"; then
		printf\
			'Error: %s: Invalid command-line parameters.\n'\
			"${FUNCNAME[0]}"\
			1>&2
		_xml_bash_print_help
		exit 1
	fi

	case "${mode}" in
		beautify-file)
			xml_beautify_file \
				"${xml_file}"
			;;
		default)
			_xml_bash_print_help
			exit 0
			;;
		remove-xpath)
			xml_remove_xpath \
				"${xml_file}" \
				"${xpath}"
			;;
		transform-file)
			xml_transform_file \
				"${xsl_file}" \
				"${xml_file}"
			;;
		*)
			printf -- \
				'Error: Illegal mode selected, please report bug.\n' \
				1>&2
			;;
	esac

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
	printf \
		'An error occurred and the script is prematurely aborted\n' \
		1>&2
	return 0
}; declare -fr _xml_bash_trap_errexit

_xml_bash_trap_exit(){
	return 0
}; declare -fr _xml_bash_trap_exit

_xml_bash_trap_return(){
	local returning_function="${1}"

	printf \
		'DEBUG: %s: returning from %s\n' \
		"${FUNCNAME[0]}" \
		"${returning_function}" \
		1>&2
}; declare -fr _xml_bash_trap_return

_xml_bash_trap_interrupt(){
	printf '\n' # Separate previous output
	printf \
		'Recieved SIGINT, script is interrupted.' \
		1>&2
	return 1
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

	local -n mode="${1}"; shift
	local -n xsl_file="${1}"; shift
	local -n xml_file="${1}"; shift
	local -n xpath="${1}"; shift

	# modifyable parameters for parsing by consuming
	local -a parameters=("${@}")

	# Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer it activation till returning(Y: Do debug)
	local enable_debug=N

	# We only allow 1 subcommand per command
	local -i count_mode_specified=0

	while true; do
		if [ "${#parameters[@]}" -eq 0 ]; then
			break
		else
			case "${parameters[0]}" in
					--help \
					|-h)
					_xml_bash_print_help
					exit 0
					;;
					--debug \
					|-d)
					enable_debug=Y
					;;
				--beautify-file)
					mode=beautify-file
					(( count_mode_specified += 1 ))

					# shift 1 parameter
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi

					# Error if no parameter left
					if [ "${#parameters[@]}" -eq 0 ]; then
						printf -- \
							'Error: %s requires 1 argument.\n' \
							--beautify-file \
							1>&2
						return 1
					fi

					# Assign argument and leave the parameter to be shifted at the end-of-loop
					xml_file="${parameters[0]}"
					;;
				--remove-xpath)
					mode=remove-xpath
					(( count_mode_specified += 1 ))

					# shift 1 parameter
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi

					# Error if no parameter left
					if [ "${#parameters[@]}" -lt 2 ]; then
						printf -- \
							'Error: %s requires 2 argument.\n' \
							--remove-xpath \
							1>&2
						return 1
					fi

					# Assign argument and leave the parameter to be shifted at the end-of-loop
					xml_file="${parameters[0]}"
					xpath="${parameters[1]}"

					# shift 1 parameter
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi
					;;
				--transform-file)
					mode=transform-file
					(( count_mode_specified += 1 ))

					# shift 1 parameter
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi

					# Error if no parameter left
					if [ "${#parameters[@]}" -lt 2 ]; then
						printf -- \
							'Error: %s requires 2 argument.\n' \
							--transform-file \
							1>&2
						return 1
					fi

					xsl_file="${parameters[0]}"
					xml_file="${parameters[1]}"

					# shift 1 parameter
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi
					;;
				*)
					printf 'Error: Unknown command-line argument "%s"\n' "${parameters[0]}" >&2
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

	if [ "${count_mode_specified}" -gt 1 ]; then
		printf -- \
			'%s: Error: Only one subcommand may be specified at a time.\n' \
			"${FUNCNAME[0]}" \
			1>&2
		return 1
	fi

	if [ "${enable_debug}" = Y ]; then
		trap '_xml_bash_trap_return "${FUNCNAME[0]}"' RETURN
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
## GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v3.3.0"
## You may rebase your script to incorporate new features and fixes from the template
