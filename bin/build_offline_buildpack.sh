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

mkdir -p buildpack

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
	bundle  install

	INFO 'Building Java buildpack'
	bundle exec rake clean package OFFLINE=true PINNED=true

else
	# We make the blind assumption we are building using the Go buildpack packager
	which go >/dev/null || FATAL 'Go is not installed, or is not in the $PATH'

	INFO 'Using Go buildpack packager'

	INFO 'Setting required Go variables'
	export GOPATH="$PWD"
	export GOBIN="$PWD/bin"

	mkdir -p "$GOBIN"

	if [ -d "src/$BUILDPACK_NAME/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager" ]; then
		# Some Go buildpacks have a vendored buildpack-packager
		PACKAGER_DIR="src/$BUILDPACK_NAME/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager"
		PACKAGER_TYPE='vendored'

		INFO 'Building vendored Go buildpack packager'

	elif [ -d src/libbuildpack ]; then
		# Some Go buildpacks rely on a pre-installed buildpack-packager
		PACKAGER_DIR='src/libbuildpack'
		TYPE='external'
	else
		FATAL 'No checkout or vendored version of libbuildpack'
	fi

	if [ x"$TYPE" = x'external' ]; then
		INFO 'Installing Go buildpack dependencies'
		go get ./...

		INFO 'Building Go buildpack packager'
	fi

	cd "$PACKAGER_DIR"

	go install

	cd - >/dev/null 2>&1

	INFO 'Fixing script permissions'
	find bin scripts -mindepth 1 -maxdepth 1 -name \*.sh -exec chmod +x "{}" \;

	if [ -n "$CUSTOM_BUILD_OPTIONS" ]; then
		WARN "Using custom buildpack-package optiopns: $@"
		"$GOBIN/buildpack-packager" --cached
	else
		"$GOBIN/buildpack-packager" build --cached
	fi
fi
