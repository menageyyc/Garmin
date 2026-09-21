# UV Tracker

A Connect IQ app for Garmin watches that reports UV index corrected for your
actual altitude and ground surface, and tracks cumulative erythemal dose against
a personalised MED.

**Status:** v0 — toolchain smoke test. Target: epix Pro (Gen 2) 47 mm.

## Start here

- **[docs/TOOLCHAIN.md](docs/TOOLCHAIN.md)** — SDK install, developer key,
  building, and how to sideload onto the watch over USB.
- **[docs/STATE.md](docs/STATE.md)** — decisions made, approaches rejected, and
  what is still open.
- **Build plan** — https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

## What v0 does

Fetches the current UV index from Open-Meteo for your GPS position and displays
it alongside a diagnostic stack: position and whether the fix was cached,
barometric altitude and how far it differs from the API's grid elevation, and
the HTTP result.

It is deliberately ugly. Its job is to prove every external dependency works and
to name the one that did not.

## Layout

```
manifest.xml              Device target, permissions, app id
monkey.jungle             Build config
source/
  UvGuardApp.mc           AppBase - entry point, glance registration
  UvMainView.mc           The diagnostic screen
  UvGlanceView.mc         Glance summary, reads persisted state only
  UvClient.mc             Open-Meteo fetch, position and altitude
  UvState.mc              Shared state, storage-backed
  UvScale.mc              WHO risk bands and colours, glance-scoped
resources/
  strings/, drawables/
```

## Things that are settled

These are load-bearing. `CLAUDE.md` has the full list with reasoning.

- No Garmin watch has a UV sensor. All UV data comes from the network.
- Same-day erythemal dose is strictly additive. A gauge that ticks down in the
  shade would be biologically wrong.
- Dose accumulates only during tracked sun time, never blindly against the clock.
- Background services cannot vibrate or play a tone. Data fields can, which is
  why the data field is the primary alerting surface.
