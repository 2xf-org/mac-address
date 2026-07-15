# 🎭 MAC Address

<p align="center">
  <img src=".github/app-icon.png" alt="MAC Address icon" width="128">
</p>

<p align="center">
  <a href="https://github.com/2xf-org/mac-address/actions/workflows/build.yml">
    <img src="https://github.com/2xf-org/mac-address/actions/workflows/build.yml/badge.svg" alt="Build">
  </a>
</p>

A tiny macOS menu bar app for changing a network interface's MAC address and
switching between saved profiles.

MAC Address discovers the interfaces already attached to your Mac, shows the
current address, and applies custom, random, saved, or hardware addresses on
interfaces whose drivers support it. It has no Dock icon, no third-party
service, and no telemetry.

<p align="center">
  <img src=".github/menu.png" alt="MAC Address menu" width="420">
</p>

## Installing

Requires macOS 13+ and Xcode command line tools.

Download the latest app from [Releases](https://github.com/2xf-org/mac-address/releases),
or build it locally:

```sh
./build.sh
open "MAC Address.app"
```

To keep it around, move `MAC Address.app` to `/Applications` and add it to
**System Settings → General → Login Items**.

## Using

- **Interface**: choose an Ethernet, Thunderbolt, Wi-Fi, or other hardware port.
- **Randomize Address**: generate a locally administered unicast address on a
  supported interface.
- **Set Address…**: apply any valid unicast 48-bit MAC address on a supported
  interface.
- **Profiles**: save the current address with its interface, apply it later, or
  delete it without changing the active address.
- **Restore Hardware Address**: return the selected interface to the address
  reported by macOS for that hardware port.
- **Private Wi-Fi Settings…**: on current macOS versions, open Apple's per-network
  **Off**, **Fixed**, and **Rotating** Private Wi-Fi Address controls.

macOS asks for administrator approval whenever an address is changed. The
interface may disconnect briefly while its hardware filter is reprogrammed. For
Wi-Fi, MAC Address powers the interface off and back on, sets the address before
it reassociates, and then lets it reconnect automatically.

## How it works

The app reads hardware ports with `networksetup`, reads live addresses with
`ifconfig`, and uses macOS's standard administrator prompt to run a validated
address-change sequence. Interface names come from macOS and are restricted to
safe device characters; addresses are parsed and normalized before the
privileged command is created.

Apple's Wi-Fi driver rejects `ifconfig` while it is associated with a network.
MAC Address follows the established approach used by
[`spoof`](https://github.com/feross/spoof): disassociate first, apply the address,
then reconnect. Tahoe no longer includes the private `airport -z` helper used by
older tools, so MAC Address creates the same disassociated window with
`networksetup -setairportpower`.

Starting with macOS Sequoia 15, Private Wi-Fi Address may replace a custom
address when Wi-Fi reconnects. If that happens, choose **Off** for the current
network before applying the custom address. See Apple's guide to
[Private Wi-Fi Address](https://support.apple.com/en-us/102509).

Profiles stay local at:

```text
~/Library/Application Support/MAC Address/profiles.json
```

Direct MAC changes are normally temporary. A reboot, reconnect, network setting,
or driver may restore or replace the address. Some hardware drivers do not
permit address changes; the app verifies the reported address and tells you
when a driver rejects the update. Use this tool only on networks you own or are
authorized to test.

## Development

```sh
./test.sh
./build.sh
```

No Xcode project is required. The build script regenerates the app icon, menu
bar glyph, and README artwork before compiling the app bundle.
README artwork is rendered from synthetic data and never reads a live network
interface.

Network glyph drawn for MAC Address and released with the app.
