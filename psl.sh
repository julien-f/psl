##
# Portable Shell Library v0.2.1
#
# Julien Fontanet <julien.fontanet@isonoe.net>
#
# 2011-07-21 - v0.2.1
# - New function: “psl_substr()”.
# - Minor fixes.
# 2011-07-20 - v0.2
# - Big rewrite, new  philosophy: if a function takes or  returns a single value
#   and if  it makes sense  for this function  to be chained with  others, these
#   values will go through the “$psl”  variable. It should be more efficient and
#   lead to clearer codes.
# - Four  new  functions:  “psl_ltrim()”,  “psl_rtrim()”,  “psl_basename()”  and
#   “psl_dirname”.   The last  two should  be  more efficient  than calling  the
#   corresponding external programs.
#
# 2011-07-14 - v0.1.1
# - psl_write{,ln}() have been renamed to psl_print{,ln}().
# - New function: psl_first_match().
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
	# characters are in “$1” (especially  quotes) so the code may be ill-formed,
	# consequently we use a helper.
	psl_silence _psl_has_feature_helper "$1"
}


########################################
# Variable management
########################################

# Sets “$psl” to the value of a variable.
#
# This function allows you to get the  value of a variable which you do not know
# the name before execution.
#
# The behavior is undefined if “$VAR” is not a valid variable name.
#
# psl_get_value VAR
if psl_has_command nameref
then
	psl_get_value()
	{
		local _psl_get_value_ref

		nameref _psl_get_value_ref=$1

		psl=$_psl_get_value_ref
	}
elif psl_has_feature '${!VAR}'
then
	psl_get_value()
	{
		local _psl_get_value_ref

		# ksh does not support (even parsing!)  “${!1}” so to hide the error, we
		# use this variable.
		_psl_get_value_ref=$2

		psl=${!_psl_get_value_ref}
	}
else
	psl_get_value()
	{
		eval psl=\$$1
	}
fi

# Assigns the value of “$psl” to a variable.
#
# This function  allows you to assigns  a value to  a variable which you  do not
# know the name before execution (through another variable).
#
# The behavior is undefined if “$VAR” is not a valid variable name.
#
# psl_set_value VAR
if psl_has_command nameref
then
	psl_set_value()
	{
		local _psl_set_value_ref

		nameref _psl_set_value_ref=$1

		_psl_set_value_ref=$psl
	}
else
	psl_set_value()
	{
		eval $1='$psl'
	}
fi

# Saves in “$psl” the raw output, preserving any end-of-lines, of a command into
# a variable.
#
# psl_get_raw_output COMMAND [ARG...]
psl_get_raw_output()
{
	# We add a dummy character which will protect a possible end-of-line.
	psl=$("$@"; printf _)

	# Removes the dummy character.
	psl=${psl%_}
}


########################################
# Input/output
########################################

# Prints each arguments on the standard output.
#
# psl_print STRING...
psl_print()
{
	printf '%s' "$@"
}

# Prints each arguments followed by a new line on the standard output.
#
# psl_println STRING...
psl_println()
{
	printf '%s\n' "$@"
}

# Reads a line from the standard input (the end of line, if any, is discarded).
#
# psl_readln
psl_readln()
{
	IFS= read -r -- psl
}


########################################
# Debugging
########################################

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
			_PSL_LOG_LEVEL=$1
			;;
		*)
			_PSL_LOG_LEVEL=2
	esac
}

# Sets “$psl” to the current log level.
#
# See “psl_set_log_level()” for more information.
psl_get_log_level()
{
	psl=$_PSL_LOG_LEVEL
}

# Runs it a first time to ensure that “_PSL_LOG_LEVEL” has a correct value.
psl_set_log_level "$_PSL_LOG_LEVEL"

# Logs a message.
#
# This implementation is  deliberatly stupid, if you want  more advanced feature
# such as including the date or use syslog, feel free to overwrite this function
# with one of your own.
#
# _psl_log LEVEL MESSAGE...
_psl_log()
{
	shift
	psl_println "$@" >&2
}

