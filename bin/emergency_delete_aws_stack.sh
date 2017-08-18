#!/bin/sh
#
# Simple, stupid AWS stack deletion

STACK_PREFIX="$1"

AWS_PROFILE="${AWS_PROFILE:-default}"

if [ -n "$AWS" ]; then
	echo "Using $AWS cli"

elif which aws >/dev/null 2>1; then
	AWS='aws'
elif [ -x ~/.local/bin/aws ]; then
	AWS=~/.local/bin/aws
else
	echo Unable to find AWS CLI
	echo 'Set AWS to full filename, including path, of the AWS CLI, eg AWS=/opt/bin/aws'

	exit 1
fi

if [ -z "$STACK_PREFIX" ]; then
	echo No stack prefix provided

	exit 1
fi

for i in `$AWS --profile "$AWS_PROFILE" --output text --query "StackSummaries[?starts_with(StackName,'$STACK_PREFIX') && StackStatus != 'DELETE_COMPLETE'].StackName" cloudformation list-stacks |  sed -re 's/\t/\n/g' | sed -re '/n-[A-Z0-9]{12,13}$/d'`; do
	$AWS --profile "$AWS_PROFILE" cloudformation delete-stack --stack-name $i

	$AWS --profile "$AWS_PROFILE" cloudformation wait stack-delete-complete --stack-name $i
done
