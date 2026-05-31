# mac2visionOS

Swift package and example app for a macOS controller talking to a visionOS host app over the local network.

## Swift Package

The reusable protocol, Bonjour/networking, and observable model layer lives in `Sources/Mac2VisionOS`.

Add the package in Xcode with **File > Add Package Dependencies...**, paste this repository URL, and select the `Mac2VisionOS` library product. Then import it from your app:

```swift
import Mac2VisionOS
```

The package exposes the core bubble protocol types, peer connection helper, host/controller models, and local smoke/stability harness models. Consuming apps still own their app-level permissions. At minimum, add these to the app target using the package:

- `NSBonjourServices` with `_m2vo._tcp`
- `NSLocalNetworkUsageDescription`
- macOS sandbox network client/server entitlements when sandboxing is enabled

The example app in `Example/` shows those settings in `Example/Config/Info.plist` and `Example/Config/mac2visionOS.entitlements`.

## Example App

The current app uses one multi-platform Xcode scheme:

- Run on **visionOS / Apple Vision Pro** to host the shared bubble.
- Run on **macOS / My Mac** to act as a controller.

Open `Example/mac2visionOS.xcworkspace` in Xcode. The app target imports the local package from the repository root.

## Build, Sign, and Generate a macOS DMG

Run these commands from the repository root to create a signed macOS DMG for the example app.

Build the Release app:

```sh
xcodebuild build \
  -workspace Example/mac2visionOS.xcworkspace \
  -scheme mac2visionOS \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/mac2visionOS-dmg-derived
```

Set a timestamp and staging directory:

```sh
STAMP=$(date +%Y%m%d-%H%M%S)
STAGING="/private/tmp/mac2visionOS-dmg-staging-$STAMP"
mkdir -p "$STAGING"
```

Copy the built app and add an Applications shortcut:

```sh
ditto \
  /private/tmp/mac2visionOS-dmg-derived/Build/Products/Release/mac2visionOS.app \
  "$STAGING/mac2visionOS.app"
ln -s /Applications "$STAGING/Applications"
```

Create the DMG:

```sh
mkdir -p Releases
hdiutil create \
  -volname mac2visionOS \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "Releases/mac2visionOS-macOS-$STAMP.dmg"
```

Find an available signing identity:

```sh
security find-identity -v -p codesigning
```

Sign a copy of the DMG. Set `SIGNING_IDENTITY_HASH` to the hash from the previous command, for example an `Apple Development` or `Developer ID Application` identity.

```sh
SIGNING_IDENTITY_HASH="04DAF6ECC1E4291B8750C45D52B4FB8919DA9395"
cp \
  "Releases/mac2visionOS-macOS-$STAMP.dmg" \
  "Releases/mac2visionOS-macOS-signed-$STAMP.dmg"
codesign --force \
  --sign "$SIGNING_IDENTITY_HASH" \
  "Releases/mac2visionOS-macOS-signed-$STAMP.dmg"
```

Verify the signed DMG and app:

```sh
hdiutil verify "Releases/mac2visionOS-macOS-signed-$STAMP.dmg"
codesign -dv --verbose=4 "Releases/mac2visionOS-macOS-signed-$STAMP.dmg"
codesign --verify --deep --strict --verbose=2 \
  /private/tmp/mac2visionOS-dmg-derived/Build/Products/Release/mac2visionOS.app
```

This produces:

```text
Releases/mac2visionOS-macOS-$STAMP.dmg
Releases/mac2visionOS-macOS-signed-$STAMP.dmg
```

The signed DMG is locally signed. For public distribution outside your development machines, sign with a Developer ID certificate and notarize the DMG.

## Manual Simulator Test

Use these steps when validating the macOS <> visionOS flow manually.

### 1. Check Available Destinations

```sh
xcodebuild -showdestinations \
  -workspace Example/mac2visionOS.xcworkspace \
  -scheme mac2visionOS
```

List available simulators and find the booted Apple Vision Pro simulator ID:

```sh
xcrun simctl list devices available
```

Expected visionOS entry looks like:

```text
-- visionOS 26.2 --
    Apple Vision Pro (<DEVICE_ID>) (Booted)
```

### 2. Build for the Booted Apple Vision Pro Simulator

Replace `<DEVICE_ID>` with the Apple Vision Pro simulator ID from `simctl`.

```sh
xcodebuild build \
  -workspace Example/mac2visionOS.xcworkspace \
  -scheme mac2visionOS \
  -destination 'id=<DEVICE_ID>' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

If direct simulator targeting is unavailable, this generic build is still useful for compile validation:

```sh
xcodebuild build \
  -workspace Example/mac2visionOS.xcworkspace \
  -scheme mac2visionOS \
  -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

