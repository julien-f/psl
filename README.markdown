# Portable Shell Library

## Introduction

PSL is the successor of my personal  shell library named jfsh, but it intends to
be used much more widely and to be cleaner and better documented.

The primary goal of  PSL is to offer tools to program  easily and securely shell
scripts,  as  its  name  indicates,   portable  across  as  much  sh-like  shell
interpreters as possible.

The secondary  goal of PSL is to  be efficient by using,  when possible, builtin
features over external programs.


## Compatibility

PSL has been tested with Bash, dash, Ksh and zsh.


## Usage

### Loading

To use PSL's facilities,  all you have to do is to  source the “psl.sh” file, if
it is in the “PATH” you can simply do `. psl.sh`.

For  performance  concerns,  “psl.sh”  prevents  himself from  be  being  loaded
multiple times,  but if you really want  to reload PSL, simply  unload it before
(see the next section).

### Unloading

If you don't  want to use PSL anymore  in your script and you want  to clean the
environment from all PSL's objects, you may use the “psl_unload()” function.