# This should be used for programming purpose.
#
# psl_debug MESSAGE...
psl_debug()
{
	[ $_PSL_LOG_LEVEL -eq 3 ] && _psl_log Debug "$@"
}

# This should be used to inform the user of something.
#
# psl_notice MESSAGE...
psl_notice()
{
	[ $_PSL_LOG_LEVEL -gt 1 ] && _psl_log Notice "$@"
}

# This should be used to inform the user that something bad happened.
#
# psl_warning MESSAGE...
psl_warning()
{
	[ $_PSL_LOG_LEVEL -gt 0 ] && _psl_log Warning "$@"
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

# This helper  is used because  we really cannot  afford to change the  value of
# “$IFS” is the “local” command is not correctly supported.
_psl_join_helper()
{
	shift
	psl=$*
}

# Joins strings with a given character separator.
#
# psl_join SEP STRING...
psl_join()
{
	IFS=$1 _psl_join_helper "$@"
}

# Checks whether “$psl” matches a given pattern.
#
# psl_match PATTERN
psl_match()
{
	case "$psl" in
		$1)
			;;
		*)
			return 1
	esac
}

# Checks whether “$psl” matches a regular expression.
#
# psl_match_re REGEX
if psl_has_feature '$([[ word =~ . ]])'
then
	psl_match_re()
	{
		[[ "$psl" =~ $1 ]]
	}
elif psl_has_command grep
then
	psl_match_re()
	{
		psl_print "$psl" | grep --extended-regexp --quiet --regexp="$1"
	}
else
	psl_warning 'psl_match_re: failed pre-requisites'
fi

# Splits “$psl” by character(s).
#
# Warning:
#   Due to the implementation, the variables used cannot be “_psl_split_IFS”.
#
# psl_split DELIMITERS @FIELD...
psl_split()
{
	local _psl_split_IFS

	_psl_split_IFS="$1"
	shift

	IFS="$_psl_split_IFS" read -r -- "$@" <<EOF
$psl
EOF
}

# Returns the length of “$psl”.
#
# For multibytes encoding,  the result may either be the number  of bytes or the
# number of characters.
#
# Do not use this function to check if “$psl” is null, use the standard “test”
# command.
#
# psl_strlen
if psl_has_feature '${#VAR}'
then
	psl_strlen()
	{
		psl=${#psl}
	}
elif psl_has_command expr
then
	psl_strlen()
	{
		psl=$(expr length + "$psl")
	}
elif psl_has_command wc
then
	psl_strlen()
	{
		psl=$(psl_print "$psl" | wc -c)
	}
else
	psl_warning 'psl_strlen: failed pre-requisites'
fi

# Checks whether “$NEEDLE” is in “$psl”.
#
# psl_strstr NEEDLE
psl_strstr()
{
	# It  is  difficult  to  use  “psl_match()”  because  “NEEDLE”  may  contain
	# metacharacters.
	case "$psl" in
		*"$1"*)
			;;
		*)
			return 1
	esac
}

