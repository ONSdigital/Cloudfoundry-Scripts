#!/bin/sh
#
#
# Installs dependencies that can be installed as user
#
# Parameters:
#	[Install AWS]
#	[Discover Versions]
#
# Variables:
#	[NO_UAAC]
#	[RUBY_VERSION]
#	[PYTHON_VERSION_SUFFIX]
#	[BOSH_CLI_VERSION]
#	[CF_CLI_VERSION]
#	[BOSH_CLI_URL]
#	[CF_CLI_URL]
#	[CF_CLI_ARCHIVE]
#	[NO_AWS]
#	INSTALL_AWS=[true|false]
#
# Requires:
#	common.sh
#
set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"


INSTALL_AWS="${1:-true}"
DISCOVER_VERSIONS="${2:-true}"

CF_GITHUB_RELEASE_URL="https://github.com/cloudfoundry/cli/releases/latest"
BOSH_GITHUB_RELEASE_URL="https://github.com/cloudfoundry/bosh-cli/releases/latest"

# Release types
BOSH_CLI_RELEASE_TYPE='linux-amd64'
CF_CLI_RELEASE_TYPE='linux64-binary'

RUBY_VERSION="${RUBY_VERSION:-2.1}"
PYTHON_VERSION_SUFFIX="${PYTHON_VERSION_SUFFIX:-3}"

if [ x"$DISCOVER_VERSIONS" = x'true' ]; then
	INFO 'Determining Bosh & CF versions'
	for i in BOSH CF; do
		eval version="\$${i}_CLI_VERSION"
		eval github_url="\$${i}_GITHUB_RELEASE_URL"

		# Only discover the version if we haven't been given one
		if [ -z "$version" ]; then
			# Strip HTTP \r and \n for completeness
			version="`curl -SsI \"$github_url\" | awk -F/ '/Location/{gsub(/(^v|\r|\n)/,\"\",$NF); print $NF}'`"

			[ -z "$version" ] && FATAL "Unable to determine $i CLI version from '$github_url'"

			INFO "Setting $i version as $version"
			eval "${i}_CLI_VERSION"="$version"
		fi

		unset github_url version
	done
else
	[ -z "$BOSH_CLI_VERSION" ] && FATAL '$BOSH_CLI_VERSION has not been set'
	[ -z "$CF_CLI_VERSION" ] && FATAL '$CF_CLI_VERSION has not been set'
fi

# Set URLs
BOSH_CLI_URL="${BOSH_CLI_URL:-https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-$BOSH_CLI_VERSION-$BOSH_CLI_RELEASE_TYPE}"
CF_CLI_URL="${CF_CLI_URL:-https://cli.run.pivotal.io/stable?release=$CF_CLI_RELEASE_TYPE&version=$CF_CLI_VERSION&source=github}"
CF_CLI_ARCHIVE="${CF_CLI_ARCHIVE:-cf-$CF_CLI_VERSION-$CF_CLI_RELEASE_TYPE.tar.gz}"

# Create dirs
[ -d "$BIN_DIR" ] || mkdir -p "$BIN_DIR"
[ -d "$TMP_DIR" ] || mkdir -p "$TMP_DIR"

# If running via Jenkins we install cf-uaac via rbenv
if [ -z "$NO_UAAC" ] && ! which uaac >/dev/null 2>&1; then
	which ruby$RUBY_VERSION >/dev/null 2>&1 || FATAL "Ruby version $RUBY_VERSION is not installed"

	INFO 'Installing UAA client'
	which "gem$RUBY_VERSION" >/dev/null 2>&1 || FATAL "No Ruby 'gem' command installed - do you need to run '$BASE_DIR/install_packages-EL.sh'? Or rbenv from within Jenkins?"
	"gem$RUBY_VERSION" install cf-uaac

	CHANGES=1
fi

# If running via Jenkins we can install awscli via pyenv
if [ -z "$NO_AWS" -a "$INSTALL_AWS" != x"false" ] && ! which aws >/dev/null 2>&1; then
	INFO 'Installing AWS CLI'
	which pip$PYTHON_VERSION_SUFFIX >/dev/null 2>&1 || FATAL "No 'pip' command installed - do you need to run '$BASE_DIR/install_packages-EL.sh'? Or pyenv from within Jenkins?"

	pip$PYTHON_VERSION_SUFFIX install "awscli" --user

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

INFO 'Creating Bosh & CF CLI links'
for i in BOSH_CLI CF_CLI; do
	eval file="\$$i"
	eval version="\$${i}_VERSION"

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
	$BOSH_CLI-$BOSH_CLI_VERSION
	$CF_CLI-$CF_CLI_VERSION
EOF

OLDIFS="$IFS"
IFS=","
for i in $INSTALLED_EXTRAS; do
	echo "	$i"
done
IFS="$OLDIFS"
[ -z "$CHANGES" ] || echo 'Changes made'
