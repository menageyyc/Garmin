# Project state

Running log. Newest entries at the top of each section. Update this whenever a
decision is made or a phase moves.

**Build plan (design authority):**
https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

---

## RESUMING? READ THIS FIRST

**v0 AND v1a ARE BOTH COMPLETE AND CONFIRMED RUNNING** in the simulator on
2026-09-22.

**UPDATED 2026-09-23 (latest session): v1c IS CLOSED. The cell height is
CONFIRMED WORKING** in the simulator: the app computes the 0.4 degree UV cell
from its own position (`cell=51.20,-115.60` at both Sunshine positions,
`51.20,-114.00` at Calgary, exactly as predicted), averages 49 Elevation API
heights across it (2,060 m and 1,101 m), and caches it. The one Problems-panel
item was an unreachable null test in `UvSense.mc`, removed (**that one-line
change is not yet compiled**; the next build confirms it). Question 25's figures
are confirmed on screen.

**v1b IS WRITTEN, NOT COMPILED** (2026-09-23, same session). Matt decided
the four design questions: refresh every 3 h, the background fetches a new
cell's height itself, data returns through `Background.exit()`, and
`uv_index_clear_sky` is fetched, stored and shown on the reading page.

**Next session:** Matt runs "Testing v1b" in TOOLCHAIN.md and pastes the
compile errors (likely - first background build) or the console. The single
most important number is the `mem=used/total` on the `BG UV OK` line: the
background memory budget, never measured. The optional UV grid test is step
5 of that section.

See the last two session log entries. The one before last corrects a fact
this file treated as settled since 2026-09-22 (Storage writes from the
background).

See the last session log entry.

The v1c-before-v1b order was not optional: the review showed v1a's position,
altitude and freshness logic is what v1b would be built on, and it was wrong.

1. **v1c** - the correction pass from `docs/REVIEW-v1a-findings.md`. Built
   and running 2026-09-23; cell height confirmed the same day. **Closed.**
2. **v1b** - the background service, the cached refresh, and the glance
   rewrite. **Read the 2026-09-22 session log entry on the background
   architecture before starting it, and then the last entry in this file,
   which corrects one of its three facts.** Established 2026-09-22:
   `onBackgroundData()` fires in the glance too, and GPS from a background
   process is unreliable. Also stated then, and **wrong as stated**: "a
   background service cannot write storage". Garmin's Storage documentation
   says background processes can write `Application.Storage` from API 3.2
   (epix Pro is 5.2). `Application.Properties` still cannot be written from
   the background. Whether v1b uses that is a design decision, not yet made.
   **The diagram's "every 30 min" is also wrong** (CAMS updates twice a day
   - review finding 7) and is to be corrected when v1b is designed.

**What v1a proved, live:** three pages with a page indicator, on-watch settings
pickers, `HTTP 200`, `idx 15/48` (so `forecast_days=2` took), correct grid
elevation, UTC alignment holding on a two-day series, and fresh snow on an open
piste reading `+42% fresh snow`. `Menu2`, `Application.Properties`,
`catch (e)` and `MenuItem`'s four-argument constructor are all now exercised.

**Memory, measured:** app budget **763.6 kB**, v1a peaks at **23.3 kB** (3%).
Glance budget ~59.9 kB. **The background budget is still unknown and is the
only one that constrains anything.**

Two v0 runs settled the data source:

| | Olathe, KS (night) | Bangkok (solar noon) |
|---|---|---|
| UV | `0.0` LOW, green | `9.5` VERY HIGH, red |
| Position | `38.86, -94.80 (cached)` | `13.76, 100.50 (cached)` |
| Grid elevation | 336 m (actual 320-340) | 4 m (actual ~2) |
| HTTP | `200 OK` | `200 OK` |

**Do not re-open any of this:**
- The CAMS air-quality endpoint returns UV to a Connect IQ client. `BASE_URL`
  stays as it is; the GFS fallback is not needed
- The response carries a top-level `elevation`, and it varies correctly by
  location - 336 m vs 4 m is not a constant or a parse artifact. v1's altitude
  correction has a real baseline
- Both `asFloat` branches are exercised: integer `0` and genuine float `9.5`
- Colour bands work at both ends of the range tested
- The measured-font layout holds; no collision between the number and the band

**No loose ends. The UTC alignment is CONFIRMED**, and by better evidence than
a single sample - consecutive runs caught `currentHourIndex` crossing an hour
boundary:

```
idx=4/24 slot+3177s
idx=4/24 slot+3577s     <- 23 s before the hour rolls
idx=5/24 slot+50s       <- index advanced, slot reset. correct.
idx=5/24 slot+707s      <- Bangkok, 05:11:47 UTC, index 5 = 05:00 UTC
```

Every value inside 0-3599, and the index advanced exactly when it should.
`currentHourIndex` is right. Do not re-test this.

**Simulator facts, all learned the hard way on 2026-09-22:**
- **Settings → Glance Launch Mode → Launch in Normal Mode.** It defaults to the
  glance, which renders correctly and then does nothing, because the glance
  never fetches. Small left-aligned text and `~6.8/59.9kB` memory = glance
- **Settings → Set Position** is ONE field taking both numbers as a
  comma-separated decimal-degrees string: `13.756331, 100.501765`. Anything
  else draws "Please enter position in latitude, longitude format in degrees"
- Default position is Olathe, Kansas (`38.856147, -94.800953`), returned by
  `Position.getInfo()` as a cached fix. A fetch works with no position set
- **Altitude is a FIXED simulator constant of `-18 m`.** It is not derived from
  the simulated position - it read `-18 m` identically at Olathe and at
  Bangkok. It is not Calgary, not Bangkok, not anywhere. So the `vs grid`
  figures on screen are correct arithmetic over a fake input: they demonstrate
  the mechanism, not real physics. On the watch the barometer supplies the real
  value. Use FIT playback if a realistic altitude is ever needed in the sim
- **Stop any running debug session before F5.** F5 with a session already live
  does not rebuild and the simulator silently serves the stale `.prg`
- The build Terminal keeps historical scrollback. Old `19 -> 3 -> 2 -> 2 -> 0`
  errors in it are not current
- `System.println` goes to the **Debug Console** tab in VS Code, not Terminal
- **Memory is in the simulator: File -> View Memory.** Peak Memory is the
  number that matters, not the instantaneous one
- **`M` on the keyboard opens the app's menu** - `onMenu()` does fire on this
  device. On real hardware MENU is a long press of UP, still unverified
- The Settings menu group (Color Mode, Glance Launch Mode, Night Mode...) is
  **greyed out when no app is loaded**. A failed build looks like a broken menu
- **Stale-binary tell:** the hint line at the bottom is per-page and short
  (`START refresh` / `DOWN for settings` / `START to change`), and there are
  three page dots below it. If it reads `START refresh  MENU set` with the last
  letter clipped off the screen edge, or there are no dots, the simulator is
  serving a pre-2026-09-22 `.prg`. Stop the debug session before F5
- A **blue triangle on black is not this app** - the launcher icon is an orange
  sun. That is the simulator outside the app, usually after BACK from the
  reading page, which exits by design. F5 relaunches

**Do not re-litigate** anything in `CLAUDE.md`'s hard constraints or the
"Rejected approaches" table below. Each was researched against primary sources
and cost real time to establish. (This does not apply to a review session
working from `docs/REVIEW-BRIEF-v1a.md` - that brief deliberately opens the
settled decisions to challenge, and says which ones rest on thin evidence.)

**Working with Matt:** technically fluent but does not write code. Explain
reasoning in plain language. He builds and tests on his own Windows machine -
Claude's sandbox reaches nothing external except `WebSearch`. He pulls by
double-clicking `update.bat`. **Push to the default branch
`claude/garmin-uv-tracking-app-7y6gk6`** - that is what his clone tracks, and
pushing elsewhere means he never receives the work.

---

## Current phase

**v1a and v1c COMPLETE** (v1c closed 2026-09-23). Builds clean and runs on epix Pro (Gen 2) 47mm / quatix 7 Pro
(5.2.0). The reading page shows UV corrected for altitude and surface with the
API's own figure beneath it; the hourly series is cached with the time and
place it was fetched for, so a failed fetch degrades to "two hours old" rather
than blanking; surface and surroundings are settable on the watch and from the
phone; three pages with a page indicator, and BACK returns to the reading page
rather than quitting.

**The cold review is done: `docs/REVIEW-v1a-findings.md`.** Read it before
v1b. Its top four findings change v1b's inputs: the `elevation` field is
probably the point terrain height rather than the cell mean (one simulator test
decides it), CAMS already applies a snow albedo so the app's +42% double
counts, position and altitude are only sampled when a fetch starts so the
distance check can never fire, and a real watch's cached fix is of unknown age.

**2026-09-23: the review has been verified, and v1c written** (see that day's
two session log entries). v1b waits for v1c, because findings 3, 4, 7 and 10
change what v1b is built on.

**2026-09-23: v1c closed.** The cell-height re-test passed on every point.
Question 25's figures are on screen.

**2026-09-23: v1b written, NOT COMPILED.** Next action: its first build and
"Testing v1b" in TOOLCHAIN.md.

---

## Open questions