# Replaces “$SUBSTRING” by “$REPLACEMENT” in “$psl”.
#
# If the “-a” option is passed, replace every occurence.
#
# The “--” flag indicates the end of the options, i.e. it allows you to use “-a”
# as the substring to be replaced.
#
# subst [-a] [--] SUBSTRING REPLACEMENT
if psl_has_feature '${VAR/pattern/string}'
then
	psl_subst()
	{
		if [ "$1" = '-a' ]
		then
			[ "$1" = -- ] && shift
			psl=${psl//"$2"/$3}
		else
			[ "$1" = -- ] && shift
			psl=${psl/"$1"/$2}
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

		[ "$1" = -- ] && shift

		_psl_subst_suf=$psl

		_psl_subst_pref=${_psl_subst_suf%%"$1"*}

		# No match.
		[ "$_psl_subst_pref" = "$_psl_subst_suf" ] && return 1

		_psl_subst_suf=${_psl_subst_suf#*"$1"}
		_psl_subst_str=$_psl_subst_pref$2

		[ "$_psl_subst_all" ] && while {
			_psl_subst_pref=${_psl_subst_suf%%"$1"*}
			[ "$_psl_subst_pref" != "$_psl_subst_suf" ]
		}
		do
			_psl_subst_suf=${_psl_subst_suf#*"$1"}
			_psl_subst_str=$_psl_subst_str$_psl_subst_pref$2
		done

		psl=$_psl_subst_str$_psl_subst_suf
	}
fi

# Quotes a string to be used in the shell.
#
# psl_quote
psl_quote()
{
	psl_subst -a \' "'\\''"

	psl="'$psl'"
}

# Removes every substring at the begining of “$psl” which matches “$PATTERN”.
#
# psl_ltrim PATTERN
psl_ltrim()
{
	local _psl_ltrim_tmp

	while _psl_ltrim_tmp=${psl#$1}; [ "$_psl_ltrim_tmp" != "$psl" ]
	do
		psl=$_psl_ltrim_tmp
	done
}

# Removes every substring at the end of “$psl” which matches “$PATTERN”.
#
# psl_rtrim PATTERN
psl_rtrim()
{
	local _psl_rtrim_tmp

	while _psl_rtrim_tmp=${psl%$1}; [ "$_psl_rtrim_tmp" != "$psl" ]
	do
		psl=$_psl_rtrim_tmp
	done
}

# Extracts a substring from “$psl”.
#
# The position is counted from 0.
#
# psl_substr POS LENGTH
if psl_has_feature '${VAR:1:1}'
then
	psl_substr()
	{
		psl=${psl:$1:$2}
	}
elif psl_has_command expr
then
	psl_substr()
	{
		psl_get_raw_output expr substr + "$psl" \( "$1" + 1 \) "$2"
	}
else
	psl_warning 'psl_substr: failed pre-requisites'
fi


########################################
# Path manipulation
########################################

# Faster equivalent to the “basename” command.
#
# This function  does not manage the  suffix removal (because it  is trivial but
# costly if we do it unnecessarily).
#
# psl_basename
psl_basename()
{
	# Empty parameter → empty result.
	[ "$psl" ] || return

	# Remove all traling slashes.
	psl_rtrim /

	# If empty → there were only slashes.
	[ "$psl" ] || { psl=/; return; }

	# Removes the directory part.
	psl=${psl##*/}
}

# Faster equivalent to the “dirname” command.
#
# This function does not handle any options.
#
# psl_dirname
psl_dirname()
{
	local _psl_dirname_tmp

	# Empty special case.
	[ "$psl" ] || { psl=.; return; }

	_psl_dirname_tmp=$psl
	psl=${_psl_dirname_tmp%/*}

	psl_rtrim /

	# If no match → there were no directory.
	[ "$_psl_dirname_tmp" = "$psl" ] && { psl=.; return; }

	# If empty → this is the root.
	[ "$psl" ] || { psl=/; return; }
}


########################################
# Utilities
########################################

# Finds the first  entry for which the given command returns  0, if none entries
# match, simply returns 1.
#
# Note that the command  is run in the current shell and,  as a consequence, may
# have some side effects.
#
# Example:
#   psl_first_match 'test -f'
#
# psl_first_match COMMAND ENTRY...
psl_first_match()
{
	local _psl_first_match_command _psl_first_match_entry

	_psl_first_match_command=$1
	shift

	for _psl_first_match_entry
	do
		if eval $_psl_first_match_command '"$_psl_first_match_entry"'
		then
			psl=$_psl_first_match_entry
			return
		fi
	done

	return 1
}

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
		psl_print \
		psl_println \
		psl_readln \
		psl_set_log_level \
		psl_get_log_level \
		_psl_log \
		psl_debug \
		psl_notice \
		psl_warning \
		psl_fatal \
		_psl_join_helper \
		psl_join \
		psl_match \
		psl_match_re \
		psl_split \
		psl_strlen \
		psl_strstr \
		psl_subst \
		psl_quote \
		psl_ltrim \
		psl_rtrim \
		psl_substr \
		psl_basename \
		psl_dirname \
		psl_first_match \
		psl_unload

	unset -v \
		PSL_LOADED \
		_PSL_LOG_LEVEL \
		psl
}
