#!/bin/sh
#
# Updates top level dirs from their vendored versions
#
# Parameters:
#	[vendor-folder1 ... vendor-folderN]
#

set -e

if [ -z "$FOOT_PROTECTION_DISABLED_AND_I_KNOW_WHY" ] && git branch | grep -Eq '^\* master'; then
	echo "You are on master"
	echo "Are you probably do not want to create copies of the vendored directories on master"
	echo "IF YOU REALLY WANT TO DO THIS AND YOU KNOW EXACTLY WHAT WILL HAPPEN THEN RERUN THIS"
	echo "SCRIPT AS FOLLOWS:"
	echo "$ export FOOT_PROTECTION_DISABLED_AND_I_KNOW_WHY=true $0 $@"

	exit 1
fi


for i in ${@:-`ls vendor/`}; do
	unset diff_ignore_opt subfolder

	if echo "$i" | grep -Eq -- '-release'; then
		subfolder='releases/'
		diff_ignore_opt="-x version.txt"
		patch_level=2
	fi

	printf "Update: $i? (y/N) "
	read update

	[ x"$update" = x"Y" -o x"$update" = x"y" ] || continue

	printf "Git Update: $i? (y/N) "
	read git_update

	if [ x"$git_update" = x"Y" -o x"$git_update" = x"y" ]; then
		cd "vendor/$i"

		git pull

		cd - >/dev/null 2>&1
	fi

	if sh -c "diff -qNrudx .git -x \*.swp $diff_ignore_opt '$subfolder$i' 'vendor/$i'"; then
		echo "No differences"

		continue
	fi

	printf "View differences? (y/N) "
	read view_diff

	if [ x"$view_diff" = x"Y" -o x"$view_diff" = x"y" ]; then
		sh -qc "diff -Nrudx .git -x \*.swp $diff_ignore_opt '$subfolder$i' 'vendor/$i'" || :
	fi

	printf "Edit diff before applying? (y/N) "
	read edit_diff

	if [ x"$edit_diff" = x"Y" -o x"$edit_diff" = x"y" ]; then
		patch="`mktemp "$i.patch.XXXX"`"

		sh -c "diff -Nrudx .git -x \*.swp $diff_ignore_opt '$subfolder$i' 'vendor/$i'" >"$patch"

		vim "$patch"
	fi

	printf "Apply diff? (y/N) "
	read apply_diff

	[ x"$apply_diff" = x"Y" -o x"$apply_diff" = x"y" ] || continue

	if [ -n "$patch" -a -f "$patch" ]; then
		patch -p${patch_level:-1} -d "$subfolder$i" -i "$patch" && rm -f "$patch"
	else
		sh -c "diff -Nrudx .git -x \*.swp $diff_ignore_opt '$subfolder$i' 'vendor/$i'" | patch -p${patch_level:-1} -d "$subfolder$i"
	fi

	#
	if [ x"$subfolder" = x'releases/' ]; then
		[ -f "$subfolder$i/version.txt" ] && eval `awk -F\. '!/^#/{printf("major=%d minor=%d patch=%d new_minor=%d",$1,$2,$3,$2+1)}' "$subfolder$i/version.txt"`

		echo "${major:-0}.${new_minor:-1}.${patch:-0}" >"$subfolder$i/version.txt"
	fi
done

echo "Git status"
git status
