# Review brief: UV Tracker v1a

You are reading this because a second pair of eyes is worth more than another
round of the same pair. The code below was written by one model across several
sessions, reviewed by that same model, and tested by its author. Every problem
found in the last two days was found either by a websearch or by the human
using the thing. None were found by the author re-reading its own work.

So the job is not to check the spelling. It is to find what someone who built
this could not see.

---

## What I want back

A written review. Findings, not a rewrite - do not refactor the app.

Rank what you find by how much it would matter to someone wearing this watch
on a ski hill, not by how interesting it is. Three real problems beat thirty
observations.

Four kinds of finding are in scope, roughly in order of value:

1. **The physics is wrong, or wrong enough to matter.** The numbers below are
   my working, and several are assumptions I could not verify.
2. **Assumption blindness.** Something designed from the inside that does not
   survive contact with how people actually use a watch. Two recent examples of
   exactly this are in "What I already got wrong" below - they are the genre.
3. **Correctness bugs.** Null paths, the series-ingest logic, storage
   round-tripping, the freshness state machine.
4. **Dishonest interface.** Anywhere the screen claims more precision than the
   model has, or where two different situations look the same.

Where you disagree with something I settled, say so and say why. Nothing here
is closed. I have marked my confidence in each piece; the thin ones are thin
and I would rather hear it now than after someone trusts a number.

---

## What the app is

A Connect IQ watch app for the Garmin epix Pro (Gen 2) 47mm. It reports the UV
index **corrected for where the wearer is actually standing**, and will later
track cumulative erythemal dose against a personal MED.

The premise is a gap in every other UV app: a server knows the sky - cloud,
ozone, aerosol - but it does not know you are 900 m above the mean elevation of
its 40 km grid cell, standing on snow. Those two facts are the watch's, and
they compound. A skier at 2,500 m on fresh snow is taking substantially more
erythemal dose than the published index for that valley says.

The wearer is one person: technically fluent, does not write code, and will
actually use this on ski hills and trails. He would rather be told "about
20-30 minutes" than "23 minutes", and he would rather the app under-report than
over-report, because an app that over-reports teaches you to ignore it.

---

## The physical model, and how much I trust each part

```
UVI_eff = UVI_api x (1 + k_alt x (h_watch - h_grid) / 1000) x (1 + f x albedo)
```

| Quantity | Value used | Confidence | Basis |
|---|---|---|---|
| `k_alt` | 0.10 per 1000 m | **Low** | Published erythemal figures run roughly 6-12% per 1000 m depending on site, season, and how much of the light path sits above the aerosol layer. 0.10 is mid-range and errs high. I have not checked whether erring high is right here |
| Fresh snow albedo | 0.85 | Medium | Literature range 0.80-0.90 |
| Old/melting snow | 0.50 | **Low** | Range given as 0.40-0.60; I took the midpoint without checking how fast it decays |
| Dry sand | 0.18 | Medium | Range 0.15-0.20 |
| Concrete/urban | 0.10 | Medium | Range 0.10-0.12 |
| Water | 0.07 | **Low** | Range 0.05-0.10 is the midday figure. Reflectance off water climbs steeply at low sun angles and with glint, and the model ignores that entirely |
| Grass | 0.03 | Medium | Range 0.02-0.05 |
| `f` (openness) | 0.50 / 0.25 / 0.10 | **Low** | Three buckets I invented: open, partly open, enclosed. 0.5 comes from "roughly half your sky is ground on an open snowfield". The other two are guesses with no source |

**Things I am least sure about, in order:**

- **Is the composition right?** Altitude and albedo are applied as independent
  multiplicative factors. That is the standard simplification, but they are not
  actually independent - high-altitude sites are snowier and have thinner
  aerosol paths, and the altitude coefficient may already have some surface
  reflection baked into it depending on how it was measured. Am I
  double-counting?
- **Is `f` a defensible construct at all?** The build plan treats it as "the
  fraction of the reflecting surface in view". That is a plausible-sounding
  quantity that I am not certain corresponds to anything measurable, and a
  wearer choosing between three words is not measuring it either.
- **Clamps.** The altitude delta is clamped to -1500..+4500 m, giving a factor
  of 0.85 to 1.45. The reflected term `f x albedo` is capped at 0.60. The
  *output* is deliberately not clamped, on the reasoning that 12 on a glacier
  really can correct to 24 and clamping would hide exactly the case this app
  exists for. Is that the right call, or is an uncapped output a way to show
  someone a number no instrument would ever read?
- **Display threshold.** A correction term under 2% is not printed, on the
  reasoning that it is inside the model's own error bars. Is 2% the right line,
  or does hiding it mislead differently?

Health-adjacent output is presented as an estimate with a margin, never as a
precise threshold. That is settled and I am confident in it: MED varies widely
within every Fitzpatrick type, and self-reported type has no significant
correlation with measured MED - 42% of people cannot be classified from the
standard questions at all. The app therefore never asks for a Fitzpatrick
numeral. **That constraint is evidence-based; the specific numbers above are
not.** Weigh them differently.

---

## Platform facts, with their evidence

These were established by research or by live testing, not assumed. They are
offered as findings - if you think one is wrong, the evidence is named so you
can check it.

