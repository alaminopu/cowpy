#!/bin/sh
# Publish the current version: build the disk image, create the GitHub release
# and point the Homebrew cask at it.
#
#   scripts/release.sh
#
# The version comes from MARKETING_VERSION in the Xcode project; bump it there
# first. Afterwards commit and push Casks/cowpy.rb, which is what makes
# `brew upgrade` see the new version.
set -eu
cd "$(dirname "$0")/.."

version=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' Cowpy.xcodeproj/project.pbxproj | head -1)
tag="v$version"
dmg="dist/Cowpy-$version.dmg"

if [ -n "$(git status --porcelain)" ]; then
    echo "Commit or stash your changes first, so the release matches a commit." >&2
    exit 1
fi
if gh release view "$tag" >/dev/null 2>&1; then
    echo "Release $tag already exists. Bump MARKETING_VERSION first." >&2
    exit 1
fi

scripts/make-dmg.sh
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)

git push
gh release create "$tag" "$dmg" --title "Cowpy $version" --generate-notes --target "$(git rev-parse HEAD)"

sed -i '' -e "s/^  version \".*\"/  version \"$version\"/" -e "s/^  sha256 \".*\"/  sha256 \"$sha\"/" Casks/cowpy.rb
echo
echo "Released $tag. Now publish the cask:"
echo "  git commit -am 'Cask: Cowpy $version' && git push"
