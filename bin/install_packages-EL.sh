#!/bin/sh
#
# Installs packages on a Redhat/RPM based system
#
# https://bosh.io/docs/cli-v2.html

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

# Computed values
REDHAT_VERSION="`rpm --eval %rhel`"

# Downloads
EPEL_RELEASE_RPM_NAME="epel-release-latest-$REDHAT_VERSION.noarch.rpm"
EPEL_RELEASE_RPM_FILE="$TMP_DIR/$EPEL_RELEASE_RPM_NAME"

WARN 'This script no longer works with Redhat/CentOS 7. This is due to requiring a Ruby version greater than 2.0'

install_packages(){
	[ -z "$1" ] && return 0

	for _i in $@; do
		if ! rpm --quiet -q "$_i"; then
			if [ -z "$YUM_CLEAN" -o x"$YUM_CLEAN" = x"yes" ]; then
				INFO Cleaning existing Yum cache
				$SUDO yum --quiet clean all && YUM_CLEAN=1
			fi

			INFO "Installing $_i"
			$SUDO yum --quiet install -y "$_i" || :
		else
			INFO "$_i already installed"
		fi
	done
}

# We need to do somethings as root
[ x"$USER" = x"root" ] || SUDO='sudo'

# EPEL repo is required for python2-pip and others
# If we are on RHEL we need to enable the optional RPM repo to pull in devel packages
if [ -f /etc/redhat-release ] && grep -qE '^Red Hat Enterprise Linux Server' /etc/redhat-release; then
	INFO Enabling Redhat optional repository
	if $SUDO subscription-manager repos | awk '{if(/^Repo ID:.*rhel-'$REDHAT_VERSION'-server-optional-rpms/){ repo=1 } else if(/^Repo ID:/){ repo=0 }; if(repo && /^Enabled:/){ if($2 == 0) exit 0; if($2 == 1) exit 1}}'; then
		$SUDO subscription-manager repos --enable "rhel-$REDHAT_VERSION-server-optional-rpms"
	fi

	if ! rpm --quiet -q epel-release; then
		if [ ! -f "$EPEL_RELEASE" ]; then
			INFO Downloading EPEL repository config
			curl -SLo "$EPEL_RELEASE_RPM_FILE" "https://dl.fedoraproject.org/pub/epel/$EPEL_RELEASE_RPM_NAME"
		fi

		INFO Installing EPEL repository
		$SUDO yum --quiet install -y "$EPEL_RELEASE_RPM_FILE"
	fi

	REAL_RHEL=1
elif uname -r | grep amzn; then
	INFO Running on Amazon, not install EPEL repo
else
	install_packages epel-release
fi

# Clean again now we, potentially, have a new repo
YUM_CLEAN=yes

# Install packages for bosh
install_packages gcc gcc-c++ make patch openssl openssl-devel ruby ruby-devel zlib-devel

# To build Java buildpacks
install_packages rubygem-bundler

# Required for AWS
install_packages python python-setuptools python-pip python-devel libyaml-devel bzip2 readline-devel

# Required to install Bosh S3 CLI
install_packages golang