| Fact | How it was established |
|---|---|
| No Garmin watch has a UV sensor. All UV data is from a network API | Product research. Any claim of on-device measurement would be false |
| The ambient light sensor exists in hardware but has never been exposed to Connect IQ | Open developer request since roughly 2020 |
| A background service **cannot write to storage** reliably, and cannot write Application Properties at all | Garmin forums; background processes get their own object-store snapshot. `Background.exit()` is the channel, capped near 8 kB |
| `onBackgroundData()` fires in the **glance** as well as the app | Garmin forums. This is what makes a phone-free glance possible |
| GPS from a background process is unreliable (permission/invocation failures) | Garmin forums. Foreground writes the last-known fix; background reads it |
| Temporal event minimum is 300 s, one registration at a time, and `getServiceDelegate()` must return an **array** or the simulator's manual trigger silently does nothing | Garmin forums |
| `Properties.setValue()` throws `InvalidKeyException` for a key not declared in the settings resources | Garmin docs |
| Open-Meteo's air-quality endpoint serves CAMS erythemal UV at ~40 km; the forecast API's `uv_index` is a GFS approximation | Open-Meteo docs |
| The response carries a top-level `elevation` that varies correctly by location | Verified live: 336 m at Olathe (actual 320-340), 4 m at Bangkok (actual ~2) |
| `timeformat=unixtime` returns GMT epoch seconds; `Time.now().value()` is also UTC | Verified live by catching the hour index advance across an hour boundary |
| App memory budget on this device is **763.6 kB**; v1a peaks at 23.3 kB | Measured in the simulator, 2026-09-22 |
| Glance budget is ~59.9 kB | Measured in the simulator |
| Background budget is **unknown** | Not yet measured. Commonly quoted as 32 kB for this generation |

---

## What v1a contains

Twelve source files, about 1,700 lines. It builds clean and runs.

| File | Job |
|---|---|
| `UvNum.mc` | Runtime narrowing. JSON, storage, properties and menu ids all yield `Any` |
| `UvCorrection.mc` | The formula above. Factors clamped, signed percentages for display |
| `UvForecast.mc` | Cached hourly series: base epoch + step + values, plus the time and place it was fetched for, and the freshness verdict |
| `UvSettings.mc` | Surface albedo and openness, read from `Application.Properties`, clamped on every read |
| `UvSettingsMenu.mc` | On-watch settings pickers |
| `UvState.mc` | Position, altitude, the forecast, request status. Schema-versioned |
| `UvClient.mc` | GPS resolution then the Open-Meteo fetch; ingests the whole series |
| `UvMainView.mc` | Three pages: reading, diagnostics, settings |
| `UvMainDelegate.mc` | Button handling |
| `UvScale.mc` | WHO/ICNIRP risk bands and colours |
| `UvGlanceView.mc` | Glance, reads the cache, applies the same correction |
| `UvGuardApp.mc` | App lifecycle, storage migration |

**Freshness** is judged on age and distance together, because either alone
misleads: a five-minute-old fetch from the last town is not current, and a
six-hour-old fetch from right here is still roughly right. Thresholds are 25 km
/ 100 km against the ~40 km CAMS cell, and 2 h / 12 h against hourly CAMS
updates. **All four numbers are judgement calls I would like checked.**

**Deliberate asymmetry worth understanding before you flag it as an
inconsistency:** GPS *quality* is logged but not gated on for the forecast
fetch, because a last-known fix is perfectly good for picking a 40 km grid
cell. In v2 the same field *will* be gated on, because telling a treadmill from
a road run is a different job with a different answer. Same field, two uses.

---

## What I already got wrong

Both of these are the genre of finding I most want more of. Neither was a
coding error; both were building from the inside.

**The activity gate would have over-counted dose.** The design said dose
accumulates whenever "an outdoor activity is recording". The watch does not
record an outdoor activity - it records a *sport*, and running, cycling,
skiing, rowing, swimming and even surfing all have indoor forms. Offseason
training is largely made of them. A treadmill run at midday would have booked a
full MED against skin that saw no sun. The human caught this, not the author.
It is now inverted: never accumulate by default, accumulate only on positive
evidence of being outdoors.

**The settings page was invisible.** A third page was added with no indicator
that other pages existed, so it was unreachable by anyone who had not read the
commit message. Found in the first minute of use.

---

## Out of scope

- **Dose accumulation, sessions, the data field, SPF/UPF inputs.** All v2.
- **Skin type and personal MED.** Deferred to v2, where something consumes it.
- **Forecast chart, avoid window, burn-time, exposure modes.** All v3.
- **Other devices.** epix Pro 47mm only, deliberately.
- **The background service and the cached refresh.** That is v1b, not yet
  written. Comment on whether v1a's data shapes will *support* it if you see a
  problem, but do not design it.

---

## How work happens here

This sandbox cannot reach Garmin or Open-Meteo - egress is an allowlist and
every external host is refused, including `example.com`. **You cannot compile
or run anything.** `WebSearch` does work, on a separate path, so documentation
can be checked.

The human compiles and tests on his own Windows machine and reports back. That
makes every compile round trip expensive, which is why proposals that will not
compile cost real time rather than none.

Monkey C traps this project has already paid for, so proposals avoid them:

- Local variable types are inferred. `var x as Float;` is a compile error.
  Annotate fields, parameters and return types; never locals.
- A two-part null test does not narrow for the next line. Read into a local and
  test that.
- A module member cannot be `private`. Access modifiers are class-only, and a
  `private` in a module breaks the parse for the whole module body.
- `(:background)` anywhere makes the project a background application and the
  build then fails until the manifest declares the Background permission.
- `Any` sits above `Object`, has no writable name, and strict mode demands
  every parameter be typed. For a function inspecting an unknown runtime value
  the resolution is `(:typecheck(false))` on that function alone.

## Where to look for more

`docs/STATE.md` is the running log - every decision with its reasoning, and a
rejected-approaches table. The build plan at
`https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17` is the
design authority. Neither is required reading to do this review; the brief
above is meant to stand on its own. They are there if you want to check whether
something was considered.
