#!/bin/sh
#
# Simple, stupid AWS stack deletion

STACK_PREFIX="$1"

if [ -n "$AWS" ]; then
	echo "Using $AWS cli"

elif which aws >/dev/null 2>1; then
	AWS='aws'

elif [ -x ~/.local/bin/aws ]; then
	AWS=~/.local/bin/aws

elif [ -z "$AWS" -o ! -x "$AWS" ]; then
	echo Unable to find AWS CLI
	echo 'Set AWS to full filename, including path, of the AWS CLI, eg AWS=/opt/bin/aws'

	exit 1
fi

if [ -z "$STACK_PREFIX" ]; then
	echo No stack prefix provided

	exit 1
fi

for i in `$AWS --output text --query "StackSummaries[?starts_with(StackName,'$STACK_PREFIX') && StackStatus != 'DELETE_COMPLETE'].StackName" cloudformation list-stacks | sed -re 's/\t/\n/g' | sed -re '/n-[A-Z0-9]{12,13}$/d'`; do
	$AWS cloudformation delete-stack --stack-name $i

	$AWS cloudformation wait stack-delete-complete --stack-name $i
done
