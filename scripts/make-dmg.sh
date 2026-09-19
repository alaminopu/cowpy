#!/bin/sh
# Package Cowpy as a drag-to-install disk image in dist/.
#
#   scripts/make-dmg.sh
#
# Signing, in order of preference:
#   1. A "Developer ID Application" certificate (paid Apple Developer Program).
#      If a notarytool keychain profile named "cowpy-notary" also exists, the
#      image is notarised and stapled, and opens on any Mac without warnings.
#      Create the profile once with:
#        xcrun notarytool store-credentials cowpy-notary --apple-id <id> --team-id <team>
#   2. Otherwise ad hoc. People who download it must right-click > Open (or use
#      System Settings > Privacy & Security > Open Anyway) the first time.
#
# The personal "Apple Development" certificate that scripts/install.sh uses is
# deliberately NOT used here: it does not satisfy Gatekeeper on other Macs, and
# it would embed your Apple ID email address in every copy you hand out.
set -eu
cd "$(dirname "$0")/.."

version=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' Cowpy.xcodeproj/project.pbxproj | head -1)
developer_id=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application[^"]*\)".*/\1/p' | head -1)

if [ -n "$developer_id" ]; then
    team=$(security find-certificate -c "$developer_id" -p \
        | openssl x509 -noout -subject -nameopt multiline \
        | sed -n 's/^ *organizationalUnitName *= *//p' | head -1)
    echo "Signing with Developer ID (team $team)"
    set -- CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" \
        DEVELOPMENT_TEAM="$team" PROVISIONING_PROFILE_SPECIFIER= \
        OTHER_CODE_SIGN_FLAGS=--timestamp
else
    echo "No Developer ID certificate found; signing ad hoc."
    set -- CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
fi

# A separate derived-data folder, so this never disturbs the build install.sh uses.
xcodebuild -project Cowpy.xcodeproj -scheme Cowpy -configuration Release \
    -derivedDataPath build/dist "$@" build 2>&1 \
    | grep -E "^/.*: (error|warning): |^error: |^\*\* BUILD" || true

app=build/dist/Build/Products/Release/Cowpy.app
[ -d "$app" ] || { echo "Build failed: $app is missing" >&2; exit 1; }

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Cowpy.app"
ln -s /Applications "$staging/Applications"

mkdir -p dist
dmg="dist/Cowpy-$version.dmg"
rm -f "$dmg"
hdiutil create -volname "Cowpy $version" -srcfolder "$staging" -fs HFS+ -format UDZO -quiet "$dmg"

if [ -n "$developer_id" ]; then
    codesign --sign "$developer_id" --timestamp "$dmg"
    if xcrun notarytool history --keychain-profile cowpy-notary >/dev/null 2>&1; then
        echo "Notarising (this can take a few minutes)…"
        xcrun notarytool submit "$dmg" --keychain-profile cowpy-notary --wait
        xcrun stapler staple "$dmg"
    else
        echo "No 'cowpy-notary' keychain profile; skipping notarisation."
    fi
fi

echo "Created $dmg ($(du -h "$dmg" | cut -f1 | tr -d ' '))"
