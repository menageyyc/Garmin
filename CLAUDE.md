# Garmin UV Tracker

A Connect IQ app for Garmin watches that reports UV index corrected for the wearer's
actual altitude and ground surface, and tracks cumulative erythemal dose against a
personalised MED.

**Target device:** Epix Pro (Gen 2). Other devices deliberately deferred.

## Start here

Every session should read `docs/STATE.md` before doing anything. It carries the
current phase, decisions already made, and what is in flight.

The shared build plan lives at:
https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

That doc is the design authority. `docs/STATE.md` is the running log. When a decision
changes, update both.

## Hard constraints

These are settled. Do not relitigate them without a reason recorded in `docs/STATE.md`.

1. **No Garmin watch has a UV sensor.** All UV data comes from a network API.
   Any claim of on-device UV measurement is false.
2. **The ambient light sensor is not exposed to Connect IQ.** It exists in the
   hardware; the API has never shipped. Sun/shade detection cannot use it.
3. **Same-day erythemal dose does not decay.** It is strictly additive. Shade stops
   accumulation, it does not reverse it. A gauge that ticks down is biologically
   wrong and must not be built.
4. **Dose accumulates only during tracked sun time** — an outdoor activity recording,
   or a manually started sun session. Never integrate blindly against the solar clock.
5. **Open-Meteo, not OpenUV.** An embedded API key in a Connect IQ app is extractable.
6. **This sandbox cannot reach Garmin or Open-Meteo.** Egress policy blocks
   `developer.garmin.com`, `apps.garmin.com` and `api.open-meteo.com`. Source is
   written here; compiling, simulating and sideloading happen on the user's machine.

## Conventions

- Monkey C, Connect IQ SDK. Language and API level confirmed in `docs/STATE.md`.
- Background service memory is the tightest budget in the project (commonly 32 KB).
  Parse and discard; never hold a whole API response.
- Layouts are resolution-relative, never pixel-hardcoded, so added devices stay cheap.
- Health-adjacent output is presented as an estimate with a margin, never as a
  precise threshold. MED varies widely within every Fitzpatrick type.

## Working style

Matt is technically fluent but does not write code. Explain reasoning in plain
language, not just conclusions. Do not soften findings. Factcheck rather than
assume — especially anything about Garmin platform behaviour, which changes.
