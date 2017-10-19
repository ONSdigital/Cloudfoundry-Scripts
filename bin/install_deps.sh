#!/bin/sh
#
#

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"


INSTALL_AWS="${1:-true}"

CF_GITHUB_RELEASE_URL="https://github.com/cloudfoundry/cli/releases/latest"
BOSH_GITHUB_RELEASE_URL="https://github.com/cloudfoundry/bosh-cli/releases/latest"

# Release types
BOSH_CLI_RELEASE_TYPE='linux-amd64'
CF_CLI_RELEASE_TYPE='linux64-binary'

# Only used if we don't have the awscli/azure-cli installed, don't have pip installed and are not running as root
GET_PIP_URL='https://bootstrap.pypa.io/get-pip.py'

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
[ -d "$BIN_DIR" ] || mkdir -p "$BIN_DIR"
[ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"

# If running via Jenkins we install cf-uaac via rbenv
if [ -z "$NO_UAAC" ] && ! which uaac >/dev/null 2>&1; then
	which gem >/dev/null 2>&1 || FATAL "No Ruby 'gem' command installed - do you need to run '$BASE_DIR/install_packages-EL.sh'? Or rbenv from within Jenkins?"
	gem install cf-uaac

	CHANGES=1
fi

# If running via Jenkins we can install awscli via pyenv
if [ -z "$NO_AWS" -a "$INSTALL_AWS" != x"false" ] && ! which aws >/dev/null 2>&1; then
	which pip${PIP_VERSION_SUFFIX:-3} >/dev/null 2>&1 || FATAL "No 'pip' command installed - do you need to run '$BASE_DIR/install_packages-EL.sh'? Or pyenv from within Jenkins?"

	pip${PIP_VERSION_SUFFIX:-3} install "awscli" --user

	[ -f ~/.local/bin/aws ] || FATAL "AWS cli failed to install"

	cd "$BIN_DIR"

	ln -s ~/.local/bin/aws

	cd -

	[ -n "$INSTALLED_EXTRAS" ] && INSTALLED_EXTRAS="$INSTALLED_EXTRAS,$BIN_DIR/aws" || INSTALLED_EXTRAS="$BIN_DIR/aws"

	CHANGES=1
fi

if [ ! -e "$BOSH_CLI-$BOSH_CLI_VERSION" ]; then
	INFO "Downloading Bosh $BOSH_CLI_VERSION"
	curl -SLo "$BOSH_CLI-$BOSH_CLI_VERSION" "$BOSH_CLI_URL"

	chmod +x "$BOSH_CLI-$BOSH_CLI_VERSION"
fi


if [ ! -f "$CF_CLI-$CF_CLI_VERSION" ]; then
	if [ ! -f "$TMP_DIR/$CF_CLI_ARCHIVE" ]; then
		INFO "Downloading CF $CF_CLI_VERSION"
		curl -SLo "$TMP_DIR/$CF_CLI_ARCHIVE" "$CF_CLI_URL"
	fi

	[ -f "$TMP_DIR/cf" ] && rm -f "$TMP_DIR/cf"

	INFO 'Extracting CF CLI'
	tar -zxf "$TMP_DIR/$CF_CLI_ARCHIVE" -C "$TMP_DIR" cf || FATAL "Unable to extract $TMP_DIR/$CF_CLI_ARCHIVE"

	mv "$TMP_DIR/cf" "$CF_CLI-$CF_CLI_VERSION"
fi

for i in BOSH CF; do
	eval file="\$$i"
	eval version="\$${i}_CLI_VERSION"

	file_name="`basename \"$file\"`"

	# Should never fail
	[ -z "$version" ] && FATAL "Unable to determine $i version"

	if [ -h "$file" -o -f "$file" ]; then
		diff -q "$file" "$file-$version" || rm -f "$file"
	fi

	if [ ! -h "$file" -a ! -f "$file" ]; then
		cd "$BIN_DIR"

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
