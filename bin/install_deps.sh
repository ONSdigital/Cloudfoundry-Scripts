#!/bin/sh
#
# 

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

# Versions:
# https://bosh.io/docs/cli-v2.html or https://github.com/cloudfoundry/bosh-cli
CLOUD_TYPES="$@"

CF_GITHUB_RELEASE_URL="https://github.com/cloudfoundry/cli/releases/latest"
BOSH_GITHUB_RELEASE_URL="https://github.com/cloudfoundry/bosh-cli/releases/latest"

# Release types
BOSH_CLI_RELEASE_TYPE='linux-amd64'
CF_CLI_RELEASE_TYPE='linux64-binary'

# Only used if we don't have the awscli/azure-cli installed, don't have pip installed and are not running as root
GET_PIP_URL='https://bootstrap.pypa.io/get-pip.py'

for i in $CLOUD_TYPES; do
	case "$i" in
		aws*)
			if ! which aws >/dev/null 2>&1 && [ ! -f "$BIN_DIRECTORY/aws" ]; then
				[ -n "$CLIS" ] && CLIS="$CLIS aws" || CLIS='aws'
				[ -n "$PIPS" ] && PIPS="$PIPS awscli" || PIPS='awscli'
			fi
			;;
		azure*)
			if ! which az >/dev/null 2>&1 || [ ! -f "$BIN_DIRECTORY/az" ]; then
				[ -n "$CLIS" ] && CLIS="$CLIS az" || CLIS='az'
				[ -n "$PIPS" ] && PIPS="$PIPS azure-cli" || PIPS='azure-cli'

				# Python-2.x doesn't seem to work with Azure CLI
				#
				# Collecting azure-datalake-store==0.0.8 (from azure-cli-dls->azure-cli)
				# Using cached azure-datalake-store-0.0.8.tar.gz
				# Complete output from command python setup.py egg_info:
				# Wheel is not available, disabling bdist_wheel hook
				# error in azure-datalake-store setup command: Invalid environment marker: python_version<'3.4'
				PIP_VERSION_SUFFIX='3.4'

				# Even when Python3.4 is installed, the python version in the script is just called 'python'. On
				# RHEL we need to fix this...
				AZ_INSTALL=1
			fi
			;;
		*)
			FATAL "Unknown cloud type: '$i'"
			;;
	esac
done

for i in BOSH CF; do
	eval version="\$${i}_CLI_VERSION"
	eval github_url="\$${i}_GITHUB_RELEASE_URL"

	# Only discover the version if we haven't been given one
	if [ -z "$version" ]; then
		# Strip HTTP \r and \n for completeness
		version="`curl -SsI \"$github_url\" | awk -F/ '/Location/{gsub(/(^v|\r|\n)/,\"\",$NF); print $NF}'`"

		[ -z "$version" ] && FATAL "Unable to determine $i CLI version from '$github_url'"

		eval "${i}_CLI_VERSION"="$version"
	fi

	unset github_url version
done

# Set URLs
BOSH_CLI_URL="https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-$BOSH_CLI_VERSION-$BOSH_CLI_RELEASE_TYPE"
CF_CLI_URL="https://cli.run.pivotal.io/stable?release=$CF_CLI_RELEASE_TYPE&version=$CF_CLI_VERSION&source=github"
CF_CLI_ARCHIVE="cf-$CF_CLI_VERSION-$CF_CLI_RELEASE_TYPE.tar.gz"

if [ x"$USER" != x"root" ]; then
	# We are not root
	# Can we run sudo?
	if ! sudo -Sn whoami </dev/null >/dev/null 2>&1; then
		# We cannot sudo without a password
		NO_SUDO=1
	fi
fi

# Create dirs
[ -d "$BIN_DIRECTORY" ] || mkdir -p "$BIN_DIRECTORY"
[ -d "$TMP_DIRECTORY" ] || mkdir -p "$TMP_DIRECTORY"

