# Lowtide

Lowtide is an iPhone app that helps people with sensory sensitivities find calm places. Every place has a "tide": noise, harsh light and crowds roll in and out during the day. Lowtide forecasts when a place will be calm **for you**, based on your own sensory profile.

This is v1: SwiftUI, MapKit, Swift Charts, SwiftData, CoreLocation, AVFoundation and UserNotifications only. It has no third-party packages, no backend, no account and no analytics. The only network use is Apple's map tiles and walking directions.

## Run it

1. Open `Lowtide.xcodeproj` in Xcode 16 or later. Xcode 26 is recommended.
2. Choose the **Lowtide** scheme and an iPhone simulator, then press Run. The minimum deployment target is iOS 17.
3. To run on your iPhone, select the Lowtide target, open **Signing & Capabilities**, choose your team and change the bundle identifier (`app.lowtide.Lowtide`) to one you own.

Run the tests with **Product › Test** (⌘U), or:

```sh
xcodebuild test -project Lowtide.xcodeproj -scheme Lowtide \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Pick any simulator listed by `xcrun simctl list devices available`.

### Demo launch arguments (Debug builds)

The scheme has these arguments, switched off. Turn them on under **Product › Scheme › Edit Scheme › Run › Arguments**:

- `-LowtideDemoTime 14:10` fixes the time of day, so you can see the mockup's afternoon whenever you test.
- `-LowtideDemoScreen <screen>` opens a screen with the default profile. Nothing is saved. The screens are `onboarding`, `map`, `place:<id>`, `route:<id>`, `checkin:<id>`, `lowwater`, `cards` and `profile`, for example `place:marlow-street-library`.

## Where things live

| Folder | What's in it |
|---|---|
| `Lowtide/App` | App entry point, root view, preview helpers |
| `Lowtide/DesignSystem` | `WaveGlyph`, status badges, buttons, chips, cards, meter, sparkline, flow layout |
| `Lowtide/Models` | Places, forecasts, the sensory profile and the SwiftData models |
| `Lowtide/Engine` | `TideEngine` and the plain-English wording. Pure Swift with no UI, fully unit-tested |
| `Lowtide/Data` | `PlaceRepository`, `LocalPlaceRepository`, the stores and **`places.json`** |
| `Lowtide/Services` | Location, walking directions, notifications, the sound meter, the clock |
| `Lowtide/Features` | Map, Place, CheckIn, LowWater and Profile screens |
| `LowtideTests` | Swift Testing unit tests for the engine and the sample data |

The colour tokens are in `Lowtide/Assets.xcassets`. Each has a dark-mode variant, and the text colours also have Increase Contrast variants. Text pairs meet 4.5:1 contrast or better.

## Sample data

`Lowtide/Data/places.json` holds 10 invented places: two libraries, three cafés, a park, a market, a station, a bookshop and a quiet room. Each place has:

- its position as metre offsets east and north of a demo centre. The demo centre is your first location fix, or central London (51.5074, -0.1278) if location isn't available, so the demo works wherever you are
- its opening hours
- 24 hourly values for every factor: `noiseDB` in decibels, plus `sudden`, `light`, `crowd` and `smell` from 0 to 1
- trigger tags, "good to know" lines, an optional quiet hour and the busy periods used to explain changes

Every day uses the same forecast in v1. To add or change places, edit the JSON. The `SampleData` tests check that the file still matches the mockup's story.

## How the tide is worked out

- Noise is normalised as `clamp((dB - 40) / 40, 0, 1)`.
- Each factor is weighted by your sensitivity: A bit = 0.5, Some = 1.0, A lot = 1.6.
- Your score for a moment is the **highest** weighted factor, so the worst trigger dominates.
- Below 0.4 is **Calm** (low tide), below 0.7 is **Busy**, and 0.7 or above is **High tide**. A closed place has no status.
- Values are interpolated between hours, and changes are reported on the half hour ("Calm until 3:30pm").
- **Best time today** is the longest calm window from now until closing.
- A trigger gets a heads-up chip when your sensitivity for its factor is Some or A lot.

## Privacy

- Your profile, saved places and check-ins are stored on the device with SwiftData. Nothing is uploaded.
- The sound meter computes a level from microphone samples in memory. Audio is never written to disk, kept or sent. Only the number is stored, and only when "Share sound readings" is on.
- Location is when-in-use only, and is used to place the map and measure walking distances.

## Known limitations in v1

- **Sound readings are approximate.** iPhone microphones aren't calibrated sound level meters. `SoundMeter.calibrationOffset` (+100 dB) maps the microphone's dBFS to an approximate dB SPL. To tune it for a device, compare a steady sound against a reference meter.
- **The forecast is invented sample data.** It's the same every day, and check-ins are stored but don't change the forecast yet.
- **Places follow you.** The sample places are positioned around your first location fix each launch. If you start far from where you were last time, they move with you.
- **Segmented controls use the system height.** The "What gets to you" pickers are standard segmented `Picker`s, so their height (about 32 pt) is set by iOS, not by the app.

## Continuous integration

`.github/workflows/ios.yml` runs on every push. It builds and tests the app on a macOS runner with the newest stable Xcode and fails on any compiler warning. It also saves simulator screenshots of every screen, plus rendered images of the place page sections, as the `lowtide-review` build artifact.
