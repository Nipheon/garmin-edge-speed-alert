# SpeedAlert

> **Not available in the Connect IQ store.** This data field was rejected by the
> store: Garmin does not allow safety-related apps, and an over-speed alarm falls
> under that ban. The code is kept here for sideloading onto your own device only.

A Connect IQ data field for Garmin Edge cycling computers. It duplicates the
built-in **Speed** field (current speed in the device's configured unit,
km/h or mph) and adds a configurable over-speed alarm: when you stay above a
speed threshold for a set number of seconds, the field beeps once per second
and flips its background — **red** on color Edges, **black** on the
monochrome Edge 130 / 130 Plus — until you slow back down.

## Settings

Edit via the Connect IQ mobile app or Garmin Express (data field → Settings):

| Setting | Default | Meaning |
|---|---|---|
| Speed threshold | 40 | Speed above which the alarm arms. Interpreted in the device's current speed unit — `40` means 40 km/h on a metric device, 40 mph on a statute device. |
| Alarm delay (seconds) | 5 | How long speed must stay **continuously** above the threshold before the alarm triggers. The counter resets the instant speed drops to or below the threshold. |

Alarm behavior: while alerting, `Attention.playTone(TONE_CANARY)` fires once
per `compute()` tick (guarded by a 900 ms timer so it can never double-fire),
and the field background inverts as described above. The alarm clears
immediately when speed drops to/below the threshold. Vibration is deliberately
not used — many Edge devices have no vibration motor.

## Black vs. red background

There is no runtime API for display color depth, so the choice is made at
build time from the SDK's own device data (`Devices/<id>/compiler.json →
bitsPerPixel`): only `edge130` and `edge130plus` are 1-bit monochrome; every
other supported Edge is 16-bit color. `monkey.jungle` excludes the
`(:colorDisplay)` constant on those two devices and the `(:monoDisplay)`
constant everywhere else (see `source/DisplayColors.mc`).

## Supported devices

All 20 Edge device IDs in the current SDK (9.1.0) — every Edge that has
Connect IQ data fields also supports `Attention.playTone` and app settings,
so nothing had to be excluded. `minApiLevel` is **2.4.0**, below the lowest
part-number variant (Edge 520 / 820 regional units at 2.4.1), so a package
export builds all 42 part numbers with none silently skipped. Edge 800/810
predate Connect IQ entirely and cannot be supported.

Constraint honored for the oldest tier: the Edge 520/130 family has a 32 KB
data-field memory limit and CIQ 2.4/3.1 APIs — the code avoids everything
newer than 2.4 (settings are read via `Application.Properties`, introduced
in 2.4.0).

## Localization

English (base) plus German, French, Spanish, Italian, Portuguese, Simplified
Chinese, and Japanese, in `resources-<qualifier>/strings/strings.xml`.
Qualifiers come from the SDK's `bin/default.jungle` — note Garmin uses
**`fre`** for French and **`deu`** for German, not the ISO codes you might
guess. All eight translations are verified present in the compiled binary
(`grep -a -o <word> bin/edge1040.prg`). `AppName` is marked
`translatable="false"` to suppress per-language "String id undefined"
warnings while intentionally staying untranslated.

## Build & sideload

```sh
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<current-sdk>"

# Build for one device (developer key lives one directory up)
"$SDK/bin/monkeyc" -o bin/edge1040.prg -f monkey.jungle -y ../developer_key -d edge1040 -w

# Run in the simulator
"$SDK/bin/connectiq" &          # start the simulator
"$SDK/bin/monkeydo" bin/edge1040.prg edge1040

# Sideload: plug the Edge in via USB (mass storage) and copy
cp bin/edge1040.prg /Volumes/GARMIN/Garmin/Apps/

# Store package (builds every supported device/part number)
"$SDK/bin/monkeyc" -e -o bin/SpeedAlert.iq -f monkey.jungle -y ../developer_key -w
```

Then on the device: add a Connect IQ data field to a data screen
(Settings → Activity Profiles → Data Screens → Connect IQ → SpeedAlert).
When sideloaded (not installed through the store), settings can be edited in
the simulator (File → Edit Persistent Storage → Edit Application.Properties)
or by installing via the store for phone-app settings support.

Bump the manifest `version` before any store upload whenever devices,
languages, or rendering change — the store rejects uploads with a version ≤
the published one.
