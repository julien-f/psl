##
# Portable Shell Library v0.2.11
#
# Julien Fontanet <julien.fontanet@isonoe.net>
#
# 2012-05-29 - v0.2.11
# - Properly works with “set -u”.
# 2012-05-29 - v0.2.10
# - Commands should not return false if it is not meaningful.
# 2012-05-29 - v0.2.9
# - New function “psl_which()” which locates a command.
# 2012-05-29 - v0.2.8
# - New function “psl_protect()” which prevents paths from being recognized as
#   options.
# - “psl_realpath()” works with files.
# - New function “psl()” which may ease the use of PSL for trivial operations.
# 2011-09-19 - v0.2.7
# - “psl_ord()” should now work correctly.
# 2011-09-18 - v0.2.6
# - Two new functions: “psl_fast_quote()” and “psl_split_all()”.
# - Minor correction in “psl_join()”.
# 2011-09-18 - v0.2.5
# - New   function   “psl_realpath()”    (currently   restricted   to   existing
#   directories).
# - “psl_unquote()” and “psl_ord()” are now correctly unloaded.
# 2011-08-01 - v0.2.4
# - Two new functions: “psl_unquote()” and “psl_ord()”.
# 2011-07-22 - v0.2.3
# - “psl_first_match()”  has been  replaced by  “psl_foreach()” which  is  a bit
#   trickier to use (at least for the same things) but much more powerful.
# - “$psl_local” is now read-only.
# - A bug has been fixed in the Bash implementation of “psl_get_value()”.
# 2011-07-22 - v0.2.2
# - Better handling of local variables with the “psl_local” variable.
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
[ "$PSL_LOADED" ] && return
PSL_LOADED=1

# Generic helper.
#
# psl [-v VALUE] [-p] FUNC [ARGUMENT]…
psl()
{
	$psl_local psl func print

	while :
	do
		case "$1" in
			-v)
				psl=$2
				shift;;
			-p)
				print=1;;
			*)
				break
		esac
		shift
	done

	func=psl_$1
	shift

	$func "$@" || return

	[ "${print:-}" ] && psl_print "$psl"

	# Prevents from returning false.
	:
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
	IFS= read -r psl
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
# This implementation is deliberately stupid,  if you want more advanced feature
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

	# Prevents from returning false.
	:
}

# This should be used to inform the user of something.
#
# psl_notice MESSAGE...
psl_notice()
{
	[ $_PSL_LOG_LEVEL -gt 1 ] && _psl_log Notice "$@"

	# Prevents from returning false.
	:
}

# This should be used to inform the user that something bad happened.
#
# psl_warning MESSAGE...
psl_warning()
{
	[ $_PSL_LOG_LEVEL -gt 0 ] && _psl_log Warning "$@"

	# Prevents from returning false.
	:
}

# This should be used to inform the user that something fatal happened.
# This function stops the script.
#
# psl_fatal MESSAGE...
psl_fatal()
{
	_psl_log Fatal "$@"
	exit 1
}


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
	(eval "_psl_has_feature=$1")
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
# Compatibility
########################################

# We  cannot  directly use  the  “local” command  because  it  is not  uniformly
# used. Instead we  use the variable “$psl_local” to  store the more appropriate
# command.
if ! [ "${psl_local:-}" ]
then
	if psl_has_command declare
	then
		psl_local=declare
	elif psl_has_command local
	then
		psl_local=local
	elif psl_has_command typeset
	then
		psl_local=typeset
	else
		psl_local=:
		psl_warning 'PSL does not support local variables for your shell, you may experience some problems.'
	fi
	readonly psl_local
fi


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
		$psl_local _psl_get_value_ref

		nameref _psl_get_value_ref=$1

		psl=$_psl_get_value_ref
	}