| # | Question | Blocks | Status |
|---|---|---|---|
| 1 | Epix Pro size | First build target | **Answered: 47 mm (416x416)** |
| 2 | User's OS | SDK install + signing key | **Answered: Windows** |
| 3 | User's Fitzpatrick type | Default MED seed | **Supplied: type II (~250 J/m2) - UNRELIABLE self-report, re-derive in settings** |
| 4 | Sun detection method | v2 design | **Answered: activity + manual session** |
| 5 | Store-published or sideload-only | Review, health wording, licence | Open |
| 6 | Which API level group does epix Pro sit under? | Target API level | **Answered: API 5.2. SDK 9.2.0 installed** |
| 7 | App + glance + background memory budgets, from local SDK | Architecture limits | **Partly answered:** glance ~59.9 kB, app 763.6 kB (both measured). **Background still unread** - v1b's `BG UV OK` console line prints `mem=used/total` for it ("Testing v1b" step 3) |
| 8 | Exact manifest device ID for epix Pro 47mm | Manifest | **Answered: `epix2pro47mm` is correct - compiler accepted it** |
| 9 | Do CIQ apps appear as assignable hotkey targets on Epix Pro? | Hotkey toggle | **Answered: NO. Not listed. Hotkey design dead** |
| 11 | Can a data field call `Attention.vibrate()` on Epix Pro? | v2 alerting rests on it | Open - test in simulator |
| 12 | Does `air-quality-api.open-meteo.com` return UV as expected? | v0 fetch | **ANSWERED 2026-09-22: YES, fully.** `HTTP 200` at night (Olathe, 0.0) and in daylight (Bangkok, 9.5 VERY HIGH). `elevation` correct and location-varying: 336 m vs 4 m |
| 13 | Is the manifest product id `epix2pro47mm` correct? | Build target | **Answered: yes** |
| 10 | Does v2 include the 7-day load, or today's gauge alone? | v2 scope | Open |
| 14 | Does the phone-side App Settings editor show both list settings, and does the on-watch MENU route write the same value? | v1a settings | Open - test in simulator |
| 15 | Does `Menu2` + `Menu2InputDelegate` behave as written on API 5.2? | v1a settings | Open - the first build will say |
| 16 | Does `Background.exit()` deliver to `onBackgroundData` in the glance on this device, not only in the app? | v1b glance freshness | Open - forum-reported, unverified here. **Test written 2026-09-23:** "Testing v1b" step 4 |
| 17 | Exact `Activity.SubSport` constant names for the indoor variants (treadmill, spin, lap swim, indoor rowing, elliptical, virtual) | v2 exposure gate | Open - read them off the local SDK's API docs, or let the compiler reject a wrong one |
| 18 | What `currentLocationAccuracy` actually reports indoors on epix Pro, versus outdoors mid-run | v2 exposure gate - this is the whole test | Open - needs a real wrist test, not the simulator |
| 19 | Is the air-quality endpoint's `elevation` the point terrain height (DEM) or the CAMS cell mean, and does `elevation=nan` return the cell mean? | v1c - decides whether the altitude correction exists on a hill | **Answered 2026-09-23 (decision), awaiting compile.** `elevation=nan` returns nothing on this endpoint, because Open-Meteo holds no terrain heights for any CAMS domain (source code read). The app now averages 49 Elevation API heights across the cell named in the response. The new console logs `pointElev=` too, which settles what the default field means for free (the skipped part A). **Tested 2026-09-23:** `pointElev=1687 m` and `2192 m` at the two Sunshine positions (real ~1,660 / ~2,160 m), so the default field IS the point terrain height - finding 1 confirmed. The mean works (49/49 points, 1,993 m); the response's coordinates turned out to name the wrong grid, and the cell is now computed on the watch. **Re-tested 2026-09-23 on the computed cell: passed** - `51.20,-115.60` at both Sunshine positions (2,060 m), `51.20,-114.00` at Calgary (1,101 m), cache hit at the second Sunshine position |
| 20 | Surroundings: drop it, or rework it to scale total UV? | v1c | **Answered 2026-09-23: dropped** |
| 21 | Snow terms: accept ~+15-20% fresh / ~+5-10% old as the increment over CAMS? | v1c | **Answered 2026-09-23: accepted.** Midpoints used: +17.5% / +7.5% |
| 22 | Corrected number: keep one decimal, whole number, or a range? | v1c | **Answered 2026-09-23: one decimal.** Already what v1c does |
| 23 | Situational surface: expire back to grass at local midnight, or after ~12 h? | v1c | **Answered 2026-09-23: local midnight** |
| 25 | Should the non-snow surfaces (sand +9%, concrete +5%, water +3.5%) also shrink? Sand now exceeds old snow. The review's physics - the index is horizontal irradiance, raised by ground-atmosphere multiple scattering over the whole region, not by the patch you stand on - suggests all four overstate the index. They were left at v1a's figures because the review did not challenge them and Matt did not decide it | v1c follow-up | **Answered 2026-09-23: B - shrink them.** Keep all six surfaces; derive smaller, sourced figures for sand, concrete and water (and re-check grass) by the snow logic. **Figures derived and approved 2026-09-23: grass 0, water +1%, concrete +2%, sand +3%** (TEMIS regional-albedo formula over published UV albedos; see that day's last log entry) |
| 24 | Which model does the v2 dose-integrator review pass? | v2 review | Open. Matt moved the project to Opus 5.5 on 2026-09-23 and is inclined to use Opus 5.5 at medium effort rather than Fable 5.1, on published benchmarks. Not yet decided |

---

## Decisions made

| Date | Decision | Reasoning |
|---|---|---|
| 2026-09-21 | Build it — no paid SDK exists | SDK, simulator, compiler, dev account and free-app publishing are all $0. $100/yr + 15% applies only to selling apps |
| 2026-09-21 | Target Epix Pro (Gen 2) first | User's device. Has barometric altimeter and WiFi. Glance device, not widget |
| 2026-09-21 | Open-Meteo as data source | No API key. An embedded key in a CIQ app is extractable and the quota would be drained |
| 2026-09-21 | Dose gauge is monotonic within the day | Erythemal dose is additive per Bunsen-Roscoe. Dark CPDs continue forming after exposure ends. A decaying gauge would be unsafe |
| 2026-09-21 | Sun detection via activity state + manual session only | Ambient light sensor is not exposed to Connect IQ. Under-reporting beats false confidence |
| 2026-09-21 | Altitude + albedo correction done on-watch | The watch's barometer beats CAMS' ~40 km grid elevation; albedo is known only to the wearer |
| 2026-09-21 | Target Epix Pro 47 mm, 416x416 baseline | User's device |
| 2026-09-21 | One hotkey toggles session via toggle-on-launch | App reads state at startup, flips, confirms, exits. Does not waste a second hotkey slot |
| 2026-09-21 | Checkpoint prompt: 30 min at UVI >= 6, else 60 min | Caps worst-case phantom dose at ~1.4 MED for type II. Chosen to bound error, not for comfort |
| 2026-09-21 | Session safety rests on auto-stop, not the prompt | Background services cannot vibrate or beep, so the prompt is silent and unreliable as a nag |
| 2026-09-21 | Three auto-stops: solar elevation < 0, 4h max, activity end | Run without user interaction; kill the overnight worst case |
| 2026-09-21 | SPF derated by Faurschou-Wulf exponential model | SPF_eff = SPF_label^(t/2). Default t = 1 mg/cm2. SPF 50 at typical application delivers ~2.7 |
| 2026-09-21 | UPF applied near face value, derated 30-50% when wet | UPF is a fabric property measured by spectrophotometer; no human application variable |
| 2026-09-21 | Protect / Tan / Vitamin D as explicit modes | The three goals have genuinely conflicting optimal timing |
| 2026-09-21 | Tan mode caps at 0.5-0.75 MED, shows time to cap not time to burn | Burning is counterproductive even cosmetically; peeling sheds the pigment being built |
| 2026-09-21 | Session launched via glance carousel + toggle-on-launch | Hotkey targets exclude CIQ apps; glance input delegates are not invoked during glance view. 2-3 presses |
| 2026-09-21 | Data field moves from v3 to v2 | It is the only surface that can vibrate, and it covers ski/run/paddle - the cases the app exists for |
| 2026-09-21 | Native repeating timer documented as opt-in, not a feature | Clock > Timer > Restart On vibrates and chirps until a button press, but the app can neither start nor stop it |
| 2026-09-21 | Never ask for a Fitzpatrick numeral; ask the two behavioural questions | Self-report has no significant correlation with measured MED; 42% are unclassifiable |
| 2026-09-21 | Personal MED is a stored moving value, calibrated from burn outcomes | The questionnaire only seeds it. Asking "did you burn?" after a session beats any survey |
| 2026-09-21 | Burn time displayed as a range, never a single figure | A precise number from an imprecise input misleads |
| 2026-09-21 | Native short repeating timer recommended for tan mode rotation | 10-15 min. The nag is wanted there, and short sessions bound the can't-stop-it flaw |
| 2026-09-21 | Set minApiLevel to 5.2.0, the device's own level | Stops the compiler rejecting APIs introduced between 3.3 and 5.2. Costs nothing with one device targeted. Lower it in v3 and add `has` checks |
| 2026-09-21 | Target the 5.x-era API surface, not Connect IQ 9 | Epix Pro (Gen 2) is a 2023 device and is not a CIQ 9 device |
| 2026-09-22 | v0 refetches on every show, not only when no reading is cached | The old gate meant the app retried forever while broken and never once it worked - backwards for a build whose only job is exercising the fetch |
| 2026-09-22 | Open-Meteo air-quality endpoint confirmed as the data source | Live `HTTP 200` with a correct grid elevation. No need for the GFS fallback; `BASE_URL` stays as it is |
| 2026-09-22 | Poor GPS quality is logged, not gated on; 0,0 is a hard fail | A last-known fix is fine for a 40 km grid cell. 0,0 is the only case that silently misleads, because Open-Meteo answers for Null Island with a plausible tropical UV over HTTP 200 |
| 2026-09-22 | v1 split into v1a (foreground) and v1b (background + glance) | Adding `(:background)` scoping to the app class is the same class of bug as the glance scoping problem that bit v0. Isolating it means a compile failure names itself instead of hiding in 600 new lines |
| 2026-09-22 | The background service returns data via `Background.exit()`, never by writing storage | A background process gets its own snapshot of the object store, and cannot write Application Properties at all. This **corrects the build plan's architecture diagram**, which draws the service writing to storage directly. **UNDER REVIEW 2026-09-23:** the Properties half holds, but Garmin's Storage docs say a background process CAN write `Application.Storage` from API 3.2, with `onStorageChanged()` to tell the other process. The channel choice is reopened as a v1b design decision; see that day's last log entry |
| 2026-09-22 | The background service reads the last-known position from storage; the foreground writes it | `Position` calls from a background process are reported to fail with permission errors. A 40 km grid cell does not need a fresh fix, and never powering the GPS from the background is also the right battery answer |
| 2026-09-22 | `forecast_days=2`, not 1 | `forecast_days=1` returns the current UTC day, which cuts at 18:00 local in Calgary. About 500 extra bytes buys a cache that survives an evening with no phone, and v3's forward curve needs it anyway |
| 2026-09-22 | A failed fetch leaves the cached reading on screen, marked stale | v0 cleared the reading on every attempt because its only job was exercising the pipe. An app that blanks the moment the phone wanders out of range is worse than one that says "two hours old" |
| 2026-09-22 | An irregular hourly series is a failed fetch, not a degraded mode | Storing base-plus-step instead of a parallel timestamp array halves the storage, but is only safe if the step really is uniform. Verified across the whole array at parse time; refusing loudly beats mis-indexing quietly |
| 2026-09-22 | Surface and surroundings are settable on the watch as well as the phone | They are situational - you change the surface on arriving at the ski hill, not on install. Both routes write the same `Application.Properties` store, so neither shadows the other |
| 2026-09-22 | Skin type deferred from v1 to v2 | Nothing in v1 consumes MED; burn time and dose are v2 and v3. Shipping a setting that changes nothing visible teaches people to ignore the settings screen |
| 2026-09-22 | Storage schema versioned; the first v1 run wipes the v0 store | v0 kept a single number under a different set of keys. There is nothing there worth migrating - it is refetched within seconds - and reading an old key with new expectations is how silent wrongness starts |
| 2026-09-22 | Correction factors are clamped, the resulting UV index is not | Altitude delta is clamped to -1500..+4500 m and reflected fraction to 0.60, because both are products of imprecise inputs. The output is left alone: 12 on a glacier really can correct to 24, and clamping that away would hide the case the app exists for |
| 2026-09-22 | Dose accumulates only on **positive evidence of being outdoors**, never on activity type alone | Matt's catch. The watch records a *sport*, not an outdoor activity. Running, cycling, skiing, rowing, swimming and surfing all have indoor forms, and offseason training is full of them. A treadmill run would have booked a full MED |
| 2026-09-22 | Outdoor test is `Activity.Info.currentLocationAccuracy` during a recorded activity | The receiver is already powered by the activity, so reading its quality is free. This does **not** contradict the "GPS as indoor proxy" rejection - that was about polling GPS continuously as a standalone detector with no activity running |
| 2026-09-22 | Fix quality, not movement | Requiring the position to change would separate a treadmill from a road run, but would also zero out chairlift and belay time - high-altitude, high-albedo exposure, exactly the case the app exists for |
| 2026-09-22 | Indoor sub-sport list suppresses prompts; it never decides to accumulate | An indoor allow-list can never be complete, and anything missing from it would silently over-count. Requiring a positive signal makes an unlisted indoor sport fail closed |
| 2026-09-22 | Three exposure states in the UI, not two | "Counting", "not counting because I cannot confirm you are outdoors", and "indoors" must look different. The build plan already required paused to look different from recovering; this is a third |
| 2026-09-22 | Per-profile "this one is outdoors" setting, default off | Covers the outdoor activity recorded with GPS off, which is otherwise permanently ambiguous. Set once for Trail Run and never thought about again |
| 2026-09-22 | GPS quality is gated on for exposure detection but deliberately NOT for the forecast fetch | Same field, two jobs. A last-known fix is fine for picking a 40 km grid cell; it is useless for telling a treadmill from a road. A future session must not "fix" this inconsistency |
| 2026-09-22 | Fable 5.1 does a review pass when v1a is green, and again at the v2 dose integrator | It is Anthropic's most capable widely released model, for demanding reasoning and long-horizon agentic work. The dose integrator is the health-adjacent maths where being wrong matters to skin |
| 2026-09-23 | v1c (correction pass) comes before v1b | The review showed v1a's position, altitude and freshness logic - what v1b would be built on - was wrong |
| 2026-09-23 | Surroundings setting dropped | It scaled only the reflected term, so "Enclosed: forest" left nearly all forest UV untouched while the wearer believed shade was counted. f is not a measurable quantity for the UV index. The number is for open sky; shade becomes a v2 dose pause |
| 2026-09-23 | Snow is an increment over CAMS: fresh +17.5%, old +7.5% | CAMS already models snow albedo above 2 cm model snow depth. v1a's +42% counted it again, above the whole measured clear-sky effect of 15-25% |
| 2026-09-23 | A surface other than grass resets at local midnight | It is situational, and a setting with no exit was a standing weekday over-report after a ski weekend |
| 2026-09-23 | Position and altitude sampled on every onShow; cached fix over 60 min refused | The distance check could never fire, and a real watch's cached fix is wherever GPS last ran |
| 2026-09-23 | ~~Request `elevation=nan`; on HTTP 400 or unparseable body, retry once without it~~ **SUPERSEDED same day, see next row** | The default `elevation` is the point terrain height, which zeroes the altitude correction on a hill. A refused parameter must not cost a reading |
| 2026-09-23 | Non-snow surfaces shrink by the same logic as snow (question 25, option B); all six surfaces stay | The index rises with the brightness of the whole region, not the patch underfoot, so v1a's albedo x 0.5 overstates sand, concrete and water as it did snow. Keeping the list gives wearers a choice that matches what they see. Matt: had the list been collapsed instead, water should still have been kept, so ground, water and snow are all represented |
| 2026-09-23 | Non-snow surfaces: grass 0, water +1%, concrete +2%, dry sand +3% | TEMIS's f(A) = (1 - 0.25 A_ref)/(1 - 0.25 A) over published erythemal albedos, A_ref = 0.05. The same formula reproduces the measured snow (15-25%) and Salar de Uyuni (+20%) effects. Upper limits: they assume the surface for kilometres around |
| 2026-09-23 | On-screen percentages rounded, not truncated | 0.02 x 100 is 1.9999999 in a 32-bit float; truncated it read +1% and fell under the 2% threshold, so +2% was never shown. Fresh / old snow now read +18% / +8% |
| 2026-09-23 | Grid-cell height = mean of 49 Elevation API heights across the cell the UV response names; once per cell, cached | `elevation=nan` returns nothing: Open-Meteo stores no terrain for CAMS. ECMWF builds model terrain as the mean height over each grid box, so this reproduces the same quantity. The response's `latitude`/`longitude` are documented as the cell centre |
| 2026-09-23 | The CAMS cell is computed on the watch: nearest point of the 0.4 deg cams_global grid, `round((coord - origin) / 0.4)` | Open-Meteo's source: the air-quality request mixes cams_global with a 0.1 deg greenhouse-gas domain, and the response's `latitude`/`longitude` come from the last domain that covers you - the greenhouse grid, which carries no UV. CAMS has no terrain file, so Open-Meteo picks the plain nearest 0.4 deg point. Supersedes "the response's latitude/longitude are the cell centre" in the row above |
| 2026-09-23 | v1b background refresh every 3 hours (decision 1) | CAMS runs twice a day; Open-Meteo's source puts arrival ~8 h after each run, unverified live. 3 h catches a new run within 3 h wherever it lands; 8 fetches a day instead of the plan's 48 |
| 2026-09-23 | The background service fetches a new cell's height itself (decision 2) | Otherwise the glance shows an uncorrected number until the app is opened. A second request inside 30 s, rare because four cells are remembered |
| 2026-09-23 | Background data returns through `Background.exit()`, not a Storage write (decision 3) | Storage writes from the background are documented from API 3.2, but exit() keeps one writer per key (no race with a foreground fetch), avoids a feature with a reported per-device bug, and the payload is under 1 kB of the ~8 kB cap |
| 2026-09-23 | `uv_index_clear_sky` fetched, stored, and shown on the reading page in v1b (decision 4) | Review finding 11: CAMS cloud at 40 km over mountains is the largest error in the chain and fails in the dangerous direction. Shown as "up to X if sky clears", only when 0.5 or more above the corrected number, tinted by its band |
| 2026-09-23 | Cache freshness judged by CAMS cell, not 25 km | Open-Meteo answers every position in a cell with that cell's values. 25 km could cross into a neighbouring cell while still "current" |
| 2026-09-23 | Four cells' heights remembered, not one | The re-test showed a Calgary-Sunshine-Calgary trip re-measuring Calgary. ~100 bytes |
| 2026-09-23 | UV interpolated between hours | Hourly values are instantaneous; the step read was up to 30-50% off on the shoulders |
| 2026-09-23 | Fresh window 6 h, not 2 h | CAMS runs twice a day; a 2 h refetch returns the same numbers |
| 2026-09-23 | `migrate()` moved out of `onStart()` | onStart runs in the background process once v1b exists |
| 2026-09-22 | The Fable brief is written differently from this repo's house style, on purpose | Anthropic's own migration guidance: prompts written for prior models are often too prescriptive on Fable and reduce output quality. CLAUDE.md and this file are deliberately prescriptive, which has served Opus well and would work against Fable |

---

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Ambient light sensor for sun detection | Not exposed to Connect IQ; open request since ~2020, never shipped |
| GPS polled continuously as a standalone indoor/outdoor proxy | Battery cost too high for continuous use. **Note the narrowness of this rejection** - reading `currentLocationAccuracy` *during an activity that already has the receiver on* is free, and as of 2026-09-22 it is the outdoor test. Do not read this row as rejecting that |
| OpenUV API | Requires a key; 50 req/day free tier; key extractable from a published app |
| Dose gauge that recovers in shade | Biologically wrong. Same-day dose does not decay |
| "No phone needed" as a capability claim | False. No Garmin watch has a UV sensor. Caching is what enables offline display |
| Vibrating/audible reminder from the background service | Not possible. `Background.requestApplicationWake()` raising a silent dialog is the only attention mechanism a background service has |
| Hourly checkpoint interval | Too slow at high UV. One forgotten hour at UVI 8 books ~2.9 MED of phantom dose for type II |
| "Tan in the shoulder hours for better efficiency" | Delayed tanning shares a near-identical action spectrum with erythema. Shoulder hours tan you *less*, not more efficiently |
| Applying label SPF at face value | Real-world application is 0.25-0.5x the tested 2 mg/cm2, and the relationship is exponential |
| Hotkey to toggle the session | Connect IQ apps are not assignable hotkey targets on Epix Pro. Confirmed on the device |
| App sets a system timer or alarm | No Connect IQ API exists. The API can read alarm count only |
| Tap the glance to toggle the session | Input delegate methods are not invoked while a glance view is running |
| Concluding the SDK is broken because `spawn java ENOENT` appears | That error means no JVM on PATH. The toolchain is Java-based; install a JDK |
| Concluding the SDK is missing because `monkeyc` fails in a terminal | The SDK Manager does not put its bin folder on PATH. Verify via the VS Code extension instead |
| Native repeating timer as a default in protect mode | The app cannot stop it either, so it keeps buzzing after the session ends. Fine in tan mode, where sessions are short |
| Fitzpatrick roman-numeral dropdown | Produces an authoritative-looking number that predicts almost nothing |
| Concluding the app is broken because the simulator shows `--` and does nothing | The simulator launches the glance by default, and the glance never fetches by design. Settings > Glance Launch Mode > Launch in Normal Mode |
| Gating the fetch on `!hasReading()` | uvIndex is persisted, so one success permanently stopped the app calling the API |
| Failing the fetch on `QUALITY_NOT_AVAILABLE` | Would block the simulator test for no safety gain. The 0,0 guard is what actually prevents a false positive |
| Writing the forecast to storage from the background service | A background process gets its own snapshot of the object store; writes back are unreliable, and Application Properties cannot be written from the background at all. `Background.exit()` is the supported channel, capped near 8 kB. **Reason partly wrong (2026-09-23):** Storage writes from the background are documented as supported from API 3.2. Still not the recommended channel for v1b (one writer per key; a reported per-device bug), but for a different reason than the one given here |
| Calling `Position.getInfo()` inside the background service | Reported to fail with permission and invocation errors from a background process. The foreground writes the last-known fix to storage and the background reads it |
| Storing parallel arrays of timestamps and values | Doubles the storage for a series that is uniformly hourly. Base plus step, with uniformity verified at parse time, costs nothing and cannot drift |
| Loading the setting labels through `Rez` in the glance | A `loadResource` call per draw inside a ~60 kB budget, returning a `Resource` the strict checker will not pass to a `String` parameter. Nine short English strings are cheaper, duplicated deliberately in `settings.xml` |
| Surroundings / openness `f` in the correction | Not a measurable quantity for the UV index, and it only scaled the reflected term, so "enclosed" did not reduce the number. Removed 2026-09-23. Do not bring back a shade setting that scales anything less than the total |
| Snow albedo applied as if CAMS knew nothing of snow | CAMS applies a regional snow albedo itself. The app adds only the local increment |
| `elevation=nan` on the air-quality endpoint | Returns no elevation (tested 2026-09-23). Not a documented air-quality parameter, and Open-Meteo holds no CAMS terrain to return. Issue #1155 was a different bug (a grid flip, fixed in PR #1164) |
| Using the air-quality `elevation` field as the baseline, with "altitude correction unavailable" on hills | It is the terrain height of the exact spot, so it cancels against the barometer wherever the correction matters. Honest, but it switches the headline feature off permanently |
| Forecast API `elevation=nan` with an ECMWF model, as a stand-in for CAMS terrain | Returns the 9 km weather model's terrain, not CAMS's ~40 km terrain. In the Rockies those can differ by hundreds of metres, and it leans on the same undocumented behaviour that just failed |
| A precomputed cell-height table bundled in the app | Needs an offline pipeline Claude's sandbox cannot run, and a global table is ~400,000 cells. The on-watch mean does the same job for one request per cell |
| Identifying the CAMS cell from the response's `latitude`/`longitude` | They are the cell centre of the LAST domain in the request's mix, which outside Europe is the 0.1 deg greenhouse-gas grid and inside Europe the 0.1 deg European grid. Neither carries `uv_index`. Documented as "the grid-cell used", true only for a single-domain request. Found by the first cell-height test, confirmed in `ForecastapiController.swift` / `GenericReaderMixerRaw.swift` |
| Two stacked `popView` calls to leave a submenu | Connect IQ promises nothing about unwinding two views inside one callback. The option delegate updates the parent row's sub-label in place and pops once |

---

## Session log

### 2026-09-21 — Scoping
- Established feasibility and cost. No paid SDK.
- Confirmed egress block on Garmin and Open-Meteo hosts in the Claude sandbox.
- Worked through UV dose accumulation and recovery science; established the
  three-clock model (same-day / recent load / lifetime).
- Confirmed ambient light sensor unavailable, which settles the sun-detection design.
- Created the shared build plan doc and this repo tracking.
- No code written yet.

### 2026-09-21 - Session and exposure design
- Device, OS and skin type settled: Epix Pro 47 mm, Windows, Fitzpatrick II.
- Sun detection confirmed as activity + manual session.
- Found the platform limit on background alerts: no vibration or tone from a
  background service, only a silent `requestApplicationWake()` dialog. Redesigned
  session safety around auto-stop rather than reminders.
- Worked the checkpoint interval from phantom-dose arithmetic rather than comfort.
- Added UPF and SPF protection inputs with the derating asymmetry between them.
- Added Protect / Tan / Vitamin D modes, with the action-spectrum correction that
  lasting tan cannot be meaningfully decoupled from burn risk.
- Still no code written.

### 2026-09-21 - Alerting surfaces resolved
- Hotkey confirmed dead on the device: CIQ apps are not assignable hotkey targets.
- Confirmed no Connect IQ API to set a system timer or alarm.
- Confirmed a glance cannot be tapped to toggle; input delegates are not invoked
  during glance view. Launch path is glance carousel -> select -> toggle-on-launch.
- Found that Garmin's native countdown timer with Restart On does exactly what was
  wanted (persistent vibrate + chirp until acknowledged), but the app can neither
  start nor stop it, so it is opt-in guidance rather than a feature.
- Architectural shift: the data field moves from v3 to v2. It is the only surface
  that can alert, and it covers the activity cases the app exists for.
- Still no code written.

### 2026-09-21 - v0 scaffolded
- Wrote the v0 project: manifest, jungle, five Monkey C source files, resources,
  generated launcher icon.
- v0 is a diagnostic screen: UV index plus position, barometric altitude vs the
  API's grid elevation, and the HTTP result. Designed so a failure names itself.
- Chose Open-Meteo's air-quality endpoint over the forecast API: the former
  serves CAMS erythemal UV, the latter a GFS approximation.
- Caught and fixed a glance scoping bug before it shipped: the glance is its own
  build scope and cannot see the app's in-memory singleton, so shared state is
  storage-backed and the scale helpers are (:glance) annotated.
- Wrote docs/TOOLCHAIN.md for Windows 11, including MTP sideloading.
- NOTHING HAS BEEN COMPILED. No Garmin SDK access from this environment.

### 2026-09-21 - Skin type reconsidered
- Matt asked how a user is supposed to know their Fitzpatrick type. Researched it:
  self-report has NO significant correlation with measured MED, only 41% of people
  are classifiable from the standard questionnaire, and 42% of responses cannot be
  classified at all.
- Redesigned: two behavioural questions instead of a numeral, "not sure" as a
  first-class answer, conservative seed, burn time shown as a range, and
  calibration from actual burn outcomes. Personal MED becomes a moving value.
- Corrected the record: type II was supplied by Matt, not inferred by Claude, but
  it is an unreliable self-report and is no longer recorded as settled.
- Added rotation guidance to tan mode: short repeating native timer, and the
  arithmetic note that alternating sides roughly halve per-site dose while face
  and shoulders take the full amount.

### 2026-09-21 - Platform version corrected
- Matt's SDK Manager screenshot shows API levels up to 6.0. Earlier research in
  this session treated System 7 / API 5.0 as the ceiling; that is now outdated.
- API 6.0 = Connect IQ 9. SDK 9.2.0 shipped June 2026. System 8 exists too.
- CIQ 9 devices are Fenix 8 family, Fenix E, Enduro 3, FR 570/970, Venu 4,
  Venu X1, vivoactive 6, D2 Mach 2 Pro and some Edge units. Epix Pro (Gen 2) is
  NOT among them - it is a 2023 device, probably in the 5.x group.
- Practical consequence: install the newest SDK (it still builds for older API
  levels) but do not reach for CIQ 9 APIs. minApiLevel stays at 3.3.0.
- Noted that the Devices tab installs partially by default - epix Pro 47mm must
  be explicitly installed or neither the simulator nor the compiler can target it.

### 2026-09-21 - Device and SDK confirmed
- epix Pro (Gen 2) 47mm is **API level 5.2**. Listed as "epix Pro (Gen 2) 47mm /
  quatix 7 Pro" - one target covers both products.
- SDK **9.2.0** (June 9 2026) installed and current. All API 6.0 and 5.2 devices
  installed.
- Raised manifest minApiLevel from 3.3.0 to 5.2.0. Rationale recorded above.
- Device id still to confirm from %APPDATA%\Garmin\ConnectIQ\Devices folder names.
- Noted for v3: the AMOLED family shares profiles, so three resolutions (390,
  416, 454) reach six or more products.

### 2026-09-21 - monkeyc PATH gotcha
- Copilot ran `monkeyc -v` in the VS Code terminal, got exit 1, and concluded the
  SDK was not installed. The evidence was right; the inference was wrong.
- Cause: the SDK Manager does not add its bin folder to PATH. The SDK is present
  and current (9.2.0, confirmed). The VS Code extension locates it independently.
- Correct verification is `Monkey C: Verify Installation` in VS Code, not a
  terminal command.
- Added `.github/copilot-instructions.md` as a thin pointer to CLAUDE.md and this
  file, so Copilot stops contradicting settled constraints. Deliberately a
  pointer rather than a copy, to avoid the two files drifting apart.

### 2026-09-21 - Java prerequisite
- Monkey C extension failed with `spawn java ENOENT`. Cause: the compiler and
  language server are Java programs and no JVM was on PATH.
- Fix: Eclipse Temurin JDK 21 (LTS), with "Add to PATH" and "Set JAVA_HOME"
  explicitly enabled in the installer, then a full VS Code restart.
- This was a gap in docs/TOOLCHAIN.md, which listed the SDK but not Java. Added
  as step 0.
- Strengthened .github/copilot-instructions.md with an explicit precedence
  section: CLAUDE.md and docs/STATE.md are authoritative, rejected approaches
  must not be re-suggested, and disagreement should be raised with the user
  rather than acted on silently.

### 2026-09-21 - Developer key clarification
- Matt expected to be issued a developer key during SDK install and was looking
  for one that was never going to appear. The key is self-generated via
  `Monkey C: Generate a Developer Key`, not issued by Garmin.
- `Monkey C: Verify Installation` checks SDK + Java + developer key, so it fails
  until the key is generated. That failure is expected, not a fault.
- Rewrote the TOOLCHAIN.md section to say plainly that you create the key, and to
  scope the "never lose it" warning: irrelevant for sideloading, critical only if
  the app is ever published to the store.

### 2026-09-21 - Non-git workflow added
- Repo confirmed PUBLIC and the working branch is the repo's DEFAULT branch, so
  Download ZIP gets the right code with no auth and no branch switching.
- Added the ZIP route to TOOLCHAIN.md. Matt does not use git; a git tutorial
  before the first successful build is the wrong order of operations.
- Flagged that renaming the developer key file breaks the extension's stored
  path. Matt renamed his to garmindeveloper_key, so the setting needs re-pointing
  via "Select existing developer key".

### 2026-09-21 - Build flow notes
- "Build for Device" asks for an output folder BEFORE the device. TOOLCHAIN.md
  did not mention the output folder step at all; added.
- The folder must be OPEN as a VS Code workspace. Browsing to it in a file dialog
  is not the same thing, and if no workspace is open the device picker never
  appears. Added as the leading warning in step 4.
- ZIP extracts nest one level deep, so the folder to open is
  garmin\Garmin-claude-garmin-uv-tracking-app-7y6gk6\, not garmin\.

### 2026-09-21 - First real build
- Toolchain fully working. The build reached Matt's source and compiled it.
- **Device id `epix2pro47mm` CONFIRMED correct** - the compiler accepted it.
- Two findings, both genuine:
  - WARNING UvGlanceView.mc:20 - unused local `w`. Removed.
  - ERROR UvClient.mc:130 - "Cannot find symbol ':toFloat' on type
    '$.Toybox.Lang.Object'". JSON values come back typed as Object, which has no
    conversion methods. Dictionary.get() and Array indexing both return Object
    regardless of narrowing the container.
- Fixed with explicit asFloat()/asNumber() narrowing helpers rather than blind
  casts, since Open-Meteo returns integers for whole values and floats otherwise
  so both branches are genuinely taken. Also applied to the unixtime comparison
  in currentHourIndex, which had the same latent problem.
- Did NOT lower typeCheckLevel. The strict checker caught real looseness.

### 2026-09-21 - One-click updates
- The ZIP re-download loop was too tedious to sustain; Matt is doing this
  alongside real work and needs updates to be frictionless.
- Switched to a proper clone: `winget install --id Git.Git -e` then VS Code's
  Git: Clone. No login needed, repo is public and the working branch is default.
- Added `update.bat` at the repo root - double-click to pull, with plain-language
  output on success or failure. Deliberately not a script that needs a terminal.
- Tracked `.vscode/settings.json` (gitignore narrowed to allow it) carrying
  git.autofetch so the status bar surfaces new commits, git.confirmSync off, and
  monkeyC.typeCheckLevel Strict so the checker stays strict across machines.
- launch.json deliberately NOT tracked - the extension generates it per machine
  and Matt's working one should not be overwritten.

### 2026-09-21 - v0 RUNS
- Clean compile. App launches in the simulator on epix Pro (Gen 2) 47mm.
- Compile-error sequence was 19 -> 3 -> 2 -> 2 -> 0, all in Claude's code, all
  genuine. Three Monkey C typing rules learned the hard way and recorded in
  CLAUDE.md: locals cannot be annotated, two-part null tests do not narrow, and
  Any is unnameable while sitting above Object.
- Windows Firewall prompts for simulator.exe on first run. Must be allowed or
  makeWebRequest fails in the simulator and looks like an API fault.
- Toolchain fully proven: SDK 9.2.0, Temurin JDK, developer key, device target,
  clone-and-pull workflow via update.bat.

### 2026-09-22 - Runtime path hardened before first live test
- Read the whole v0 source before touching it. Found five defects in the exact
  path about to be tested, one of which could have made the test **lie**.
- **The false positive:** `start()` guarded against a 0,0 fix; `onPosition()`
  did not. A one-shot callback carrying "no fix yet" would have sent the app to
  Null Island, where Open-Meteo returns a plausible tropical UV over HTTP 200.
  That reads as success and proves nothing. Guard added, symmetric with the
  cached path.
- **The fetch gate:** `onShow()` checked `!hasReading()`, and uvIndex is
  persisted, so after one success the app never called the API again. Now
  refetches on every show and clears the in-memory value first so a stale
  number cannot sit on screen looking fresh. Storage is untouched, so the
  glance keeps its last good reading.
- **Added a retry:** `UvMainDelegate`, START refetches in place. The test loop
  was otherwise "restart the app" every time.
- **Added success logging.** Three small lines on a round screen is a poor
  channel for settling question 12. The console now carries the fix and its
  quality, the altitude, the outgoing request, and on success the UV value,
  grid elevation, series index and offset into the hour slot.
- **Bounded the GPS wait.** A one-shot that never completed left
  `requestInFlight` true forever - "..." on screen, no error, indistinguishable
  from still trying. 45 s timeout, then an explicit failure.
- Minor: the cached-fix path now falls back to GPS altitude the way
  `onPosition` already did; the third diagnostic line distinguishes "Fetching..."
  from "No request yet".
- **Verified the Open-Meteo contract from documentation** (WebSearch reaches the
  network even though curl and WebFetch do not). `uv_index` is a valid hourly
  variable on the air-quality endpoint and is CAMS-sourced; the response does
  carry a top-level `elevation`; `forecast_days` accepts 0-7, default 5; and
  `timeformat=unixtime` returns GMT+0 epoch seconds against a default
  `timezone=GMT`. `Time.now().value()` is also UTC, so `currentHourIndex` is
  comparing like with like. Every assumption in the client holds on paper.
- **Corrected two documentation errors that would have cost simulator time.**
  The position menu is **Settings → Set Position**, not the Simulation menu -
  both STATE.md and TOOLCHAIN.md said the latter. And
  `Activity.getActivityInfo()` is only populated while data is generated or
  replayed, so `No altitude` is the *expected* simulator result from Set
  Position alone. TOOLCHAIN.md had been priming the reader to treat that line
  as the one to watch, which would have looked like a barometer failure.
- Corrected CLAUDE.md constraint 6: sandbox egress is an allowlist, not a block
  on three named hosts. `example.com` is refused the same way. There is no
  hostname workaround, and the GFS fallback is equally untestable from here.
- **v1 note, not acted on:** `forecast_days=1` returns the current *UTC* day,
  which cuts at 18:00 local in Calgary. Self-consistent for "now" in v0, but
  v1's forward-looking burn-time curve will need `forecast_days=2`.
- **NOT COMPILED.** No Garmin SDK in this environment. Every change here is
  unverified against the compiler.

### 2026-09-22 - The hardening compiled, and the glance-launch gotcha
- **The 39a42c5 changes compile clean.** Problems panel empty and the app runs
  in the simulator, which it could not do if the build had failed. `Timer`,
  `Position.QUALITY_*` and `BehaviorDelegate` were the new API surface and all
  three are fine. That was the open risk from the previous entry; it is closed.
- **Found why the simulator appeared dead:** it launches the **glance**, not the
  app. The glance renders correctly and then does nothing, because by design it
  never fetches - it only shows what the app already persisted. So `--` and no
  activity is correct glance behaviour, not a fault.
- Tells: small left-aligned `UV` / `--` near the top, and a memory readout
  around `6.8/59.9kB`, which is a glance-sized budget rather than a watch-app's.
- Fix is in the simulator's own menu bar, not VS Code:
  **Settings → Glance Launch Mode → Launch in Normal Mode**.
- Recorded in TOOLCHAIN.md with a side-by-side table for telling the two apart.
- Separately: the empty Chat/Sessions panel in VS Code is not a fault either.
  Claude sessions run on Anthropic infrastructure, not inside the editor, so
  that panel will never list this conversation. There is no connection between
  VS Code and Claude to re-establish; GitHub is the only channel.

### 2026-09-22 - Old build on screen, and two corrections
- Matt reached the app view. The screen showed `No position`, `-18 m`,
  `No request yet`. That combination is **impossible in the current code**:
  altitude is only read inside `UvClient.start()`, which sets
  `requestInFlight` true, and the new third line renders that as `Fetching...`.
  Only the pre-39a42c5 build, which had no `Fetching...` branch, prints
  `No request yet` while altitude is populated. There was also no
  `START = retry` line. Diagnosis: a debug session left running from before the
  pull, so F5 never rebuilt and the simulator kept the stale .prg.
- **Version tells added to the triage:** the current build says `Fetching...`
  rather than `No request yet` during a request, and draws `START = retry` at
  the bottom. Absence of either means a stale binary, not a code fault.
- **Correction: altitude does work in the simulator.** The previous entry
  predicted `No altitude` from Set Position alone, reasoning from forum reports
  that `Activity.getActivityInfo()` is only populated during data playback.
  Observed behaviour contradicts that - it returns the simulator default of
  about -18 m with nothing playing. Both docs corrected.
- **Fixed a real layout collision.** `FONT_NUMBER_HOT` at `h * 0.20` overruns
  the band label at `h * 0.42` on a 416 px screen, so the big number drew
  straight through `UV INDEX`. The stack now measures `getFontHeight()` and
  flows downward from it, which also holds for the other epix Pro sizes instead
  of needing per-resolution fractions.

### 2026-09-22 - THE PIPE WORKS. Question 12 answered
- `HTTP 200 OK` in the simulator. **The single largest unverified assumption in
  the project is now settled.** The CAMS air-quality endpoint returns UV to a
  Connect IQ client exactly as designed. The GFS fallback is not needed and
  `BASE_URL` stays as it is.
- **`elevation` is returned, and it is right.** Screen read `-18 m  -354 vs
  grid`, so the API supplied 336 m. Olathe, Kansas sits at roughly 320-340 m.
  That was verified from documentation earlier today; it is now verified live,
  and it means v1's altitude correction has a real baseline to work against.
- **The simulator has a default position: 38.86, -94.80** - Olathe, Kansas,
  Garmin's own HQ. `Position.getInfo()` returns it as a cached fix with no
  `Set Position` needed, which is why the fix reads `(cached)` and the one-shot
  path never ran. Earlier guidance in this file implied a position had to be set
  before anything would happen; that is not so.
- **My changes compiled first time.** Builds 6 and 7 in the terminal log are
  the new code; builds 1-5 are the historical 19 -> 3 -> 2 -> 2 -> 0 sequence
  from the previous session, still in the scrollback. `Timer`,
  `Position.QUALITY_*` and `BehaviorDelegate` were the untested surface and all
  three were clean.
- **One genuine regression, caught by the compiler.** Assigning the client to a
  local and calling `start()` on that left `_client` write-only, hence
  "Member variable '_client' is not used". Fixed by giving UvClient a `cancel()`
  and calling it on the previous client, which is both a real read and a real
  cleanup. Deleting the field instead would have risked the client being
  collected while a callback was still registered against it.
- **What UV 0.0 does and does not prove.** It was about 23:30 local in Olathe,
  so 0.0 is correct - but every night hour returns 0.0, so a wrong hour index
  would look identical. The UTC alignment in `currentHourIndex` is NOT yet
  confirmed. Needs a daylight position and the `slot+Ns` figure from the
  console.

### 2026-09-22 - v0 COMPLETE
- Bangkok at solar noon: **UV 9.5, VERY HIGH, red, `HTTP 200 OK`,
  `13.76, 100.50 (cached)`, `-18 m  -22 vs grid`.** Everything v0 was built to
  prove is now proven live.
- **Grid elevation varies correctly by location.** Olathe implied 336 m against
  an actual 320-340 m; Bangkok implied 4 m against an actual ~2 m. Two very
  different values, both right, which rules out a constant or a parse artifact
  and gives v1's altitude correction a real baseline.
- **Both `asFloat` branches exercised.** Olathe's `0.0` almost certainly arrived
  as integer `0` (the `Lang.Number` branch); Bangkok's `9.5` is a genuine float.
  The dual-branch narrowing written on 2026-09-21 was justified.
- **Colour bands confirmed at both ends tested** - green/LOW at 0.0, red/VERY
  HIGH at 9.5, matching the WHO thresholds in `UvScale`.
- **The measured-font layout holds.** No collision between the number and the
  band label at either a one-character or three-character reading.
- **UTC alignment: gross error ruled out, small offset not.** At 05:11 UTC the
  series index is 5, which is 12:00 Bangkok local - solar noon - and a
  near-peak 9.5 is exactly what that index should carry. But the UV curve is
  flat within an hour or two of noon, so a +/-1-2 hour offset would look the
  same. `slot+Ns` from the Debug Console remains unread and should be checked
  before v1 uses the hour index for burn-time estimates. Expected ~660s.
- Nothing in v0 is outstanding beyond that one console line. **Next session
  starts v1.**

### 2026-09-22 - Console read. v0 closed with no loose ends
- **UTC alignment CONFIRMED by an hour-boundary crossing.** Consecutive runs
  logged `idx=4 slot+3177s`, `idx=4 slot+3577s`, then `idx=5 slot+50s`. The
  index advanced exactly at the roll and the slot reset - 73 s of wall clock
  between the last two runs, with the boundary in between. Every value inside
  0-3599. Stronger than any single reading could be. `currentHourIndex` is
  correct; this does not need re-testing.
- **The 45 s GPS timeout earned its place on the first run.** Console shows
  `No usable cached fix; acquiring one-shot GPS` then `UV fetch failed: GPS
  timed out (code none)`. Without it that run would have sat on "..." forever
  with no error, which is precisely the failure mode it was added to kill.
- **`quality=LAST_KNOWN` on every single fetch.** This vindicates the
  2026-09-22 decision to log GPS quality rather than gate on it. Had the client
  refused anything below USABLE, every fetch in the simulator would have
  failed, and the endpoint would still be unverified.
- **The `-18 m` altitude is a fixed simulator constant, not position-derived.**
  It read identically at Olathe and Bangkok. It is not Calgary's ~1045 m, not
  Bangkok's ~2 m, not anywhere's. The `vs grid` figures are therefore correct
  arithmetic over a fake input - they prove the mechanism works, not the
  physics. The real barometer supplies the real value on the watch.
- **v1 note on where the altitude correction actually earns its keep:** in a
  city the watch altitude and the CAMS cell mean are close, so the delta is
  near zero. It matters on ski hills and mountain trails, where you sit well
  above a ~40 km cell average - exactly the cases this app exists for.

### 2026-09-22 - v1a written. Three platform facts corrected the architecture
- Read STATE.md, TOOLCHAIN.md, CLAUDE.md, all seven v0 source files and the
  whole build plan before touching anything, then factchecked the Connect IQ
  behaviour v1 rests on. **Three of the assumptions in the build plan's
  architecture diagram are wrong**, and all three would have been found the
  expensive way, mid-v1b, with a background service that silently did nothing.
- **A background service cannot write to storage.** The diagram draws
  `Background service -> Storage`. A background process gets its own snapshot
  of the object store; experienced Connect IQ developers read from storage in
  the background and never write to it, and Application **Properties** cannot
  be written from the background at all. The supported channel is
  `Background.exit(payload)` -> `AppBase.onBackgroundData()`, capped at
  roughly **8 kB**.
- **The good news that falls out of that:** `onBackgroundData()` fires in the
  **glance** as well as the app, so the glance can take delivery of a fresh
  forecast and persist it. That is what "useful with no phone in sight"
  actually needs, and it survives the correction above.
- **GPS from a background process is unreliable** - reported permission and
  invocation failures even with the manifest right. v1b will read the
  last-known fix from storage, written by the foreground. That is also the
  right battery answer: the background never powers the receiver.
- **Temporal events:** minimum interval is 300 seconds, only one registration
  at a time, and `getServiceDelegate()` must return an **array** or the
  simulator's manual trigger does not call `onTemporalEvent` at all. That last
  one would have cost an evening chasing a service that looked dead.
- **`Properties.setValue()` throws `InvalidKeyException`** for a key not
  declared in the settings resources, so every key the app writes must appear
  in `properties.xml` even if only the app ever touches it.
- **The simulator's own App Settings Editor ignores `listEntry` values** when
  opened from its File menu - a long-standing bug. Use the IDE-side editor.
  Every setting in v1a is a list, so this matters immediately.

**What v1a actually contains**

| File | Job |
|---|---|
| `UvNum.mc` | Runtime narrowing in one place. JSON, storage, properties and menu ids all hand back `Any` |
| `UvCorrection.mc` | The formula. Altitude and albedo factors, each clamped, plus signed percentages for the screen |
| `UvForecast.mc` | The cached hourly series: base epoch + step + values, the fetch position and time, and the freshness verdict |
| `UvSettings.mc` | Surface albedo and openness fraction, read from `Application.Properties`, clamped on every read |
| `UvSettingsMenu.mc` | The on-watch MENU route into both settings |
| `UvState.mc` | Rewritten around the forecast. Schema versioned; the first v1 run wipes the v0 store |
| `UvClient.mc` | Rewritten `onResponse` - ingests the whole series instead of one value. GPS logic, timeout and the 0,0 guard are untouched, because they are proven |
| `UvMainView.mc` | Two pages. Reading first, diagnostics behind DOWN |
| `resources/settings/` | `properties.xml` and `settings.xml` for the phone-side editor |

**Design changes worth knowing about**
- **The number on screen is now the corrected one**, with the API's own value
  shown under it. A term that rounds to 0% is omitted rather than printed, so
  a city reads "no correction" and a ski hill reads "+9% altitude / +43% fresh
  snow". The point of the app is visible or it is absent, never noise.
- **`onShow()` no longer refetches unconditionally.** It fetches only when the
  cache cannot answer for this hour or is over two hours old. START still
  forces a fetch, which is also the test loop.
- **Freshness is age and distance together.** Either alone misleads: a
  five-minute-old fetch from the last town is not current, and a six-hour-old
  fetch from right here is still roughly right. Thresholds are 25 km / 100 km
  against the ~40 km CAMS cell, and 2 h / 12 h.

**Self-review found four real defects before the commit**, all in code written
in this session: a compound-condition ternary that would not have narrowed,
`format("%d")` on a `Float`, a local inferred from `null` then reassigned from
an `Any`, and - the one that mattered - the grid elevation being assigned
before `ingest()` had accepted the series, which would have paired a new
cell's elevation with the old cell's values on a refused fetch. That is a
quietly wrong number rather than an error, which is the worst kind.

- **NOT COMPILED.** No Garmin SDK in this environment. Every line here is
  unverified against the compiler. The riskiest surfaces are `Menu2` /
  `Menu2InputDelegate`, `Application.Properties`, and the settings resource
  XML, none of which v0 exercised.

### 2026-09-22 - The activity gate was unsafe. Matt caught it
- Matt asked what happens when the watch detects running, cycling or skiing
  **indoors** - offseason training, a treadmill, a spin bike, a wave pool. The
  build plan said dose accumulates when "an outdoor activity is recording".
  **The watch does not record an outdoor activity. It records a sport**, and
  almost every sport this app cares about has an indoor form. A treadmill run
  at midday would have booked a full MED against skin that saw no sun at all.
- That is the exact failure mode the whole design exists to prevent: an app
  that over-reports teaches people to ignore it. It was written into the
  design authority and nobody had noticed.
- **The fix is not a prompt, it is an inversion.** Never accumulate by
  default; accumulate only on positive evidence of being outdoors. An indoor
  allow-list can never be complete - Matt's own examples included indoor
  surfing - and anything missing from such a list silently over-counts.
  Requiring a positive signal means an unlisted indoor sport fails closed.
- **The positive signal is free.** `Activity.Info.currentLocationAccuracy`
  reports live GPS quality during a recorded activity, and the activity has
  already powered the receiver. `Activity.getProfileInfo()` gives `sport` and
  `subSport` alongside it.
- **This does not contradict the earlier GPS rejection.** That rejection was
  about polling GPS continuously as a standalone detector with no activity
  running, where the battery cost is real. Reading the quality of a receiver
  someone else turned on is a different question with a different answer. The
  rejected-approaches row has been narrowed so a future session cannot read it
  the wrong way.
- **Quality, not movement.** Requiring the position to change would separate a
  treadmill from a road run, but would also zero out chairlift and belay time -
  high-altitude, high-albedo, and precisely the exposure this app exists to
  measure. The residual over-count is a treadmill beside a south-facing window
  holding a lock, which is rare and which window glass largely defuses anyway,
  since it blocks most of the UVB that drives erythema.
- **Three UI states now, not two:** counting, not-counting-because-unconfirmed,
  and indoors. The build plan already required "paused" to look different from
  "recovering"; this is a third thing that must not look like the other two.
- **Added a per-profile override**, default off, for the outdoor activity
  recorded with GPS switched off - otherwise permanently ambiguous. Set once
  for Trail Run and never thought about again.
- Build plan updated: the signals table, and the "honest design" paragraph that
  carried the wrong rule.

### 2026-09-22 - Model choice for the remaining phases
- Looked up the current model line rather than reasoning from memory, after
  Matt pushed back on a vaguer answer. **Claude Fable 5.1 (`claude-fable-5-1`)
  is Anthropic's most capable widely released model**, above Opus 5, for
  demanding reasoning and long-horizon agentic work, at roughly double the
  per-token price. Opus 5 at `xhigh` - what this project has been using - is
  the documented best setting for coding and agentic work, with `max` the only
  step above it.
- **Decision: Fable does a review pass when v1a is green, and again at the v2
  dose integrator.** Not during the v1a compile loop, where the bottleneck is
  Matt's build cycle rather than idea quality.
- **The Fable brief must be written differently from this repo's house style.**
  Anthropic's own migration guidance is explicit that prompts written for prior
  models are often too prescriptive on Fable and reduce output quality.
  `CLAUDE.md` and this file are deliberately prescriptive - hard constraints, a
  rejected-approaches table, "do not relitigate" - and that has served Opus
  well. For Fable the brief should instead:
  - give the whole task specification up front rather than drip-feeding it
  - state each constraint **with the evidence behind it**, so it can reason
    about the constraint rather than comply with a rule
  - drop the "do not relitigate" framing entirely, and explicitly invite
    challenge where the reasoning is thin - which is the point of a review pass
  - keep the physical and platform facts (no UV sensor, no ambient light
    sensor, same-day dose does not decay) as findings with sources attached
- Today is the argument for that pass: the activity gate above was a design
  hole sitting in the design authority across several sessions, and it took a
  reader who had not written it to see it.

### 2026-09-22 - First v1a build: 2 errors, one cause
- `UvSettings.mc` lines 121 and 139. **A module member cannot be `private` in
  Monkey C** - access modifiers are class-only. The parser abandons the whole
  module body at the first one, so the *next* function reports as a second,
  unrelated-looking error ("extraneous input 'private' expecting 'class',
  'module', ..."). Two errors, one mistake.
- Confirmed by natural experiment across the twelve files rather than by
  guessing: `UvScale`, `UvNum`, `UvCorrection` and `UvSettingsMenu` are modules
  with no `private` and compiled clean; `UvForecast` and `UvState` are classes
  *with* `private` and compiled clean; `UvSettings` was the only module given
  `private` members and the only file that errored.
- Fixed by dropping `private` from both. Module helpers are reachable as
  `UvSettings.readIndex()`, which is harmless. Rule added to `CLAUDE.md`.
- Two parse errors on a 1,700-line rewrite is a better first build than v0's
  19. But a file that fails to parse is not a file that has been type-checked,
  so `catch (e)`, `Menu2`, `MenuItem`'s four-argument constructor and
  `Application.Properties` are all still unexercised. The second build is the
  real test.
- **Simulator note for the resume block:** the Settings menu group - Color
  Mode, Enhanced Readability, Flashlight Available, Glance Launch Mode, Night
  Mode - is greyed out when no app is loaded. It is not a separate fault; a
  failed build means there is nothing for those options to apply to.

### 2026-09-22 - Second build: the background annotation was a declaration
- One error, and no source line: *"The 'Background' permission is required in
  the manifest file in order to create a background application."* v1a has no
  background code at all - no `ServiceDelegate`, no `getServiceDelegate()`, no
  `Background.` call anywhere.
- Cause: `UvNum` and `UvCorrection` carried `(:glance :background)`. **A single
  `(:background)` anywhere in the project makes it a background application**,
  and the compiler then refuses to build until the manifest declares the
  Background permission.
- This was a self-inflicted wound from trying to be forward-looking. The v1a
  reasoning was "annotate for the background scope now, it costs nothing, and
  it avoids a scope surprise in v1b." It is not free. **An annotation is a
  declaration that a build scope exists, not a note that one might.**
- Fixed by dropping `:background` from both, leaving `(:glance)`. v1b adds the
  annotation, the `ServiceDelegate` and `<iq:uses-permission id="Background"/>`
  in one change, which is the only order that builds at every step.
- The alternative - declaring the permission now - was rejected. It asks the
  wearer to grant a permission for something that does not exist, and a
  permission with no service behind it is the sort of thing store review asks
  about.
- Rule added to `CLAUDE.md`.

### 2026-09-22 - v1a RUNS. Three fixes from the first live look
- **Clean build, both pages render, the pipe holds.** `HTTP 200`,
  `idx 15/48` so `forecast_days=2` took, `gridElev=4 m` at Bangkok,
  `slot+3171s` inside the hour. Index 15 is 15:00 UTC, which is 22:00 Bangkok
  local, so `raw=0.00` is correct - **the UTC alignment survived the move to a
  two-day series.**
- **The correction arithmetic is live and correct.** `alt=0%` is right: -18 m
  watch against a 4 m grid is a 22 m delta, 0.2%, which truncates to zero.
  `albedo=1%` is grass 0.03 times open 0.5 = 1.5%. Both branches computed, both
  right.
- **`Menu2`, `Application.Properties`, `catch (e)` and `MenuItem`'s
  four-argument constructor all compiled and ran.** Those were the four
  surfaces v0 never touched. They are no longer unknowns.

**Fix 1 - settings were unreachable.** MENU did nothing Matt could use. On this
hardware MENU is a **long press of UP**, and the simulator's shortcut is the
**M key**; a short press is `onPreviousPage`. But Garmin's own forums carry
reports of `onMenu()` never firing on some fenix and epix models, so a feature
reachable only that way is a feature that is sometimes missing. Added a **third
page** - reading, diagnostics, settings - where START opens the picker. DOWN
cycles. `onMenu()` is kept as well; it is now the shortcut rather than the only
door.

**Fix 2 - the bottom hint was clipped.** `START refresh  MENU set` lost its
final character. At 86% down a round 416 px face the chord is about 288 px, not
416 - roughly `0.69 w` - and 23 characters of `FONT_XTINY` is about 290 px. The
hint is now per-page, measured with `getTextWidthInPixels`, and falls back to a
shorter string if it does not fit, so the 390 and 454 px siblings stay free.

**Fix 3 - "+1% grass" was noise.** On the default settings that line is the
permanent state of the screen, and it claims a precision the model does not
have: `k_alt` is a plus-or-minus-30% assumption and the albedo figures are
mid-range estimates. A correction term is now only printed at 2% or more. Fresh
snow open is +42% and still shows; grass open is +1% and does not.

**Not a bug:** the ten repeated fetches in the console are START presses. The
refetch-on-show gate is working - `onShow()` only fetches when the cache cannot
answer for this hour, and it never fired.

### 2026-09-22 - Memory measured. Question 7 answered for the app
- **App budget on epix Pro (Gen 2) 47mm is 763.6 kB.** v1a peaks at **23.3 kB**
  - about 3%, so roughly 33x headroom. Code 9,584 bytes, data 3,905 bytes, 61
  peak objects of 65,535. Far more room than assumed; the app scope is nowhere
  near a constraint and design decisions should stop pretending it is.
- Glance budget was observed at **59.9 kB** in v0, using about 6.8 kB.
- **The background budget is still unknown and is the only one that matters
  for v1b.** Commonly quoted as 32 kB for this generation. The v1b build will
  report it, and the fetch has to fit: 48 timestamps plus 48 floats parsed into
  a Monkey C Dictionary, on top of the response buffer. `timeformat=unixtime`
  and a single `hourly` variable are already the mitigations; if it does not
  fit, the background drops to `forecast_days=1` and the foreground keeps 2.
- **`onMenu()` fires on this device** - confirmed with the simulator's **M**
  keyboard shortcut. On hardware MENU is a long press of UP, still unverified.
  The settings page stays regardless: forum reports of `onMenu()` failing are
  specifically about real watches, and a feature with one flaky door is a
  feature that is sometimes missing.
- **Discoverability failure found the hard way.** Nothing on the reading page
  indicated other pages existed, so the settings page was unreachable by
  anyone who had not read the commit message. Added the platform-standard
  three-dot page indicator. The memory measurement above is what makes that an
  easy call rather than a trade.
- **Stale-binary tell, updated:** the hint is now per-page and short. If the
  screen reads `START refresh  MENU set` with the final letter clipped off the
  edge, or shows no page dots, the simulator is serving a pre-2026-09-22 `.prg`.

### 2026-09-22 - v1a CONFIRMED WORKING. BACK behaviour fixed
- **All three pages render, the dots show, and the settings picker works.**
  Fresh snow plus open reads `+42% fresh snow` on the reading page. v1a is
  functionally complete.
- **BACK was quitting the app from any page.** That is the Connect IQ default,
  but on a three-page app it reads as a crash: you press BACK expecting to undo
  a page turn and end up outside the app looking at the simulator's own screen.
  Matt hit it within a minute of the settings page existing.
- Fixed: BACK returns to the reading page from a sub-page, and only leaves the
  app from the reading page itself. `onBack()` returning false is what hands
  the press back to the framework so the normal exit still works.
- **Not a crash, worth recording as a triage note:** a blue triangle on black
  in the simulator is not this app. The launcher icon is an orange sun. That
  screen is the simulator outside the app; F5 relaunches.

### 2026-09-22 - v1a closed. Review brief written, session handed over
- BACK fix confirmed. **v1a is complete**: three pages, page indicator,
  on-watch settings, altitude and albedo correction live, cached series that
  survives a failed fetch.
- Wrote `docs/REVIEW-BRIEF-v1a.md` for a cold review by a model that did not
  write the code. **It is deliberately not written in this repo's house
  style.** CLAUDE.md and this file are prescriptive - hard constraints, a
  rejected-approaches table, "do not relitigate" - which has served Opus well.
  Anthropic's migration guidance is explicit that prompts written for prior
  models are often too prescriptive on Fable and reduce output quality, so the
  brief instead:
  - gives the whole task up front rather than drip-feeding it
  - states each constraint **with the evidence behind it**, and marks
    confidence per number, so the reviewer can reason rather than comply
  - names the places the reasoning is thin and asks to be challenged there
  - drops the "do not relitigate" framing entirely
  - is self-contained: it does not require reading this 600-line file first
- **The confidence table is the point of the brief.** `k_alt = 0.10`, the old
  snow albedo, the water albedo and all three openness fractions are marked
  **low** confidence, because they are. Two structural questions are asked
  outright: whether altitude and albedo are genuinely independent multiplicative
  factors or a double-count, and whether `f` - "fraction of the reflecting
  surface in view" - corresponds to anything measurable.
- Recorded the two design holes found in the last two days as the *genre* of
  finding wanted, rather than as warnings: the activity gate that would have
  over-counted a treadmill run as a full MED, and the settings page that was
  invisible because nothing indicated other pages existed. Neither was a coding
  error; both were building from the inside, and both were found by the human
  rather than by the author re-reading its own work. **That is the argument for
  the pass.**

### 2026-09-22 - Cold review of v1a delivered (Fable 5.1)
- `docs/REVIEW-v1a-findings.md`. Eleven findings, ranked for the ski hill,
  every physics and platform claim checked against a primary source. Nothing
  compiled; the sandbox cannot. Highlights, in rank order:
  - **Open-Meteo's `elevation` defaults to the 90 m DEM height at the requested
    point**, not the CAMS cell mean; `elevation=nan` is documented to return the
    grid-cell average. On a piste the delta is therefore ~0 and the altitude
    correction silently vanishes. v0's flat-terrain checks could not
    distinguish the two. Five-minute simulator test in the review.
  - **CAMS already models snow albedo** (regional albedo when model snow depth
    > 2 cm, old/fresh split). The app's +42% is stacked on top. Measured
    clear-sky snow enhancement of the index is 15-25% in total.
  - **Position and altitude are written only in `UvClient.start()` /
    `onPosition()`**, and `forecast.lat/lon` are copies of the same values, so
    `distanceKm` is 0 after every successful fetch and `onShow()` cannot detect
    a move. Fetch at home, drive to the hill, open the app: Calgary's number,
    labelled current.
  - **A real watch's cached fix is the end of the last GPS activity**, and
    `Position.Info.when` is never read. The simulator's always-correct default
    position hid this.
  - Hourly values are instantaneous; the step read is up to 30-50% off on the
    shoulders. Surroundings only scales the reflected term, so "Enclosed" is
    not a reduction. CAMS global updates every 12 h, so fetch age is not data
    age, and a 30-minute v1b refresh buys nothing. Situational surface settings
    never expire and the default surface word is hidden by the 2% threshold.
  - `migrate()` in `onStart()` will run in the background process once the app
    class is `(:background)`; move it before v1b.
- Constants (k_alt, albedo table, water, clamps, uncapped output) judged inside
  the noise of the above; verdicts recorded in the review.
- No code changed. Findings, not a rewrite, as the brief asked.

### 2026-09-23 - Review verified. v1c defined; v1b waits for it
- Project moved from Fable 5.1 to **Opus 5.5** for this phase, on Matt's
  reading of published benchmarks. Which model does the v2 dose-integrator
  review is left open (question 24).
- Read the review, the brief, this file, TOOLCHAIN.md, the whole build plan
  and all twelve source files before judging anything. **Nothing compiled;
  no code changed.**

**What was re-checked, and the verdict**

| Finding | Check | Verdict |
|---|---|---|
| 1 `elevation` is the 90 m DEM height at your coordinates, not the cell mean | Open-Meteo documents it: default is Copernicus GLO-90 at the point, used for downscaling; `elevation=nan` disables downscaling and uses the grid-cell height. The air-quality API accepts `elevation` and `cell_selection` too. Issue #1155 (elevation=nan returning the wrong number) is real; its fix status could not be confirmed from here | **Holds. Needs the simulator test** - Olathe and Bangkok are flat, so v0 could not tell the two apart |
| 1, extra | The CAMS UV method uses **altitude as an input** to its snow regressions, i.e. CAMS already applies an altitude effect at its own model terrain height | Strengthens finding 1: the correct baseline is the cell height CAMS used, which is what `elevation=nan` is supposed to return |
| 2 CAMS already models snow albedo | CAMS UV methodology: regional snow albedo when model snow depth > 0.02 m; four regressions split on old/fresh and solar zenith above/below 65 deg | **Holds.** One discrepancy: the CAMS document says "fresh" means snow water content rose **within the last 24 h**; the review says four days. Does not change any decision |
| 3 Position and altitude only sampled when a fetch starts | Re-traced. `UvState.latitude/longitude/watchAltitude` are written only in `UvClient.start()` and `onPosition()`; `load()` restores the last fetch's values; `ingest()` copies them into `forecast.lat/lon`. So `distanceKm` is 0 after every successful fetch, also across app restarts | **Holds exactly as stated** |
| 4 Cached fix age never read | `Position.Info.when` exists in the API docs; `UvClient` never reads it. `QUALITY_LAST_KNOWN` whenever GPS is off is documented | **Holds.** How often it bites is a wrist test |
| 5 Hourly values instantaneous; step read | Code reads `values[idx]` for the whole hour | **Holds** |
| 6 Surroundings only scales the reflected term | `UvCorrection.albedoFactor` multiplies `albedo * openness`; direct and sky terms untouched | **Holds.** "Enclosed" + grass reads "no correction" |
| 7 CAMS updates twice a day | Open-Meteo: CAMS updated twice daily; global ~45 km, Europe 11 km | **Holds.** v1b's 30-minute refresh is wasted |
| 8 Sticky settings; default word hidden | Code re-read | **Holds** |
| 10 `migrate()` in `onStart()` | `onStart` runs in every process once the app is a background app | **Holds.** Must move before v1b |

**v1c - what it contains**

No-decision items (findings 3, 4, 5, 10, and 10's `_cancelled` flag):
- Read position (range-guarded, fix age checked) and barometric altitude on
  every `onShow()`, before judging freshness
- Treat a cached fix older than ~60 min as unusable; fall through to the
  existing one-shot GPS with its 45 s timeout. Show fix age on diagnostics
- Range guard: reject |lat| > 90 or |lon| > 180, alongside the 0,0 guard
- Interpolate between hours in `valueAt()`, falling back to the step value
  at a gap or at the end of the series
- Move `migrate()` out of `onStart()` into `getInitialView()` /
  `getGlanceView()`
- EXPIRED draws the number grey
- `FRESH_SECONDS` 2 h -> ~6 h; distance thresholds unchanged (they now work)
- Add `elevation=nan` to the request **if** test part B shows it returns a
  shared cell value

Decision items (questions 20-23), all Matt's:
- **Surroundings** - drop it (review recommends: shade belongs in v2 as a
  dose pause) or rework it to scale total UV with wide, honest labels
- **Snow** - replace 0.85/0.50 x openness with an increment over CAMS of
  roughly +15-20% fresh and +5-10% old, printed as approximate
- **Corrected number** - one decimal, whole number, or a range. The API
  figure stays at one decimal either way
- **Surface expiry** - back to grass at local midnight, or after ~12 h. The
  surface word always shows; the percentage only at 2% or more

**The elevation test - exact steps for Matt**

Part A runs on the **current** build. No pull needed.
1. Simulator: **Settings -> Set Position** -> `51.115, -115.763` (Sunshine
   Village base, about 1,660 m). Press START. In the **Debug Console**, copy
   the line starting `UV OK` - the number after `gridElev=`
2. Set Position -> `51.078, -115.779` (Sunshine Village, about 2,160 m,
   4 km away). START. Copy the `UV OK` line again
3. **Read it:** two different `gridElev` values, each close to the real
   height, means the field is the point terrain height and finding 1 is
   confirmed. The same value both times means it is already the cell mean and
   the altitude correction works as designed

Part B needs a build with `elevation=nan`; Claude pushes it after part A. Same
two positions. One shared value, well below 2,160 m, is the cell height and
becomes the correction's baseline. Anything else is issue #1155, and the
fallback is to say on screen that the altitude correction is unavailable
rather than print "+0%".

**Branch note (resolved).** Matt asked for the work to go to the branch
`update.bat` pulls, `claude/garmin-uv-tracking-app-7y6gk6`, as previous
sessions did. Pushed there as a fast-forward.

- Build plan not yet edited: no decision has changed yet. It gets updated
  when the four decisions are made.

### 2026-09-23 - v1c written. NOT COMPILED
- Matt's decisions: **drop Surroundings, accept the snow figures, reset the
  surface at local midnight.** Corrected-number format (question 22) not yet
  answered, so v1c keeps one decimal.
- **What v1c changes**, file by file:

| File | Change | Finding |
|---|---|---|
| `UvSense.mc` (new) | Barometric altitude and cached fix, read from what the system holds. Fix range-guarded and age-checked (over 60 min refused); age recorded | 3, 4 |
| `UvMainView.mc` | `onShow()` samples position and altitude, and expires the surface, before judging freshness. Surface word always shown. Expired number grey. Diagnostics shows fix age. Settings page shows one setting and "shade not modelled" | 3, 6, 8, 10 |
| `UvClient.mc` | Uses `UvSense`. `_cancelled` flag. Requests `elevation=nan`; retries once without it on 400 or a parse failure. Console gains `hr=` and `(cell)`/`(point)` | 1, 10 |
| `UvForecast.mc` | Interpolates between hours; `stepValueAt()` for the console. Fresh window 6 h | 5, 7 |
| `UvSettings.mc` | Surroundings removed. Surface is an increment, not albedo x openness. Midnight reset via two Storage keys; reading never writes, the app writes the reset | 2, 6, 8 |
| `UvCorrection.mc` | `surfaceFactor(increment)` replaces `albedoFactor(albedo, openness)` | 2, 6 |
| `UvSettingsMenu.mc` | Opens the surface list directly; the one-row top menu and its delegate are gone | 6 |
| `UvGuardApp.mc` | `migrate()` moved to `getInitialView()` / `getGlanceView()` | 10 |
| `UvState.mc` | `fixAgeSeconds`. A restored position is no longer labelled a cached fix | 4 |
| `UvGlanceView.mc` | Expired reading grey | 10 |
| resources | `openness` property, setting and strings removed; surface prompt rewritten | 6 |

- **No schema bump.** The new Storage keys are additive and absent keys are
  handled; a bump would wipe the cache for nothing. A watch with `openness`
  set keeps an orphaned property nothing reads.
- **The elevation test now runs on v1c.** Part A (optional) must be done on
  the v1a build, i.e. before `update.bat`. Part B is simply two fetches on v1c
  at the two Sunshine positions; the console marks `(cell)` or `(point)`.
- **Riskiest new surface for the compiler:** `Position.Info.when`,
  `Time.today()`, and `Dictionary.put` on the params literal - none used
  before in this project. Compound null tests before arithmetic were split.
- **Riskiest new surface at runtime:** the fix-age gate in the simulator.
  Nobody knows what the simulator puts in `when`. If it reports an old
  timestamp, every fetch falls through to a one-shot GPS that timed out in the
  simulator once before. The console line `Cached fix too old` names it.
- Sand (+9%) now exceeds old snow (+7.5%). Deliberate for now; question 25.
- Build plan updated for the three decisions.

### 2026-09-23 - v1c compiled and ran. The elevation test found a hole
- **Build successful** on the first compile. `Position.Info.when`,
  `Time.today()`, `Dictionary.put` and `UvSense` all passed the strict checker.
- **Part A skipped** (optional). **Part B results**, both Sunshine positions:

```
UV OK raw=0.00 hr=0.00 eff=0.00 gridElev=ABSENT (cell) idx=3/48 slot+1545s alt=0% surface=1%
UV OK raw=0.00 hr=0.00 eff=0.00 gridElev=ABSENT (cell) idx=3/48 slot+1607s alt=0% surface=1%
```

- **What that proves:** `(cell)` means `elevation=nan` was sent and accepted:
  HTTP 200, the body parsed, no retry. But the response carries **no usable
  `elevation`** - absent, or null. So on this endpoint `elevation=nan` does
  not return the grid-cell height the forecast API documents. The altitude
  correction is therefore **off everywhere** in v1c (`alt=0%`, diagnostics
  "no grid"). That is an under-report, the safe direction, and on a hill v1a
  was probably no better (finding 1) - but the headline feature does nothing.
- **What it does not prove:** UV was 0.00 because idx 3 is 03:00 UTC, night
  in Alberta, so the series itself was untested at those positions. The fix
  age was not reported; the fetches succeeded without a GPS timeout, so the
  60-minute gate did not block the simulator.
- `hr=` equals `raw=` at night as expected (both zero); interpolation is not
  yet seen working on a non-zero series. A daylight position will show it.
- **Question 22 answered: one decimal** (no code change - v1c already does).
- **Options for the cell height, for the next session to weigh:**
  1. **Drop `elevation=nan`, return to the default.** Honest only if the
     screen then says the altitude correction is unavailable in relief,
     because the default is (per the docs) the point terrain height, which
     cancels against the barometer on a hill
  2. **Compute the cell mean ourselves** from Open-Meteo's Elevation API
     (`api.open-meteo.com/v1/elevation`, a 90 m DEM, many coordinates per
     request): sample a grid of points across the CAMS cell and average. One
     extra request per cell, cacheable indefinitely because terrain does not
     change. Needs the CAMS global grid spacing and cell boundaries checked
     (~0.4 deg, ~45 km) and the free-tier terms for that endpoint checked
  3. **Find another field or endpoint** that exposes the CAMS model
     orography directly. Unresearched
  - Also worth running part A after all, on a build without `nan`, to test
    rather than infer what the default returns in relief
- `update.bat` branch: pushed to `claude/garmin-uv-tracking-app-7y6gk6`
  (fast-forward) and to the session branch `claude/fable-results-review-nb6cd3`.

### 2026-09-23 - Cell height decided and written. NOT COMPILED
- Read CLAUDE.md, this file, the review, TOOLCHAIN.md and all thirteen source
  files first. Then fact-checked the three options from the previous entry.

**Why `elevation=nan` came back empty. Established, not guessed.**
- Open-Meteo's own source, `Sources/App/Cams/CamsDomain.swift`: the CAMS
  domains define a grid and nothing else. **No elevation file.**
  `CamsDownload.swift` downloads no terrain either. So `elevation=nan`
  ("use the model's cell height") has nothing to look up and comes back
  empty. That is the cause, and no request parameter can get around it
- `elevation` is not even a documented parameter on the air-quality API.
  Only `cell_selection` and `domains` are
- Issue #1155 is a **different** bug: `elevation=nan` returned 0 in the Alps
  on the weather API, fixed by PR #1164 ("shift and flip GRIB data for grids
  starting at 0 deg longitude"). It does not explain ours

**Facts that the chosen fix rests on, each checked**
- The response's `latitude`/`longitude` are, in Open-Meteo's words, the "WGS84
  of the center of the weather grid-cell which was used to generate this
  forecast". So the app can read which cell it was served
- `cams_global` is a regular 0.4 deg grid anchored at -90 / -180
  (`RegularGrid(nx: 900, ny: 451, ... dx: 0.4, dy: 0.4)`). **`uv_index`
  comes only from `cams_global`**, never `cams_europe`, so 0.4 deg holds
  everywhere. Both Sunshine test points fall in the cell centred 51.2,
  -115.6 on paper
- CAMS itself runs at about 40 km (TL511 / N256), and Open-Meteo regrids it
  to 0.4 deg. **ECMWF builds model terrain as the mean surface height over
  each grid box**, from a ~1 km dataset. A mean of terrain heights across
  the cell is therefore the same quantity, computed the same way. The ~0.35
  vs 0.4 deg mismatch is second order
- Elevation API: `https://api.open-meteo.com/v1/elevation`, comma-separated
  `latitude`/`longitude`, **up to 100 points per request**, Copernicus GLO-90
  (90 m), response `{"elevation":[...]}`, HTTP 400 with a JSON error on bad
  input. Free for non-commercial use; attribution to Copernicus and
  Open-Meteo required (relevant to question 5)
- **Not confirmed:** whether a 49-point request counts as 1 or 49 calls
  against the 10,000/day free limit. Issue #1295 asks exactly this and has no
  answer. Either way it is one request per new cell, ever

**The three options, weighed**
1. **Fall back to the default field, say "unavailable" on hills.** Honest,
   but the default is the height of the exact spot, so the correction is
   ~0 wherever it matters, forever. Rejected: it turns the headline feature
   off rather than fixing it
2. **Compute the cell mean ourselves.** Chosen. Rests on documented
   behaviour only, one ~1 kB request per new cell, cached indefinitely
3. **Find a field that exposes CAMS terrain.** There isn't one on
   Open-Meteo (no CAMS terrain stored at all). The CAMS data store needs a
   key, which hard constraint 5 rules out. The weather API's ECMWF terrain is
   the 9 km model's, not CAMS's. A bundled table cannot be built from here.
   Rejected

**What changed**

| File | Change |
|---|---|
| `UvCell.mc` (new) | 7 x 7 sample grid across the 0.4 deg cell, the mean (at least 40 of 49 heights usable, missing ones left out rather than counted as sea level), and a one-cell cache in Storage (`cla`, `clo`, `ch`) |
| `UvClient.mc` | `elevation=nan` and its 400-retry removed. Reads the cell centre from the response; cached cell -> baseline at once, new cell -> `gridElevation` null and a second request. `_cancelled` now also checked in `onResponse`. Console: `cell=`, `cellElev=`, `pointElev=` |
| `TOOLCHAIN.md` | "Testing the cell height" |

- **Ordering is deliberate.** The UV reading is saved and shown first; the
  height request follows. A new cell has no baseline for a second or two, so
  the correction is briefly off ("no grid"). An old cell's height is never
  paired with a new cell's forecast.
- **A failed height request costs nothing but the correction.** It is not
  cached, so the next fetch at that cell tries again.
- **`pointElev=` is logged, not used.** Two different values at the two
  Sunshine positions would confirm the review's finding 1, the part A that was
  skipped, at no extra effort.
- **Expected in the simulator: `alt=-15%` at Sunshine.** The fixed -18 m
  simulator altitude against a ~2 km mountain cell hits the -1,500 m delta
  floor. That is correct and does not need fixing.
- **On a real hill the correction can be negative**, and that is physics,
  not a bug. It is measured from the cell's mean height. If the cell is
  mostly peaks and high benches, standing at a base area below that mean
  means CAMS already assumed more altitude than you have.
- **Riskiest new surface for the compiler:** none that is new to the project.
  The same `makeWebRequest` callback signature, `Storage`, the `asFloat`
  pattern and nested null tests all compile already. The module constant
  arithmetic in `UvCell` (`SPACING / SIDE`) is the only new shape.
- **Riskiest at runtime:** the request URL is about 1 kB after the commas are
  URL-encoded. No documented Connect IQ limit was found either way. If it is
  refused, the console says `Cell height failed: HTTP ...` and the fix is
  fewer points (5 x 5).
- **Unverified side note, not acted on:** Open-Meteo's air-quality docs list
  CAMS global as "3-hourly", while ECMWF says CAMS surface fields are hourly.
  If Open-Meteo interpolates UV to hourly, the finding-5 interpolation is
  interpolating an interpolation. It changes nothing in v1c.
- **v1b consequence:** the background service needs the cell height too. It
  cannot write storage, so either it returns a new cell's height in the
  `Background.exit()` payload, or it leaves new cells to the foreground and
  sends `gridElevation` null. Decide when v1b is designed.

**Question 25, re-explained in plain terms** (Matt found the first version
unclear)

The surface setting adds a percentage for what you are standing on: fresh snow
+17.5%, old snow +7.5%, sand +9%, concrete +5%, water +3.5%, grass +1.5%.

The number on screen is the **UV index**, which measures the UV landing on a
flat, face-up surface like a table top. Bright ground raises it in only one
way: UV bounces off the ground, goes back up into the air, gets scattered, and
some comes back down onto the table top. That round trip happens over
kilometres of landscape, so **it depends on how bright the whole area is, not
the patch under your boots.**

That is why snow was cut from +42% to +17.5%. A piste on its own adds much
less to the index than the old formula claimed, and the forecast already
allows for snow across the area.

**The question:** sand, concrete and water still use the old formula that was
thrown out for snow - "how reflective is the surface, times a half". The same
argument says they are too high as well. A beach is a strip of sand beside a
lot of water and land that reflects less. By rough scaling from the snow
measurements, **my estimate, not a measured figure**, a whole region of dry
sand might lift the index by a few percent, and a strip of beach by less.
+9% is probably at or above the top of that.

What the figures do NOT capture: reflected light hits your **skin**
directly - under the chin, the nose, the eyes. On a beach, UV measured at eye
level can be about double what it is over grass. That is real, but it is
about the dose to your face, which is v2's job, not the index on screen.

The options:
- **A. Leave them.** Simple, errs high. Keeps the oddity that sand beats old
  snow
- **B. Shrink them by the same logic as snow.** More consistent. The next
  session would derive and source the figures first; none are proposed here
- **C. Collapse the list** to grass/ground plus the two snows. At the index
  level the non-snow differences are about the size of the model's own error
  bars, so the choice may be false precision. The skin-level effects come
  back properly in v2

- **Matt decided question 25: B.** Shrink sand, concrete and water by the
  same logic as snow; keep all six surfaces, because wearers should still feel
  they have a real choice of ground. His note for the record: had it been C,
  water should still have stayed, so ground, water and snow are all
  represented. **Figures are not yet derived.** The next session sources them
  first and proposes them before any code changes.
- Build plan updated: the formula's `h_grid` definition, the payload note,
  and the resolution note now describe the cell mean and where it comes from.

Pushed to `claude/garmin-uv-tracking-app-7y6gk6` for `update.bat`.

### 2026-09-23 - Question 25 figures derived, approved, written. NOT COMPILED
- Matt asked for the surface figures first, with sources, and his OK before
  any code changed. Given; then written.

**Method.** KNMI's operational UV service (TEMIS) corrects the UV index for
regional surface albedo with

    f(A) = (1 - 0.25 * A_ref) / (1 - 0.25 * A)

which is the ground-atmosphere multiple-reflection effect - the physics that
cut snow. A_ref, what the model already assumed for snow-free ground, is taken
as 0.05, the value the 2026 ERA5 UV-index paper uses.

**Checked against measurements before use.** Regional albedo 0.5-0.7 gives
+13% to +20% over 0.05, against the measured clear-sky snow effect of 15-25%.
At the Salar de Uyuni (measured erythemal albedo 0.69 +/- 0.02), it predicts
about +17-19% against a measured +20% at 50 deg solar elevation (Reuder et al.
2007). So the formula holds from grass to salt flat.

| Surface | Published erythemal albedo | Formula | Was | Now |
|---|---|---|---|---|
| Grass | 0.01-0.04 (Feister & Grewe 1995); 0.02-0.03 (Chadysiene & Girgzdys 2008) | -0.9 to -0.3% | +1.5% | **0** |
| Water | 0.05-0.08 (Feister & Grewe); ~0.10 calm water (WHO UVI guide) | 0 to +1.3% | +3.5% | **+1%** |
| Concrete or urban | 0.10-0.20 (Feister & Grewe); ~0.10 (Turner & Parisi 2018 review) | +1.3 to +4.0% | +5% | **+2%** |
| Dry sand | ~0.10 (Chadysiene & Girgzdys); ~0.15 (WHO); higher for white sand | +1.3 to +5.3% | +9% | **+3%** |

- Grass is 0, not negative: CAMS's own snow-free UV albedo is not pinned
  down well enough to claim a reduction
- **Upper limits.** The ground that matters reaches 10-20 km, detectably
  40-50 km (Degunther & Meerkotter 1998, 2000). The figures assume that whole
  area is the surface; a strip of beach adds less
- **Sand and concrete are the same within the measurement spread.** Sand's
  +3% over concrete's +2% rests on sand's range reaching higher, not on a
  measured difference
- **Unconfirmed:** CAMS's actual snow-free UV albedo. ECMWF's UV-visible
  background albedo is a MODIS snow-free climatology, probably higher than
  true UV albedo; if so, these figures err high, the safe direction
- **Unverified counter-evidence:** a search summary of Schmucki et al. 2001
  (Swiss Alps) appears to give +5% at effective albedo 0.1, where the formula
  gives +1-3%. Its baseline could not be read from here
- Consequence, stated plainly: water and grass now never show a percentage
  (under the 2% threshold). Sand and concrete just clear it. All six stay in
  the list, per Matt's decision

**Rounding fix.** Percentages were truncated. 0.02 x 100 is 1.9999999 in a
32-bit float, so concrete's +2% would have read "+1%" and been hidden.
`UvCorrection.roundPercent()` now rounds, halves away from zero, and
`surfacePercent()` works from the increment directly rather than from
(factor - 1), which adds float error. Fresh snow now reads +18% and old snow
+8% (were +17% / +7%). The altitude floor still reads -15%.

**Files:** `UvSettings.mc` (figures, sourced comment, "no change" sub-label
for grass), `UvCorrection.mc` (rounding, `clampIncrement`), `UvMainView.mc`
("no change to UV" on the settings page), `strings.xml` (surface prompt),
`properties.xml` (comment), TOOLCHAIN.md ("The surface figures").

- **Riskiest for the compiler:** nothing new to the project. The ternary in
  the settings-page array sits beside one that already compiles, and
  `(:glance)` modules already call each other
- Build plan updated: the surface table and question 25
- Job 1 (the cell-height test) is still waiting on Matt's console lines

Pushed to `claude/garmin-uv-tracking-app-7y6gk6` for `update.bat`.

### 2026-09-23 - Cell-height test run. One unpredicted finding, fixed. NOT COMPILED
- Matt ran "Testing the cell height" on the build with the new surface
  figures. All six surfaces showed as predicted, including concrete's
  `about +2%` (the rounding fix works) and grass's `no change`.

```
UV OK ... cell=51.10,-115.80 cellElev=pending pointElev=1687 m idx=5/48 slot+1745s alt=0% surface=0%
GET https://api.open-meteo.com/v1/elevation cell=51.10,-115.80 points=49
Cell height 1993 m from 49/49 points, cell=51.10,-115.80 alt=-15%
UV OK ... cell=51.10,-115.80 cellElev=1993 m pointElev=2192 m idx=5/48 slot+1803s alt=-15% surface=0%
UV OK ... cell=51.00,-114.10 cellElev=pending pointElev=1061 m idx=5/48 slot+1836s alt=0% surface=0%
GET https://api.open-meteo.com/v1/elevation cell=51.00,-114.10 points=49
Cell height 1117 m from 49/49 points, cell=51.00,-114.10 alt=-11%
```

**What passed, as asked:** the same `cell=` at both Sunshine positions; no
second elevation request there (`cellElev=1993 m` straight away - the cache
works); `alt=-15%` at Sunshine (the -1,500 m floor); Calgary a new cell with
its own request; 49 of 49 heights usable both times; the ~1 kB request URL
was accepted; `alt=-11%` at Calgary is -18 m against 1,117 m, rounded
correctly. UV 0.00 is right: idx 5 is 05:00 UTC, night in Alberta.

**Finding 1 of the review is now confirmed live:** `pointElev=1687 m` and
`2192 m` at two positions 4 km apart, against real heights of about 1,660 and
2,160 m. The response's default `elevation` is the terrain height of the exact
spot.

**What failed: the cell was the wrong one.** On paper both Sunshine positions
sit in the 0.4 deg cell centred 51.20,-115.60. The response named
51.10,-115.80 - and Calgary 51.00,-114.10. Those three fit a 0.1 deg grid
exactly and cannot sit on a 0.4 deg grid anchored at -90 / -180.

**Cause, from Open-Meteo's own source** (read directly this time;
raw.githubusercontent.com is reachable from the sandbox):
- `CamsDomain.swift`: `cams_global` is still `RegularGrid(nx: 900, ny: 451,
  latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)`. `cams_global_greenhouse_gases`
  is a 0.1 deg global grid carrying only CO2, CO and methane. `cams_europe`
  returns nil for `uv_index`. So UV comes only from the 0.4 deg grid
- `ForecastapiController.swift`: the default model, `air_quality_best_match`,
  reads from all CAMS domains together, with no primary domain set
- `GenericReaderMixerRaw.swift`: the reported coordinates are
  `reader.last?.modelLat` - the last domain in that list that covers the
  point. Outside Europe that is the greenhouse-gas grid
- `Gridable.swift` / `RegularGrid.swift`: with no terrain file (CAMS has none),
  the grid point is the plain nearest one, `roundf((coord - origin) / dx)`

**Consequence:** the first build averaged a 0.4 deg box centred on the
greenhouse cell, offset 0.1 deg north-south and 0.2 deg east-west from the
real UV cell - about 38% overlap. 1,993 m and 1,117 m are therefore not the
right cells' heights, though probably not far off. It would also have cached
per 0.1 deg cell, costing up to 16 times the requests.

**Fix:** `UvCell.cellLat()` / `cellLon()` compute the 0.4 deg cell from the
fetch position with the same rounding (clamped at the poles, column 900
wrapped to 0). Checked in 32-bit arithmetic: both Sunshine positions give
51.20,-115.60 and Calgary 51.20,-114.00. The response's coordinates are logged
as `resp=` and never used. The stored 1,993 m belongs to the wrong box, so it
no longer matches and is replaced on the first fetch - no migration needed.

- **Riskiest for the compiler:** nothing new. The null-initialised locals the
  first draft of this fix used were caught in self-review and replaced with a
  text string, per CLAUDE.md
- **Two items from the screenshots, not faults:**
  - `WARNING - persisted values reset due to settings redefinition` is the
    simulator clearing Properties because `strings.xml` (a settings prompt)
    changed. Storage survived, which is why the first launch did not fetch:
    the cache from the previous session was still current. Worth knowing for
    real updates later: whether a watch resets settings the same way is
    unverified
  - The Problems panel shows 1 item. Not yet read; Matt to report it
- Build plan updated: the `h_grid` sentence now says the cell is computed from
  the position, not read from the response

Pushed to `claude/garmin-uv-tracking-app-7y6gk6` for `update.bat`.

### 2026-09-23 - Cell height CONFIRMED. v1c closed. v1b designed, awaiting decisions
- Matt pulled `952b724`, ran "Testing the cell height" and pasted the console.
  He started at Calgary (where the simulator was left), so the order was
  Calgary, Sunshine base, Sunshine Village, Calgary again.

```
UV OK raw=0.88 hr=0.50 eff=0.88 cell=51.20,-114.00 resp=51.00,-114.10 cellElev=pending pointElev=1061 m idx=15/48 slot+2125s alt=0% surface=0%
GET https://api.open-meteo.com/v1/elevation cell=51.20,-114.00 points=49
Cell height 1101 m from 49/49 points, cell=51.20,-114.00 alt=-11%
UV OK raw=0.88 hr=0.45 eff=0.88 cell=51.20,-115.60 resp=51.10,-115.80 cellElev=pending pointElev=1687 m idx=15/48 slot+2223s alt=0% surface=0%
GET https://api.open-meteo.com/v1/elevation cell=51.20,-115.60 points=49
Cell height 2060 m from 49/49 points, cell=51.20,-115.60 alt=-15%
UV OK raw=0.90 hr=0.45 eff=0.76 cell=51.20,-115.60 resp=51.10,-115.80 cellElev=2060 m pointElev=2192 m idx=15/48 slot+2292s alt=-15% surface=0%
UV OK raw=0.92 hr=0.50 eff=0.92 cell=51.20,-114.00 resp=51.00,-114.10 ...
```

(The last line is abbreviated here; it matched the first Calgary fetch,
including a fresh elevation request and `Cell height 1101 m`.)

**Every expectation met:**
- `cell=` is the 0.4 degree UV cell at all three positions, exactly as
  predicted; `resp=` is the 0.1 degree greenhouse cell, exactly as in the
  first run. The response's coordinates are logged and never used
- The first Sunshine fetch made a fresh elevation request (the stored height
  belonged to the wrong box); the second Sunshine position made none and
  showed `cellElev=2060 m` straight away - the cache works
- `alt=-15%` at Sunshine is the -1,500 m floor (-18 m against 2,060 m)
- `alt=-11%` at Calgary: -18 m against 1,101 m is -11.2%
- `eff=0.76` at Sunshine Village is `0.90 x 0.85`, the floor applied
- 49/49 points usable every time
- The correct cells are a little different from the first build's wrong
  boxes: Sunshine 2,060 m (was 1,993), Calgary 1,101 m (was 1,117)

**Also shown for the first time: the hour interpolation on a non-zero
series.** 15:00 UTC is 09:00 in Calgary. `hr=0.50` is the 15:00 value and
`raw=0.88` at 59% of the way through the hour implies about 1.14 at 16:00 -
a plausible September morning rise. All four `raw` values imply the same next
hour (about 1.14-1.16) within the two-decimal rounding of the log.

**Found, not a fault:** returning to Calgary re-requested its height, because
`UvCell` remembers one cell only. v1b widens that cache (below).

**Not proven by this test, for the record:** that the UV value comes from the
0.4 degree cell rather than the 0.1 degree one. Both Sunshine positions share
both cells, so their identical `hr=0.45` cannot tell the two apart. The
source-code reading is the evidence. An optional one-minute test: Set Position
`51.300, -115.450` (same 0.4 degree cell as Sunshine, different 0.1 degree
cell) in the same UTC hour as a Sunshine fetch. Identical `hr=` confirms it.

**The Problems-panel item:** `UvSense.mc` line 59, "Statement is not
reachable" - the `return false` after `if (info == null)`. The SDK declares
`Position.getInfo()` as always returning a `Position.Info`, so the compiler
knows the test can never be true. Removed, with a comment saying why. The
position inside the info can still be null and is still tested.
**Not yet compiled** - the next build confirms it.

**Storage writes from the background: a settled fact was wrong as stated.**
Found while researching v1b. Two separate searches return the same passage from
Garmin's Storage documentation (the page itself is blocked from this sandbox): *API
level 3.2.0 introduced the ability to access the Storage module from
background processes. The background process can modify storage using
`setValue()`, `deleteValue()` and `clearValues()`. When the storage is
written from the background process, `AppBase.onStorageChanged()` is invoked
for the foreground process if both are active at the same time, and vice
versa.* epix Pro is API 5.2. So "a background service cannot write storage"
(2026-09-22) is wrong for `Application.Storage` on this watch. It still holds
for `Application.Properties`. There is also a forum bug report of one device
(titled "F5", probably a fenix 5) failing to save from the background while others
succeed - unread here, the forum is blocked. The decision and rejected-
approach rows are marked; the choice of channel is decision 3 below.

**v1b design - what it does**

1. **Manifest and scopes, in one change** (per CLAUDE.md): the Background
   permission, `(:background)` on the app class, a new service delegate,
   `UvNum`, `UvCell`, and one shared parser.
2. **A background service** (`UvBackground`, a `ServiceDelegate`) woken by a
   repeating temporal event. It reads the last position from Storage
   (the foreground writes it), fetches the UV series, and returns it.
   `getServiceDelegate()` returns an array, or the simulator's manual trigger
   never calls it (established 2026-09-22).
3. **One parser for both paths.** `UvForecast.ingest()` lives in a glance
   class; the background should not carry the whole class. The uniform-step
   check and the -1 sentinel move into a small `(:background)` module that the
   foreground client and the service both call.
4. **`onBackgroundData()` in both the app and the glance** takes delivery,
   writes the series, and redraws. Only foreground processes write the
   forecast keys, so there is one writer per key.
5. **Position persisted on every `onShow()`**, not only when a fetch
   starts, so the background fetches for where the watch last *was*, not
   where it last *fetched* (review finding 3, its v1b note).
6. **Diagnostics shows the last background result**: when, and the HTTP
   code if it failed. The real-watch test needs it, because nothing else
   will show whether the service is running.
7. **The background memory budget gets measured** on the first build. The
   fallback, if it does not fit, stays as planned: `forecast_days=1` in the
   background only.

**Doing unless Matt objects** (consequences of this session's findings, not
new choices):
- **Freshness by cell, not by 25 km.** The 25 km "near" test predates knowing
  the grid. A 0.4 degree cell is about 44 x 28 km at 51 deg N, so 25 km can
  cross into a neighbouring cell - whose forecast is different - while the
  cache still says CURRENT. Now that the watch computes the cell exactly,
  "same cell" is the right test. 100 km stays as the EXPIRED limit
- **Remember several cells' heights, not one.** Four is ~100 bytes and makes
  a Calgary-Sunshine round trip cost no elevation requests
- **The glance reads the barometer on draw**, if the compiler accepts
  `Toybox.Activity` in the glance scope; otherwise it keeps the stored
  altitude. On a ski day the stored one is wherever the app was last opened

**Decisions for Matt**
1. **Refresh cadence.** Replaces "every 30 min" (48 fetches a day for data
   that changes twice). Open-Meteo's source says CAMS arrives about 8 hours
   after each 00 and 12 UTC run, i.e. about 02:00 and 14:00 in Calgary in
   summer - but the live status page is blocked from here, so the exact time
   is unverified. Recommended: **every 3 hours** (8 small fetches a day),
   which catches a new run within 3 hours whatever its exact arrival time.
   Alternatives: every 6 hours (4 a day); or twice a day aimed at the
   expected arrival times, which is leanest but misses a run for 12 hours
   whenever Open-Meteo is late
2. **Cell height in the background.** Recommended: **the service fetches it
   itself** when the cell is new and returns it with the forecast, so the
   glance is never left uncorrected. Cost: a second request inside the
   service's 30-second limit, rare because of the wider cell cache.
   Alternative: leave new cells to the foreground; the glance shows the
   uncorrected number until the app is opened
3. **How the service hands data back.** Recommended: **keep
   `Background.exit()`**, now for a different reason than first given: one
   writer per key (a foreground fetch and a background run can otherwise
   write the same keys at the same moment), no reliance on a feature with a
   reported per-device bug, and a payload far under the ~8 kB cap (48 values
   is under 1 kB). Alternative: the service writes Storage itself, which
   drops the payload plumbing
4. **`uv_index_clear_sky`** (review finding 11: "3.1 now, up to 7 if it
   clears", the answer to a CAMS cloud forecast that is wrong over the
   mountains). Recommended: **fetch and store it now**, so the stored shape
   changes once, not twice. Sub-question: show it on the reading page in v1b,
   or wait for v3's chart

Build plan not yet edited: its "every 30 min" and its background-storage
sentence change once decisions 1 and 3 are made.

Pushed to `claude/garmin-uv-tracking-app-7y6gk6` for `update.bat`.

### 2026-09-23 - v1b written. NOT COMPILED
- Matt's four decisions: **every 3 h; the background fetches a new cell's
  height; `Background.exit()`; clear-sky fetched now and shown in v1b.** He
  asked for the optional UV grid test to join the next round of GPS testing -
  it is step 5 of "Testing v1b".

**What v1b contains**

| File | Change |
|---|---|
| `manifest.xml` | `Background` permission |
| `UvFetch.mc` (new) | Shared by foreground and background: the request (now `hourly=uv_index,uv_index_clear_sky`), the parser (uniform-step check and -1 sentinel, moved from `UvForecast.ingest`), and the key names passed between processes. `(:glance :background)` |
| `UvBackground.mc` (new) | The `ServiceDelegate`. Reads the stored position, fetches, parses, and exits with the series plus the cell height - fetching the height itself for a cell it has not measured. Every path ends in exactly one `Background.exit()`. Logs `mem=used/total` |
| `UvGuardApp.mc` | `(:background :glance)` on the class. `getServiceDelegate()` returns an array. `onBackgroundData()` hands the payload to `UvState`. `registerRefresh()` registers the 3-hour temporal event from `getInitialView()`, leaving an existing identical registration alone |
| `UvState.mc` | `receiveBackground()`: saves the series and height, remembers the cell, records the result for diagnostics, and drops a payload older than what is stored. `effectiveClearNow()`. Position keys shared with `UvFetch` |
| `UvForecast.mc` | `adopt()` replaces `ingest()`. `clearValues` stored under `fc`. Interpolation shared by UV and clear-sky. Freshness by cell, not 25 km |
| `UvCell.mc` | `(:glance :background)`. `row()` / `col()` / `sameCell()`. Four cells remembered under `cells`; the v1c keys `cla`/`clo`/`ch` are orphaned |
| `UvClient.mc` | Uses `UvFetch` and `UvCell.heightParams`. Console gains `clr=` |
| `UvMainView.mc` | Position saved on every `onShow()`. Reading page: "up to X if sky clears". Diagnostics: a `bg` line |
| `UvGlanceView.mc` | Reads the barometer on every draw (guarded by `Toybox has :Activity`), in memory only |
| `UvNum.mc` | `(:glance :background)` |

**Choices made inside the decisions, for the record**
- **The clear-sky margin is 0.5 UV index**, absolute rather than a percentage.
  The bands are absolute (3, 6, 8, 11), and at night or under a clear
  forecast the two figures are the same, so the line disappears exactly when
  it has nothing to say
- **The clear-sky figure is corrected like the big number** (altitude and
  surface), so the two are comparable on screen. The console `clr=` is the
  raw API value, like `raw=`
- **A background payload older than the stored series is dropped**, so a
  START press during a background run cannot be overwritten by the run
- **The glance writes Storage** only in `receiveBackground()`. Forum reports
  say this is the usual pattern; it has not been seen on this device
- **Position saved on every show**, so the background fetches for where the
  watch last was. The review's finding 3 asked for this once v1b existed

**Known gaps, stated plainly**
- **The background's own new-cell path cannot be reached by ordinary
  simulator steps.** Opening the app in a new cell makes the foreground fetch
  and measure it first (freshness is by cell now), so the background only
  meets an unmeasured cell if the foreground's height request failed. It is a
  backstop. It will be seen working, if ever, on the watch
- **A slow height request can cost the whole background run.** The service
  has 30 seconds; if the second request is still out when it is killed, the
  UV series from the first is lost with it. The next run, 3 hours later,
  tries again. Rare, because heights are remembered
- **When the new CAMS run actually lands** is from Open-Meteo's source
  ("delay of 8 hours"), not observed. The 3-hour cadence was chosen so it
  does not matter
- **Storage writes from the background** are from Garmin's documentation as
  quoted by search; the pages themselves are blocked from here

**Riskiest for the compiler**, in order: `(:background :glance)` on the app
class and the scope checks it sets off - the method most likely to be named
is whichever touches a class that only exists in one process; `instanceof`
narrowing on `Background.getTemporalEventRegisteredTime()`; `Toybox has
:Activity` and `Activity` inside the glance. All `Any`-handling is in
`(:typecheck(false))` functions per the project's convention, and every
compound null test before arithmetic is split.

- Build plan updated: the architecture diagram's "every 30 min" and the
  background-storage paragraph
