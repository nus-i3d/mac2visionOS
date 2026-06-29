# Get started

## Requirements

- Xcode with the macOS 14 and visionOS SDKs
- A Mac and either Apple Vision Pro or the visionOS simulator
- Both apps on the same local network for device testing

## Add the package

In Xcode, choose **File → Add Package Dependencies**, enter:

```text
https://github.com/careylzh/mac2visionOS
```

Select the `Mac2VisionOS` library product, then import it:

```swift
import Mac2VisionOS
```

## Configure permissions

The consuming app owns its network permissions. Add the Bonjour service and local-network description to its `Info.plist`:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_m2vo._tcp</string>
</array>
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to nearby mac2visionOS devices.</string>
```

For a sandboxed macOS target, enable outgoing and incoming network connections. See the working configuration in `Example/Config`.

## Run the example

Open `Example/mac2visionOS.xcworkspace`. The shared scheme chooses its role from the run destination:

1. Run on **Apple Vision Pro**. Enter a four-character key such as `AVP1`, then select **Start Hosting**.
2. Run on **My Mac**. Enter the same key, select **Browse**, and connect to the discovered host.
3. Send **Ping** or a movement command. The host displays the command and the controller displays its acknowledgement.

!!! note
    The group key is normalized to four uppercase letters or digits. It narrows Bonjour discovery; it is not authentication or encryption.

## Integrate the models

On visionOS, create a `BubbleHostModel`, start hosting, and react to its published state. On macOS, create a `BubbleControllerModel`, browse, connect, and send a `BubbleAction`.

The example views under `Example/mac2visionOS` are the canonical integration reference.
