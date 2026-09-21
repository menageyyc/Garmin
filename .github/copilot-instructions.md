# Project instructions

## Precedence

`CLAUDE.md` and `docs/STATE.md` are the authority on this project. They record
decisions made with Claude that were researched against primary sources and are
settled. **Defer to them.**

- Do not contradict a documented decision, and do not work around one.
- Do not re-suggest an approach listed under "Rejected approaches" in
  `docs/STATE.md`. Each was investigated and ruled out for a recorded reason.
- If you believe a documented decision is wrong, **say so to the user with your
  evidence rather than acting against it.** Disagreement is welcome; silent
  divergence is not.
- Garmin platform behaviour changes often and is easy to get wrong from memory.
  Verify against current sources or say you are unsure. Do not assume.

A failing command is evidence about that command, not proof of its most obvious
cause. Check before concluding — see the toolchain facts below for two cases
where the obvious inference is wrong.

## Where the context lives

**Read both before answering questions about this project:**

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
- `monkeyc` is **not on PATH** by default. The SDK Manager does not add it. A
  failing `monkeyc` command does **not** mean the SDK is missing. It lives under
  `%APPDATA%\Garmin\ConnectIQ\Sdks\<sdk-folder>\bin`.
- The VS Code Monkey C extension locates the SDK itself and does not need PATH.
  Build through the extension, not a terminal.
- **The toolchain requires Java.** The compiler and language server are Java
  programs. `spawn java ENOENT` means no JVM on PATH, not a broken SDK.
- Verify the setup with `Monkey C: Verify Installation` in VS Code, never with a
  terminal command.