elif psl_has_feature '${!VAR}'
then
	psl_get_value()
	{
		$psl_local _psl_get_value_ref

		# ksh does not support (even parsing!)  “${!1}” so to hide the error, we
		# use this variable.
		_psl_get_value_ref=$1

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
		$psl_local _psl_set_value_ref

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
# String operations
########################################

# Joins strings with a given character separator.
#
# psl_join SEP STRING...
psl_join()
{
	$psl_local IFS

	IFS=$1
	shift

	psl=$*
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
	$psl_local _psl_split_IFS

	_psl_split_IFS="$1"
	shift

	IFS="$_psl_split_IFS" read -r "$@" <<EOF
$psl
EOF
}

# Prints  a  space-separated   list  of  quoted  fields  of   $psl  splitted  by
# character(s).
#
# The result of this function can be used to set positional parameters:
#
#     psl=$(getent passwd root)
#     eval "set -- $(psl_split_all :)"
#
# If DELIMITERS is not supplied, the default value of IFS will be used.
#
# psl_split_all [DELIMITERS]
psl_split_all()
{
	(
		[ $# -eq 1 ] && IFS=$1 || unset -v IFS
		set -f
		for psl in $psl
		do
			psl_fast_quote
			psl_print " $psl"
		done
	)
}

# Returns the length of “$psl”.
#
# For multibytes encoding,  the result may either be the number  of bytes or the
# number of characters.
#
# Do  not use  this  function  to check  if  “$psl” is  null,  use the  standard
# “[ "$psl" ]” instead.
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
# If the “-a” option is passed, replace every occurrence.
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
		$psl_local _psl_subst_all _psl_subst_str _psl_subst_pref _psl_subst_suf

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

# Quotes a string in a POSIX-compatible way.
#
# psl_quote
psl_quote()
{
	psl_subst -a \' "'\\''"

	psl="'$psl'"
}

# Quotes a string.
#
# Contrary to “psl_quote()” the result may not be usable in another shell.
#
# psl_fast_quote
if psl_has_feature '$(printf %q)'
then
	psl_fast_quote()
	{
		psl=$(printf %q "$psl")
	}
else
	psl_fast_quote()
	{
		psl_quote "$@"
	}
fi

# Unquotes a string.
#
# psl_unquote
psl_unquote()
{
	psl_get_raw_output printf %b "$psl"
}

# Removes every substring at the beginning of “$psl” which matches “$PATTERN”.
#
# psl_ltrim PATTERN
psl_ltrim()
{
	$psl_local _psl_ltrim_tmp

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
	$psl_local _psl_rtrim_tmp

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

# Returns the numeric value of the character in the given encoding.
#
# psl_ord
psl_ord()
{
	psl=$(printf %u \'"$psl")
}

########################################
# Path manipulation
########################################

# Faster equivalent to  the “basename” command (6/15 times  with Bash/Dash on my
# PC).
#
# This function  does not manage the  suffix removal (because it  is trivial but
# costly if we do it unnecessarily).
#
# psl=PATH; psl_basename; psl_println "$psl"
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

# Faster equivalent to  the “dirname” command (20/18 times  with Bash/Dash on my
# PC).
#
# This function does not handle any options.
#
# psl=PATH; psl_dirname; psl_println "$psl"
psl_dirname()
{
	$psl_local _psl_dirname_tmp

	# Empty special case.
	[ "$psl" ] || { psl=.; return; }

	psl_rtrim /

	_psl_dirname_tmp=$psl
	psl=${_psl_dirname_tmp%/*}

	# If no match → there were no directory.
	[ "$_psl_dirname_tmp" = "$psl" ] && { psl=.; return; }

	# If empty → this is the root.
	[ "$psl" ] || { psl=/; return; }
}

# Finds the real path of a file.
#
# The real path is an absolute path which contains neither “.” nor “..” nor
# symbolic links.
#
# psl=PATH; psl_realpath && psl_println "$psl"
psl_realpath()
{
	$psl_local old OLDPWD

	old=${PWD:+"$(pwd)"} || return 1

	psl_protect

	if psl_silence cd -P "$psl";
	then
		psl=$PWD
		cd "$old"
	else
		psl_get_raw_output perl -e 'use Cwd q(abs_path); print abs_path($ARGV[0])' -- "$psl"
	fi
}

# Prevents a path from being interpreted as an option.
#
# This is done by prepending the path with “./” if it starts with a dash.
#
# psl=PATH; psl_protect; psl_println "$psl"
psl_protect()
{
	[ "x$(printf '%c' "$psl")" = x- ] && psl=./$psl

	# Prevents from returning false.
	:
}

# Locates a command.
#
# If the path contains a slash, “$PATH” is ignored.
#
# psl=PATH; psl_which && psl_println "$psl"
psl_which()
{
	$psl_local dir

	# Contains a slash, do not look in $PATH.
	if psl_match '*/*'
	then
		[ -x "$psl" ]
		return
	fi

	eval "set -- $(psl=$PATH; psl_split_all :)"
	for dir
	do
		if [ -x "$dir/$psl" ]
		then
			psl=$dir/$psl
			return
		fi
	done

	return 1
}

########################################
# Utilities
########################################

# Evaluates a command for a list of entries.
#
# The evaluation  continues while the  command returns 0.  “psl_foreach” returns
# 0 if it  iterates until the end  of the list, otherwise it  returns the return
# value of the command which stopped it.
#
# When the command is evaluated, “$psl”  is positioned to the current entry.
#
# Examples:
#
#   # Selects the first entry which is a file.
#   psl_foreach '! test -f "$psl"' *
#
#   # Selects the first entry which ends with “.txt”.
#   psl_foreach '! psl_match "*.txt"' *
#
# psl_foreach COMMAND ENTRY...
psl_foreach()
{
	$psl_local _psl_foreach_command

	_psl_foreach_command=$1
	shift

	for psl
	do
		eval "$_psl_foreach_command" || return
	done
}

# Cleans the shell from almost all PSL's functions and variables.
#
# Local  variables may  not be  removed  if your  shell does  not support  local
# scopes.
#
# The “$psl_local” is not removed because it is marked read-only.
#
# psl_unload
psl_unload()
{
	unset -f \
		psl \
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
		psl_split_all \
		psl_strlen \
		psl_strstr \
		psl_subst \
		psl_quote \
		psl_fast_quote \
		psl_unquote \
		psl_ltrim \
		psl_rtrim \
		psl_substr \
		psl_ord \
		psl_basename \
		psl_dirname \
		psl_realpath \
		psl_protect \
		psl_which \
		psl_foreach \
		psl_unload

	unset -v \
		PSL_LOADED \
		_PSL_LOG_LEVEL \
		psl
}
