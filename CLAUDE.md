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
6. **This sandbox cannot reach Garmin or Open-Meteo.** Egress is an *allowlist*,
   not a blocklist on a few named hosts. `developer.garmin.com`,
   `apps.garmin.com`, `api.open-meteo.com` and `air-quality-api.open-meteo.com`
   all get `403 Forbidden` at the CONNECT stage - and so does `example.com`.
   Trying a different hostname is never the workaround. `WebSearch` does work,
   on a separate egress path, so documentation can be checked even though APIs
   cannot be called. Source is written here; compiling, simulating and
   sideloading happen on the user's machine.
7. **Never ask the user for a Fitzpatrick numeral.** Self-reported skin type has
   no significant correlation with measured MED, and ~42% of people cannot be
   classified from the standard questions at all. Ask the two behavioural
   questions, offer "not sure", seed conservatively, show burn time as a range,
   and calibrate from whether the user actually burned. Personal MED is a stored
   moving value, not a lookup from a type.

## Conventions

- Monkey C, Connect IQ SDK. Language and API level confirmed in `docs/STATE.md`.
- Background service memory is the tightest budget in the project (commonly 32 KB).
  Parse and discard; never hold a whole API response.
- Layouts are resolution-relative, never pixel-hardcoded, so added devices stay cheap.
- **Local variable types are inferred.** `var x as Float;` is a compile error.
  Annotate fields, parameters and return types; never locals.
- A two-part null test (`if (a != null && a.b != null)`) does not narrow `a.b`
  for the next line. Read the value into a local and test that.
- **A module member cannot be `private`.** Access modifiers are class-only. A
  `private` inside a `module` block fails the parse, and because the parser then
  abandons the whole module body, the *next* function reports as a second error
  that looks unrelated ("extraneous input 'private' expecting 'class',
  'module', ..."). Two errors, one cause. Module helpers are simply public.
- **`(:background)` is a declaration, not a note.** A single `(:background)`
  anywhere in the project makes it a background application, and the build then
  fails with "The 'Background' permission is required in the manifest file"
  until `<iq:uses-permission id="Background"/>` is added. Never annotate for a
  build scope that does not exist yet - add the annotation, the service and the
  permission in the same change.
- `Any` sits **above** `Object`. Dictionary and Array lookups yield `Any`, which
  therefore cannot be passed to a parameter declared `Object`. `Any` also has no
  writable name (`as Any` gives "Cannot resolve type"), while strict mode demands
  every parameter be typed. For a function that inspects an unknown value at
  runtime, the resolution is `(:typecheck(false))` on that function alone.
- Health-adjacent output is presented as an estimate with a margin, never as a
  precise threshold. MED varies widely within every Fitzpatrick type, and the
  type itself is an unreliable self-report.
- Matt's stated type II is a starting assumption, not a settled fact. Do not
  treat it as calibrated.

## Working style

Matt is technically fluent but does not write code. Explain reasoning in plain
language, not just conclusions. Do not soften findings. Factcheck rather than
assume — especially anything about Garmin platform behaviour, which changes.