### 3. Install and Launch on the Vision Pro Simulator

```sh
xcrun simctl install <DEVICE_ID> \
  .DerivedData/Build/Products/Debug-xrsimulator/mac2visionOS.app
```

```sh
xcrun simctl launch <DEVICE_ID> com.i3d.mac2visionOS
```

The launch command prints a process ID when successful.

### 4. Build and Launch the macOS Controller

```sh
xcodebuild build \
  -workspace Example/mac2visionOS.xcworkspace \
  -scheme mac2visionOS \
  -destination 'platform=macOS' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

```sh
open .DerivedData/Build/Products/Debug/mac2visionOS.app
```

### 5. Exercise the App Flow

On the Vision Pro simulator:

1. Enter a 4-character key, for example `AVP1`.
2. Click **Start Hosting**.
3. Confirm the status shows the Bonjour host name.

On macOS:

1. Enter the same 4-character key.
2. Click **Browse**.
3. Select the discovered AVP host.
4. Click **Connect**.
5. Send a command such as **Ping**.

Expected result:

- visionOS shows the connected Mac controller.
- visionOS command log shows the received command.
- macOS log shows an acknowledgement.
- Diagnostics sections on both apps show connection and message events.

### 6. Run the Local 4-Client Check

The macOS app includes a local harness for the multi-client transport layer.

1. Run the macOS app.
2. Enter a valid 4-character key.
3. Click **Run 4-Client Check**.

Expected result:

```text
4-client local check passed
```

This check proves one local listener can receive commands from four local clients and return four acknowledgements. It does not replace a physical 4-MacBook + 1-AVP network test.

### 7. Run the Simulator Smoke Check

The app also supports launch arguments for a repeatable simulator check. This starts the Vision Pro simulator as the Bonjour host and runs the macOS app as a client that exits after receiving an acknowledgement.

Launch the Vision Pro simulator host with a 4-character key:

```sh
xcrun simctl launch <DEVICE_ID> com.i3d.mac2visionOS \
  --bubble-smoke-host AVP1
```

Run one macOS smoke client and capture its output:

```sh
open -W -n .DerivedData/Build/Products/Debug/mac2visionOS.app \
  --stdout /private/tmp/mac2vision-smoke.out \
  --stderr /private/tmp/mac2vision-smoke.err \
  --args --bubble-smoke-client AVP1
```

Expected output includes:

```text
[BubbleSmoke] Found mac2visionOS-AVP1; connecting
[BubbleSmoke] Decoded ack(true, Accepted Ping)
[BubbleSmoke] Smoke connection passed: Accepted Ping
```

To approximate four Mac controllers from one development Mac, launch four smoke clients with separate output files at the same time. Each client should report `Smoke connection passed: Accepted Ping`.

### 8. Run the Stability Check

This variant keeps one Bonjour connection open and sends a sequence of pings to confirm the AVP simulator host stays reachable over time.

Run the macOS stability client:

```sh
open -W -n .DerivedData/Build/Products/Debug/mac2visionOS.app \
  --stdout /private/tmp/mac2vision-stability.out \
  --stderr /private/tmp/mac2vision-stability.err \
  --args --bubble-stability-client AVP1
```

Expected output includes:

```text
[BubbleStability] Sending ping 1/5
[BubbleStability] Received acknowledgement 5/5
[BubbleStability] Stable connection passed: 5/5 acknowledgements
```

## Runtime Diagnostics

The app surfaces runtime diagnostics in the UI. Use those first for:

- listener state
- browser state
- discovered host count
- connection state
- message send/receive
- decode failures
- rejected wrong-key peers

You can also inspect Bonjour advertisement from Terminal while the AVP host is running:

```sh
dns-sd -B _m2vo._tcp local
```

Resolve a discovered service:

```sh
dns-sd -L mac2visionOS-AVP1 _m2vo._tcp local
```

Replace `AVP1` with the active bubble key.

## Simulator Logs

Stream logs for the app bundle from a booted simulator:

```sh
xcrun simctl spawn <DEVICE_ID> log stream \
  --predicate 'process == "mac2visionOS"' \
  --style compact
```

For macOS app logs, use Console.app or run:

```sh
log stream \
  --predicate 'process == "mac2visionOS"' \
  --style compact
```

## Notes

- Run package tests from the repository root with `swift test`.
- Some automation environments cannot access CoreSimulator from a sandbox. If `simctl` or direct simulator `xcodebuild` commands fail with CoreSimulator connection errors, rerun them with the needed host permissions or perform the simulator steps manually in Xcode.
- Leave unrelated Xcode user/scheme metadata unstaged unless intentionally changing scheme configuration.
