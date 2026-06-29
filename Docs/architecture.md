# Architecture

mac2visionOS separates the wire protocol from platform-specific host and controller state.

## Components

| Component | Platform | Responsibility |
| --- | --- | --- |
| `BubbleProtocol` | macOS + visionOS | Service naming and four-character key validation |
| `BubbleMessage` | macOS + visionOS | Codable hello, command, and acknowledgement envelope |
| `BubblePeerConnection` | macOS + visionOS | Framing, sending, receiving, and connection events |
| `BubbleHostModel` | visionOS | Bonjour listener, connected clients, command handling |
| `BubbleControllerModel` | macOS | Discovery, host selection, connection, and commands |
| Smoke/stability models | macOS | Repeatable runtime validation through launch arguments |

## Discovery and connection

The host advertises the Bonjour service `_m2vo._tcp` with a name derived from the normalized key, for example `mac2visionOS-AVP1`. The controller browses that service type and keeps only the matching service name.

After TCP connects, the controller sends a `BubblePeerHello`. The host validates its group key and role before registering it. Commands carry their own group key and receive a `BubbleAcknowledgement` identifying the original message.

## Available actions

```swift
public enum BubbleAction: String, CaseIterable, Codable {
    case ping
    case moveLeft, moveRight
    case moveUp, moveDown
    case select
    case reset
}
```

The host currently records and acknowledges these actions. Replace or extend the action handling in your app to connect them to scene state, gestures, navigation, or game logic.

## Trust boundary

The package is designed for local-network prototypes and controlled experiences. The group key filters peers but does not provide identity, confidentiality, or authorization. Add an application-level security design before using the protocol for sensitive data or privileged actions.
