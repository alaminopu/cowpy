#!/bin/sh
# Build a Release copy of Cowpy, install it to /Applications and relaunch it.
#
# If an "Apple Development" certificate is in the keychain (add your Apple ID
# under Xcode > Settings > Accounts, then Manage Certificates > + > Apple
# Development), the build is signed with it. That gives the app a stable
# identity, so macOS keeps its Accessibility permission across reinstalls.
# Without one the build is ad-hoc signed and the permission has to be granted
# again after every install.
#
#   scripts/install.sh            build, install, relaunch
#   BUILD_ONLY=1 scripts/install.sh   build and report the signature only
set -eu
cd "$(dirname "$0")/.."

identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)
if [ -n "$identity" ]; then
    team=$(security find-certificate -c "$identity" -p \
        | openssl x509 -noout -subject -nameopt multiline \
        | sed -n 's/^ *organizationalUnitName *= *//p' | head -1)
    echo "Signing with: $identity (team $team)"
    set -- CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
        DEVELOPMENT_TEAM="$team" PROVISIONING_PROFILE_SPECIFIER=
else
    echo "No Apple Development certificate found; signing ad hoc."
    echo "The Accessibility permission will need to be granted again after this install."
    set --
fi

xcodebuild -project Cowpy.xcodeproj -scheme Cowpy -configuration Release \
    -derivedDataPath build "$@" build 2>&1 \
    | grep -E "^/.*: (error|warning): |^error: |^\*\* BUILD" || true

app=build/Build/Products/Release/Cowpy.app
[ -d "$app" ] || { echo "Build failed: $app is missing" >&2; exit 1; }
codesign -dvv "$app" 2>&1 | grep -E "^(Authority=Apple Development|Signature=|TeamIdentifier=)" | head -3

[ "${BUILD_ONLY:-0}" = 1 ] && exit 0

osascript -e 'tell application "Cowpy" to quit' >/dev/null 2>&1 || true
i=0
while pgrep -x Cowpy >/dev/null && [ $i -lt 20 ]; do
    i=$((i + 1))
    perl -e 'select(undef, undef, undef, 0.25)'
done

rm -rf /Applications/Cowpy.app
ditto "$app" /Applications/Cowpy.app
open /Applications/Cowpy.app
echo "Installed and launched /Applications/Cowpy.app"
