##
# Portable Shell Library v0.1
#
# Julien Fontanet <julien.fontanet@isonoe.net>
##

##
# This file is part of the Portable Shell Library.
#
# The Portable  Shell Library is free  software: you can  redistribute it and/or
# modify it  under the terms of the  GNU General Public License  as published by
# the Free  Software Foundation, either  version 3 of  the License, or  (at your
# option) any later version.
#
# The Portable Shell Library is distributed  in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR  A PARTICULAR PURPOSE.  See the GNU  General Public License for
# more details.
#
# You should have  received a copy of the GNU General  Public License along with
# the Portable Shell Library.  If not, see <http://www.gnu.org/licenses/>.
##

########################################
# Include guard
########################################

# Prevents  PSL from  being parsed  and loaded  more than  once  for performance
# concerns.
#
# If you really want to reload it, call “psl_unload()” before.
if [ "$PSL_LOADED" ]
then
	return
fi
PSL_LOADED=1


########################################
# Compatibility
########################################

# Some shells, such as ksh, does not support the “local” keyword.
#
# This definition does strictly nothing, it might hide some errors.
if ! type local > /dev/null 2>&1
then
	local()
	{
		:
	}
fi


########################################
# Core commands
########################################

# Runs  a command silently,  i.e.  redirects  its standard  and error  output to
# “/dev/null”.
#
# psl_silence COMMAND [ARG...]
psl_silence()
{
	"$@" 2> /dev/null >&2
}


########################################
# Features detection
########################################

# Checks whether the shell has a given command.
#
# psl_has_command COMMAND
psl_has_command()
{
	psl_silence type "$@"
}

# Helper function for “psl_has_feature()”.
_psl_has_feature_helper()
{
	(eval _psl_has_feature="$1")
}

# Checks whether the shell has a given features (variable substitutions, …).
#
# The code  passed must  be assignable to  a variable,  so you must  use command
# substitution if you want to test a command.
#
# psl_has_feature CODE
psl_has_feature()
{
	# We cannot use directly the “psl_silence()” function on the code because it
	# does not know how to run command in a subshell.
	#
	# We cannot either use “eval()” because we do not have any knowledge of what
	# characters  are in  “$1”  (especially quotes)  so  the code  may be  illed
	# formed, consequently we use an helper.
	psl_silence _psl_has_feature_helper "$1"
}


########################################
# Variable management
########################################

# Returns the value of a variable.
#
# This function allows you to get the  value of a variable which you do not know
# the name before execution.
#
# The behavior is undefined if VAR is not a valid variable name.
#
# psl_get_value @VALUE VAR
if psl_has_command nameref
then
	psl_get_value()
	{
		local _psl_get_value_ref

		nameref _psl_get_value_ref=$2

		psl_set_value $1 "$_psl_get_value_ref"
	}
elif psl_has_feature '${!VAR}'
then
	psl_get_value()
	{
		local _psl_get_value_ref

		# ksh does not support (even parsing!)  “${!1}” so to hide the error, we
		# use this variable.
		_psl_get_value_ref=$2

		set_value $1 "${!_psl_get_value_ref}"
	}
else
	psl_get_value()
	{
		eval $1='$'$2
	}
fi

# Assigns a value to a variable.
#
# This function  allows you to assigns  a value to  a variable which you  do not
# know the name before execution (through another variable).
#
# The behavior is undefined if VAR is not a valid variable name.
#
# psl_set_value VAR VALUE
if psl_has_command nameref
then
	psl_set_value()
	{
		local _psl_set_value_ref

		nameref _psl_set_value_ref="$1"

		_psl_set_value_ref="$2"
	}
else
	psl_set_value()
	{
		eval $1'=$2'
	}
fi

# Saves  the  raw  output,  preserving  any  end-of-lines,  of  a  command  into
# a variable.
#
# Warning:
#   Due    to    the   implementation,    the    variable    name   cannot    be
#   “_psl_get_raw_output_var” nor “_psl_get_raw_output_val”.
#
# psl_get_raw_output @OUTPUT COMMAND [ARG...]
psl_get_raw_output()
{
	local _psl_get_raw_output_var _psl_get_raw_output_val

	_psl_get_raw_output_var=$1
	shift

	# We add a dummy character which will protect a possible end-of-line.
	_psl_get_raw_output_val=$("$@"; printf _)

	# Removes the dummy character.
	psl_set_value "$_psl_get_raw_output_var" "${_psl_get_raw_output_val%_}"
}


########################################
# Input/output
########################################

# Writes each arguments on the standard output.
#
# psl_write STRING...
psl_write()
{
	printf '%s' "$@"
}

# Writes each arguments followed by a new line on the standard output.
#
# psl_writeln STRING...
psl_writeln()
{
	printf '%s\n' "$@"
}

# Read a line from the standard input (the end of line, if any, is discarded).
#
# psl_readln @LINE
psl_readln()
{
	IFS= read -r -- $1
}


########################################
# Debugging
########################################

# The “PSL_LOG_LEVEL”  variable is  used to determine  which messages  should be
# logged.

# Changes the log level.
#
# The following values are possible:
# - 0: Fatal
# - 1: Fatal + Warning
# - 2: Fatal + Warning + Notice (default)
# - 3: Fatal + Warning + Notice + Debug
#
# If another value is passed, the default level is selected.
#
# psl_set_log_level LEVEL
psl_set_log_level()
{
	case "$1" in
		[0-3])
			PSL_LOG_LEVEL=$1
			;;
		*)
			PSL_LOG_LEVEL=2
	esac
}

# Runs it a first time to ensure that “PSL_LOG_LEVEL” has a correct value.
psl_set_log_level "$PSL_LOG_LEVEL"

