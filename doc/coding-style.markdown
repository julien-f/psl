# Coding style

This file describe the coding style used in the PSL.


## Naming convention

Every name should prefixed with “psl_” or “PSL_” (the last one for contants).

Apart from that, the names should be as short as possible while still being meaningful.

Try also to maintain a coherent style.


## Private functions/variables

A private function or variable should be prefixed with an underscore.


## Return values

The return value of a function shall only be used for signaling errors.

If you want to return values, assigns them to variables whose names are given by
the user as arguments.

Example:

	psl_strlen()
	{
		psl_set_value "$1" "${#2}"
	}

	psl_strlen term_length "$TERM"

There is no obligation whether the variable name should be the first or the last
argument,  use the  style  which feels  more  natural and  explicits  it in  the
documentation.
