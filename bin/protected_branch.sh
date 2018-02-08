#!/bin/sh
#
# Checks for a file named protection_state to determine if the current branch is protected
#

if [ ! -d .git -o ! -f .git/config ]; then
	echo Not a Git repository

	exit 1
fi

if [ -f protection_state ] && grep -q 'protected' protection_state; then
	echo Protected branch
	echo Protection state:
	cat protection_state

	echo
	echo Refusing to make any changes, please remove \"protection_state\" to allow changes
	exit 1
fi


echo No branch protection exists
