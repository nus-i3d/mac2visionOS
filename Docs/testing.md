# Testing

## Package tests

Run the protocol unit tests from the repository root:

```sh
swift test
```

They cover key normalization, service names, and message encoding round trips.

## Four-client local check

The macOS example includes a transport harness:

1. Run the example on **My Mac**.
2. Enter a valid four-character key.
3. Select **Run 4-Client Check**.
4. Confirm the result reads `4-client local check passed`.

This validates four loopback TCP clients and acknowledgements. It does not prove Bonjour or a physical multi-device network.

## Simulator smoke test

Build the example for a booted Vision Pro simulator and macOS, then launch the automated host and client:

```sh
xcrun simctl launch <DEVICE_ID> com.i3d.mac2visionOS \
  --bubble-smoke-host AVP1

open -W -n .DerivedData/Build/Products/Debug/mac2visionOS.app \
  --stdout /private/tmp/mac2vision-smoke.out \
  --stderr /private/tmp/mac2vision-smoke.err \
  --args --bubble-smoke-client AVP1
```

A passing client log contains:

```text
[BubbleSmoke] Found mac2visionOS-AVP1; connecting
[BubbleSmoke] Decoded ack(true, Accepted Ping)
[BubbleSmoke] Smoke connection passed: Accepted Ping
```

See the repository `README.md` for complete build, stability, and multi-client commands.

## Documentation preview

Install the pinned documentation dependency and serve the site:

```sh
python3 -m pip install --requirement requirements-docs.txt
zensical serve
```

Open `http://localhost:8000`. Production builds run with `zensical build --clean` and are deployed by GitHub Actions.
