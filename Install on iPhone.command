#!/bin/bash
# Double-click this file in Finder to build IELTS Assistant and install it on the
# iPhone connected to this Mac. One-time setup is described in README.md
# ("Install with one double-click").

set -uo pipefail
cd "$(dirname "$0")"

PROJECT="IELTSAssistant.xcodeproj"
SCHEME="IELTSAssistant"
BUILD_DIR="build"
LOG="$BUILD_DIR/install.log"
mkdir -p "$BUILD_DIR"

bold()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
green() { printf '\n\033[32m%s\033[0m\n' "$1"; }
pause() { if [ -t 0 ]; then echo; read -n 1 -s -r -p "Press any key to close this window."; echo; fi; }
fail()  { printf '\n\033[31m%s\033[0m\n' "$1"; pause; exit 1; }

command -v xcodebuild >/dev/null 2>&1 || fail "Xcode is not installed. Install it from the Mac App Store, open it once, then try again."

BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER = " "$PROJECT/project.pbxproj" | sed -E 's/.*= "?([^";]+)"?;/\1/')

# ---------------------------------------------------------------- 1. find the iPhone
bold "1/4  Looking for your iPhone…"
JSON=$(mktemp)
xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1
DEVICE=$(/usr/bin/python3 -I - "$JSON" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
found = []
for d in devices:
    props = d.get("properties") or {}
    hw = props.get("hardware") or d.get("hardwareProperties") or {}
    conn = props.get("connection") or d.get("connectionProperties") or {}
    state = props.get("state") or d.get("deviceProperties") or {}
    if hw.get("platform") != "iOS" or hw.get("reality") == "simulated":
        continue
    paired = conn.get("pairingState") == "paired"
    connected = conn.get("state") == "connected" or conn.get("tunnelState") == "connected"
    name = state.get("name") or hw.get("marketingName") or "iPhone"
    found.append((paired, connected, hw.get("udid") or d.get("identifier"), name))
found.sort(key=lambda f: (f[1], f[0]), reverse=True)
if found:
    paired, connected, udid, name = found[0]
    print("\t".join([udid, name, "paired" if paired else "unpaired", "connected" if connected else "unreachable"]))
PY
)
rm -f "$JSON"
[ -n "$DEVICE" ] || fail "No iPhone found. Connect it with a cable, unlock it, tap Trust if asked, then double-click this file again."
UDID=$(printf '%s' "$DEVICE" | cut -f1)
NAME=$(printf '%s' "$DEVICE" | cut -f2)
PAIRED=$(printf '%s' "$DEVICE" | cut -f3)
REACH=$(printf '%s' "$DEVICE" | cut -f4)
[ "$PAIRED" = "paired" ] || fail "\"$NAME\" is connected but does not trust this Mac yet. Unlock it, tap Trust, enter your passcode, then try again."
[ "$REACH" = "connected" ] || fail "\"$NAME\" is known but not reachable right now. Unlock it and check the cable
(if it is restarting, wait until it has finished), then double-click this file again."
echo "Found \"$NAME\"."

if xcrun devicectl device info details --device "$UDID" 2>/dev/null | grep -q "Developer Mode Status: Disabled"; then
    fail "Developer Mode is off on \"$NAME\". On the iPhone: Settings › Privacy & Security › Developer Mode › On, then Restart.
After the restart, unlock it and tap Turn On. Then double-click this file again."
fi

# ---------------------------------------------------------------- 2. signing team
bold "2/4  Checking your Apple ID…"
TEAM=$(grep -m1 "DEVELOPMENT_TEAM = " "$PROJECT/project.pbxproj" | sed -E 's/.*= "?([A-Z0-9]+)"?;/\1/')
if [ -z "$TEAM" ]; then
    # Fall back to the teams of the Apple IDs added in Xcode › Settings › Accounts.
    TEAMS=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
        | grep -E "teamID = " | sed -E 's/.*teamID = "?([A-Z0-9]+)"?;.*/\1/' | sort -u)
    if [ "$(printf '%s\n' "$TEAMS" | grep -c .)" = "1" ]; then
        TEAM="$TEAMS"
    fi
fi
if [ -z "$TEAM" ]; then
    open "$PROJECT"
    fail "No Apple ID is set up for signing yet (one-time step). Xcode is opening now:
  1. Xcode › Settings › Accounts › + › Apple ID, and sign in.
  2. Click the blue IELTSAssistant project, then the IELTSAssistant target,
     then Signing & Capabilities, and choose your team in Team.
Then double-click this file again."
fi
echo "Signing with team $TEAM."

# ---------------------------------------------------------------- 3. build
bold "3/4  Building the app (the first time takes a few minutes)…"
if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
        -destination "platform=iOS,id=$UDID" -destination-timeout 300 -derivedDataPath "$BUILD_DIR/DerivedData" \
        -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
        DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
        build > "$LOG" 2>&1; then
    echo
    grep -E "error:" "$LOG" | sed -E 's/^.*error: //' | sort -u | head -6
    if grep -q -i "developer mode" "$LOG"; then
        fail "Developer Mode is off on the iPhone. Turn it on in Settings › Privacy & Security › Developer Mode, restart the phone, then try again."
    fi
    if grep -q -i -E "No Account|no accounts|sign in" "$LOG"; then
        fail "Xcode needs you to sign in again: Xcode › Settings › Accounts. Then try again."
    fi
    if grep -q -i -E "bundle identifier.*(not available|cannot be registered)|failed to register bundle identifier" "$LOG"; then
        fail "The app ID is taken. In Xcode › Signing & Capabilities, change the Bundle Identifier (for example add your name to the end), then try again."
    fi
    fail "The build failed. The full log is in $LOG"
fi
APP="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/$SCHEME.app"
[ -d "$APP" ] || fail "The build finished but the app was not found at $APP"

# ---------------------------------------------------------------- 4. install and open
bold "4/4  Installing on \"$NAME\"…"
if ! xcrun devicectl device install app --device "$UDID" "$APP" >> "$LOG" 2>&1; then
    if grep -q -i "developer mode" "$LOG"; then
        fail "Developer Mode is off on the iPhone. Turn it on in Settings › Privacy & Security › Developer Mode, restart the phone, then try again."
    fi
    fail "Installing failed. Keep the iPhone unlocked and try again. Details are in $LOG"
fi

if xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >> "$LOG" 2>&1; then
    green "Done. IELTS Assistant is open on \"$NAME\"."
else
    green "Installed on \"$NAME\"."
    echo "If the phone says \"Untrusted Developer\": Settings › General › VPN & Device Management,"
    echo "tap your Apple ID, then Trust. After that, open IELTS Assistant from the Home Screen."
fi
echo
echo "With a free Apple ID the app works for 7 days. To renew it, connect the phone and"
echo "double-click this file again. Your practice history is kept."
pause