# If running via Jenkins we install cf-uaac via rbenv
if [ -z "$NO_UAAC" ] && ! which uaac >/dev/null 2>&1; then
	which gem >/dev/null 2>&1 || FATAL "No Ruby 'gem' command installed - do you need to run '$BASE_DIR/install_packages-EL.sh'?  Or rbenv from within Jenkins?" 
	gem install cf-uaac

	CHANGES=1
fi

# If running via Jenkins we can install awscli/azure-cli via pyenv
if [ -n "$PIPS" ]; then
	which pip$PIP_VERSION_SUFFIX >/dev/null 2>&1 || FATAL "No 'pip' command installed - do you need to run '$BASE_DIR/install_packages-EL.sh'?  Or pyenv from within Jenkins?"

	for i in $PIPS; do
		pip$PIP_VERSION_SUFFIX  install "$i" --user
	done

	for i in $CLIS; do
		[ -f ~/.local/bin/"$i" ] || FATAL "$i cli failed to install"

		cd "$BIN_DIRECTORY"

		ln -s ~/.local/bin/"$i"

		cd -

		[ -n "$INSTALLED_EXTRAS" ] && INSTALLED_EXTRAS="$INSTALLED_EXTRAS,$BIN_DIRECTORY/$i" || INSTALLED_EXTRAS="$BIN_DIRECTORY/$i"
	done

	if [ -n "$AZ_INSTALL" ]; then
		# Check the 'az' binary works, it may call python which may not be python-3.4, depending on the OS/environment
		~/.local/bin/az || sed -i -re "s/(python) (-m azure.cli)/\1$PIP_VERSION_SUFFIX \2/g" ~/.local.bin/az
	fi

	CHANGES=1
fi

if [ ! -e "$BOSH-$BOSH_CLI_VERSION" ]; then
	INFO "Downloading Bosh $BOSH_CLI_VERSION"
	curl -SLo "$BOSH-$BOSH_CLI_VERSION" "$BOSH_CLI_URL"

	chmod +x "$BOSH-$BOSH_CLI_VERSION"
fi


if [ ! -f "$CF-$CF_CLI_VERSION" ]; then
	if [ ! -f "$TMP_DIRECTORY/$CF_CLI_ARCHIVE" ]; then
		INFO "Downloading CF $CF_CLI_VERSION"
		curl -SLo "$TMP_DIRECTORY/$CF_CLI_ARCHIVE" "$CF_CLI_URL"
	fi

	[ -f "$TMP_DIRECTORY/cf" ] && rm -f "$TMP_DIRECTORY/cf"

	INFO 'Extracting CF CLI'
	tar -zxf "$TMP_DIRECTORY/$CF_CLI_ARCHIVE" -C "$TMP_DIRECTORY" cf || FATAL "Unable to extract $TMP_DIRECTORY/$CF_CLI_ARCHIVE"

	mv "$TMP_DIRECTORY/cf" "$CF-$CF_CLI_VERSION"
fi

for i in BOSH CF; do
	eval file="\$$i"
	eval version="\$${i}_CLI_VERSION"
	
	file_name="`basename \"$file\"`"

	# Should never fail
	[ -z "$version" ] && FATAL "Unable to determine $i version"

	if [ -h "$file" -o -f "$file" ]; then
		diff "$file" "$file-$version" || rm -f "$file"
	fi

	if [ ! -h "$file" -a ! -f "$file" ]; then
		cd "$BIN_DIRECTORY"

		ln -s "$file_name-$version" "$file_name"

		CHANGES=1
	fi

	unset file file_name version
done

cat <<EOF
Initial setup complete:
	$BOSH
	$CF
EOF

OLDIFS="$IFS"
IFS=","
for i in $INSTALLED_EXTRAS; do
	echo "	$i"
done
IFS="$OLDIFS"
[ -z "$CHANGES" ] || echo 'Changes made'