# Logs a message.
#
# This implementation is  deliberatly stupid, if you want  more advanced feature
# such as including the date or use syslog, feel free to overwrite this function
# with one of your own.
#
# _psl_log LEVEL MESSAGE...
_psl_log()
{
	psl_writeln "$@" >&2
}

# This should be used for programming purpose.
#
# psl_debug MESSAGE...
psl_debug()
{
	[ $PSL_LOG_LEVEL -eq 3 ] && _psl_log Debug "$@"
}

# This should be used to inform the user of something.
#
# psl_notice MESSAGE...
psl_notice()
{
	[ $PSL_LOG_LEVEL -gt 1 ] && _psl_log Notice "$@"
}

# This should be used to inform the user that something bad happened.
#
# psl_warning MESSAGE...
psl_warning()
{
	[ $PSL_LOG_LEVEL -gt 0 ] && _psl_log Warning "$@"
}

# This should be used to inform the user thats something fatal happened.
# This function stops the script.
#
# psl_fatal MESSAGE...
psl_fatal()
{
	_psl_log Fatal "$@"
	exit 1
}


########################################
# String operations
########################################

# Joins strings with a given character separator.
#
# psl_join @RESULT SEP STRING...
psl_join()
{
	local _psl_join_var

	_psl_join_var=$1
	IFS=$2
	shift 2

	psl_set_value $_psl_join_var "$*"
}

# Checks whether a string matches a given pattern.
#
# psl_match PATTERN STRING
psl_match()
{
	case "$2" in
		$1)
			;;
		*)
			return 1
	esac
}

# Checks whether a string matches a regular expression.
#
# psl_match_re REGEX STRING
if psl_has_feature '$([[ word =~ . ]])'
then
	psl_match_re()
	{
		[[ "$2" =~ $1 ]]
	}
elif psl_has_command grep
then
	psl_match_re()
	{
		printf '%s' "$1" | grep --extended-regexp --quiet --regexp="$1"
	}
else
	psl_warning 'psl_match_re: failed pre-requisites'
fi

# Splits a string by character(s).
#
# Warning:
#   Due to the implementation, the variables used cannot be “_psl_split_IFS” nor
#   “_psl_split_string”.
#
# psl_split STRING DELIMITERS @FIELD...
psl_split()
{
	local _psl_split_IFS _psl_split_string

	_psl_split_string="$1"
	_psl_split_IFS="$2"
	shift 2

	IFS="$_psl_split_IFS" read -r -- "$@" <<EOF
$_psl_split_string
EOF
}

# Returns the length of the string.
#
# For multibytes encoded  strings, the result may either be  the number of bytes
# or the number of characters.
#
# Do not use this function to check if a string is null, use the standard “test”
# command.
#
# psl_strlen @LENGTH STRING
if psl_has_feature '${#VAR}'
then
	psl_strlen()
	{
		psl_set_value $1 ${#2}
	}
elif psl_has_command expr
then
	psl_strlen()
	{
		psl_set_value $1 $(expr length "$1")
	}
elif psl_has_command wc
then
	psl_strlen()
	{
		psl_set_value $(printf '%s' "$1" | wc -c)
	}
else
	psl_warning 'psl_strlen: failed pre-requisites'
fi

# Checks whether the string “needle” is in the string “haystack”.
#
# psl_strstr HAYSTACK NEEDLE
psl_strstr()
{
	[ -z "$2" ] && return

	[ -n "$1" ] && [ -z "${1##*"$2"*}" ]
}

# Replaces the substring SUBSTRING in string by REPLACEMENT.
#
# If the “-a” option is passed, replace every occurence.
#
# subst [ -a ] @RESULT STRING SUBSTRING REPLACEMENT
if psl_has_feature '${VAR/pattern/string}'
then
	psl_subst()
	{
		if [ "$1" = '-a' ]
		then
			shift
			psl_set_value $1 "${2//"$3"/$4}"
		else
			psl_set_value $1 "${2/"$3"/$4}"
		fi
	}
else
	psl_subst()
	{
		local _psl_subst_all _psl_subst_str _psl_subst_pref _psl_subst_suf

		[ "$1" = '-a' ] && {
			_psl_subst_all=1
			shift
		}

		_psl_subst_suf="$2"

		_psl_subst_pref="${_psl_subst_suf%%"$3"*}"
		[ "$_psl_subst_pref" = "$_psl_subst_suf" ] && {
			# No match
			psl_set_value $1 "$_psl_subst_suf"
			return 1
		}

		_psl_subst_suf="${_psl_subst_suf#*"$3"}"
		_psl_subst_str="$_psl_subst_pref$4"

		[ "$_psl_subst_all" ] && while {
			_psl_subst_pref="${_psl_subst_suf%%"$3"*}"
			[ "$_psl_subst_pref" != "$_psl_subst_suf" ]
		}
		do
			_psl_subst_suf="${_psl_subst_suf#*"$3"}"
			_psl_subst_str="$_psl_subst_str$_psl_subst_pref$4"
		done

		psl_set_value $1 "$_psl_subst_str$_psl_subst_suf"
	}
fi


########################################
# Utilities
########################################

psl_unload()
{
	unset -f \
		psl_silence \
		psl_has_command \
		_psl_has_feature_helper \
		psl_has_feature \
		psl_get_value \
		psl_set_value \
		psl_get_raw_output \
		psl_write \
		psl_writeln \
		psl_readln \
		psl_set_log_level \
		_psl_log \
		psl_debug \
		psl_notice \
		psl_warning \
		psl_fatal \
		psl_join \
		psl_match \
		psl_match_re \
		psl_split \
		psl_strlen \
		psl_strstr \
		psl_subst \
		psl_unload

	unset -v \
		PSL_LOADED \
		PSL_LOG_LEVEL
}
