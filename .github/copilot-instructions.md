# Project instructions

This repository's authoritative context lives in two files. **Read both before
answering questions about this project:**

- **`CLAUDE.md`** — the hard constraints. These are settled and evidence-backed.
  Do not suggest approaches they rule out.
- **`docs/STATE.md`** — decisions made, approaches already rejected and why, and
  what is still open.

The design authority is the build plan linked from `CLAUDE.md`.

## Constraints most likely to be violated by a confident guess

These have each been researched and settled. Suggesting them again wastes time.

1. **No Garmin watch has a UV sensor.** UV data comes from a network API. There
   is nothing on-device to read.
2. **The ambient light sensor is not exposed to Connect IQ.** The hardware has
   one; the API has never shipped. Sun/shade detection cannot use it.
3. **Same-day erythemal dose does not decay.** It is strictly additive. A gauge
   that ticks down in the shade is biologically wrong.
4. **Background services cannot vibrate or play a tone.**
   `Background.requestApplicationWake()` raising a silent dialog is the only
   attention mechanism they have.
5. **Connect IQ cannot set a system timer or alarm.** It can read the alarm
   count and nothing more.
6. **Connect IQ apps are not assignable hotkey targets** on this watch, and a
   glance cannot be tapped to toggle — input delegates are not invoked during
   glance view.
7. **Never ask a user for a Fitzpatrick numeral.** Self-reported skin type has
   no significant correlation with measured MED.

## Toolchain facts

- Target: epix Pro (Gen 2) 47 mm, **API level 5.2**. SDK 9.2.0.
- `monkeyc` is **not on PATH** by default. The SDK Manager does not add it. This
  does not mean the SDK is missing. It lives under
  `%APPDATA%\Garmin\ConnectIQ\Sdks\<sdk-folder>\bin`.
- The VS Code Monkey C extension locates the SDK itself and does not need PATH.
  Build through the extension, not a terminal.
