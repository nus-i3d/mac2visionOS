---
title: mac2visionOS
description: A Swift package for controlling a visionOS experience from macOS over the local network.
hide:
  - navigation
---

# One shared bubble. Multiple Mac controllers.

mac2visionOS is a Swift package and example app for sending commands from macOS to a visionOS host over the local network. It handles Bonjour discovery, TCP connections, typed messages, acknowledgements, and observable state for SwiftUI.

[Get started](getting-started.md){ .md-button .md-button--primary }
[Explore the architecture](architecture.md){ .md-button }

## What it provides

<div class="feature-grid" markdown>

<div class="feature-card" markdown>

### Native Swift

A Swift 6 package supporting macOS 14 and visionOS 1 or later, built on Apple's Network framework.

</div>

<div class="feature-card" markdown>

### Local discovery

The visionOS host advertises `_m2vo._tcp`; matching macOS controllers discover it using a four-character group key.

</div>

<div class="feature-card" markdown>

### Typed protocol

Codable hello, command, and acknowledgement messages make communication explicit and testable.

</div>

<div class="feature-card" markdown>

### Multi-controller ready

One visionOS host accepts multiple controllers. A local harness checks four simultaneous clients.

</div>

</div>

## The flow

```text
visionOS host                     macOS controller
     │                                   │
     ├── advertises mac2visionOS-AVP1 ──►│
     │◄──────── TCP connection ──────────┤
     │◄──────── hello + command ─────────┤
     ├──────── acknowledgement ─────────►│
```

The package is intentionally a transport and state layer. Your visionOS app decides what actions such as `moveLeft`, `select`, or `reset` do in the experience.
