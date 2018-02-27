#!/bin/sh
#
# Script to build the various buildpack types
#
#
# If we are building using the Go method, sometimes we have a vendor'd libbuildpack and other times we don't

set -e

BASE_DIR="`dirname \"$0\"`"

. "$BASE_DIR/common.sh"

# Buildpack methods:
#
# Go buildpack-packager
# Ruby buildpack-packager
# Java packager

BUILDPACK_NAME="$1"
BUILDPACK_DIR="$2"

[ -z "$BUILDPACK_NAME" ] && FATAL 'No buildpack name provided'
[ -z "$BUILDPACK_DIR" ] && FATAL 'No buildpack directory provided'
[ -d "$BUILDPACK_DIR" ] || FATAL "Buildpack directory does not exist: $BUILDPACK_DIR"

cd "$BUILDPACK_DIR"

INFO "Building $BUILDPACK_NAME offline/cached buildpack"
if [ -f cf.Gemfile ]; then
	# Ruby buildpack packager
	which ruby >/dev/null || FATAL 'Ruby is not installed, or is not in the $PATH'

	INFO 'Using Ruby buildpack packager'

	# CF uses a different Gemfile name
	INFO 'Ensuring all of the Ruby dependencies are installed'
	BUNDLE_GEMFILE=cf.Gemfile bundle

	INFO "Building $BUILDPACK_NAME"
	BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --cache


elif [ -f java-buildpack.iml ]; then
	# Java buildpack packager - as always Java people like to do things differently:
	which ruby >/dev/null || FATAL 'Ruby is not installed, or is not in the $PATH'

	INFO 'Ensuring all of the Ruby dependencies are installed'
	bundle install

	INFO 'Building Java buildpack'
	bundle exec rake clean package OFFLINE=true PINNED=true

else
	PACKAGER_DIR="src/$BUILDPACK_NAME/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager"

	if [ ! -d "$PACKAGER_DIR" ]; then
		# Previously some buildpacks used an external Go buildpack-packager, but they now all seem to use a vendored one
		FATAL 'No vendored version of libbuildpack'
	fi

	which go >/dev/null || FATAL 'Go is not installed, or is not in the $PATH'

	INFO 'Setting required Go variables'
	export GOPATH="$PWD"
	export GOBIN="$PWD/bin"

	mkdir -p "$GOBIN"

	cd "$PACKAGER_DIR"

	INFO 'Building vendored Go buildpack packager'
	go install

	cd - >/dev/null 2>&1

	INFO 'Fixing script permissions'
	find bin scripts -mindepth 1 -maxdepth 1 -name \*.sh -exec chmod +x "{}" \;

	INFO 'Using Go buildpack packager'
	if "$GOBIN/buildpack-packager" --help 2>&1 | grep -qE '^\s+-cached'; then
		WARN 'Buildpack is using older buildpack-packager'
		"$GOBIN/buildpack-packager" -cached
	else
		INFO 'Building offline/cached buildpack'
		"$GOBIN/buildpack-packager" build --cached
	fi
fi
