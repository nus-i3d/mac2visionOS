# mac2visionOS

Prototype for a macOS controller app talking to a visionOS host app over the local network.

The current app uses one multi-platform Xcode scheme:

- Run on **visionOS / Apple Vision Pro** to host the shared bubble.
- Run on **macOS / My Mac** to act as a controller.

## Manual Simulator Test

Use these steps when validating the macOS <> visionOS flow manually.

### 1. Check Available Destinations

```sh
xcodebuild -showdestinations \
  -project mac2visionOS.xcodeproj \
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
  -project mac2visionOS.xcodeproj \
  -scheme mac2visionOS \
  -destination 'id=<DEVICE_ID>' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

If direct simulator targeting is unavailable, this generic build is still useful for compile validation:

```sh
xcodebuild build \
  -project mac2visionOS.xcodeproj \
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
  -project mac2visionOS.xcodeproj \
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

- The project currently has no configured test target/action, so `xcodebuild test` reports that the scheme is not configured for testing.
- Some automation environments cannot access CoreSimulator from a sandbox. If `simctl` or direct simulator `xcodebuild` commands fail with CoreSimulator connection errors, rerun them with the needed host permissions or perform the simulator steps manually in Xcode.
- Leave unrelated Xcode user/scheme metadata unstaged unless intentionally changing scheme configuration.

