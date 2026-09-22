# Review findings: UV Tracker v1a

Cold review of v1a against `docs/REVIEW-BRIEF-v1a.md`, 2026-09-22. Every source
file, both resource sets, the manifest, `STATE.md` and `TOOLCHAIN.md` were read
in full. Nothing here was compiled or run - the sandbox cannot - so every
proposal is a sketch that respects the Monkey C traps listed in the brief, not
a tested patch. Each physics or platform claim below was checked against a
primary or near-primary source, listed at the end.

Findings are ranked by how much they would matter to someone wearing this on a
ski hill. The first four are the ones that would change what the watch says on
a real Saturday. Everything after that is real but smaller.

---

## The short version

1. **The altitude correction is almost certainly zero on the hill.** Open-Meteo's
   `elevation` field is, by default, the elevation of *your exact coordinates*
   from a 90 m terrain model, not the mean height of the 40 km CAMS cell. On a
   piste the watch's barometer and that number agree, the delta is ~0, and the
   app prints "no correction" precisely where the app exists to correct. v0's
   two flat-terrain checks could not have caught this. One simulator run at a
   mountain coordinate settles it, and one query parameter fixes it.
2. **Snow is counted at least twice.** CAMS already applies a regional snow
   albedo whenever its model has more than 2 cm of snow in the cell, with an
   old/fresh distinction. A Rockies cell in February has snow in the model
   everywhere. The app then adds +42% on top. Measured clear-sky snow
   enhancement of the UV *index* is 15-25% in total, so +42% on top of a number
   that already carries some of it is an over-report of the kind the wearer
   said he most wants to avoid.
3. **The app only knows where you were the last time it fetched.** Position and
   altitude are sampled only when a fetch starts, and the freshness check
   compares the fetch position against itself, so the "moved 100 km" branch can
   never fire after a successful fetch. Check the UV at home, drive to the
   hill, open the app: Calgary's number, Calgary's grid elevation, Calgary's
   altitude, labelled current.
4. **On a real wrist the "cached fix" is wherever GPS last ran**, typically the
   end of your last activity, and the app never reads the fix's timestamp even
   though the platform provides one. The simulator hid this because its default
   position is always "right".

Then, in order: the hour-step read of the series (up to 30-50% off on the
shoulders of the day), a Surroundings setting that does not do what its label
promises, a freshness clock that measures fetch age when the data changes
twice a day, and situational settings that never expire.

The physical constants themselves (k_alt, the albedo table, water) are inside
the noise compared with the four above. Fix the structure first; the constants
are a second pass.

---

## 1. `elevation` is the terrain height at your coordinates, not the cell mean

**Kind:** physics / data contract. **Confidence: high** on the documentation,
**needs one live check** on the air-quality endpoint specifically.

**What the code assumes.** `UvClient.onResponse` reads the top-level
`elevation` and stores it as `gridElevation`, and `UvCorrection.altitudeFactor`
treats `h_watch - gridElevation` as "how far above the model's terrain you are
standing". The comments call it the grid cell's elevation throughout.

**What Open-Meteo documents.** The returned `elevation` is the height from a
90 m digital elevation model (Copernicus GLO-90) at the requested coordinates.
It is used for statistical downscaling of temperature and pressure. The docs
state that if `elevation=nan` is passed, downscaling is disabled and the
*average grid-cell height* is used instead. In other words, the number the app
wants is the one you get only by asking for it; the default is the one that
makes the correction vanish.

**Why v0 could not have seen it.** Olathe (336 m) and Bangkok (4 m) are both
flat. At a flat site the 90 m terrain height and the 40 km cell mean are the
same number to within the noise. The distinction only appears in relief, which
is the only place the correction matters.

**What it does on the hill.** At Sunshine Village (~2,200 m) the DEM says
~2,200 m, the barometer says ~2,200 m, delta ~0, screen says "no correction" or
"+0% altitude". The CAMS value was computed for the model orography of a cell
that is mostly lower terrain. The diagnostics page reads "2200 m / grid 2200 m",
which looks like the model knew the hill. This is an under-report, so it is
safe, but it silently switches off the headline feature and it makes the
diagnostics lie about what the model assumed.

**A second-order effect.** The default `cell_selection=land` picks, among the
nearby cells, the one whose model height best matches the DEM height at your
point. So in relief the app may be served a neighbouring cell rather than the
nearest one. With `elevation=nan` there is no DEM height to match against, and
`cell_selection=nearest` makes the choice explicit.

**Five-minute test in the simulator.** Set Position to `51.115, -115.763`
(Sunshine base, ~1,660 m), fetch, note `gridElev` in the console. Then
`51.078, -115.779` (Sunshine Village, ~2,160 m), 4 km away, fetch again. Two
different `gridElev` values from two points that are certainly inside the same
40 km cell prove the field is the point DEM. Then add `"elevation" => "nan"` to
`params` in `requestUv()` and repeat: the same value for both points is the cell
mean, and that value is what the correction should use.

**One caveat to carry into the test.** There is an open-meteo GitHub issue
(#1155, December 2024) reporting that `elevation=nan` returned the wrong value
at the time. Its resolution is not visible from here. If the second half of
the test does not produce a single shared number, that issue is why, and the
fallback is to keep the default field and accept the correction is unavailable,
saying so on screen rather than printing "+0%".

**What to change.** One line in the params dictionary, plus `cell_selection`
if the test shows it matters. The rest of the pipeline is already right for
the cell-mean number.

---

## 2. Snow albedo is applied on top of a model that already applied it

**Kind:** physics. **Confidence: high** that CAMS models snow; the *magnitude*
of what it already includes cannot be read from the API and is the residual
uncertainty.

**What CAMS does.** The CAMS UV processor (the same lineage as DWD's UV
forecast scheme) accounts for a regional albedo due to snow cover whenever the
model's snow depth exceeds 0.02 m. It distinguishes "old" and "fresh fallen"
snow - old when there has been no increase in snow water content for four days,
otherwise a linear transition from fresh to old - and applies four regressions
split on old/fresh and on solar zenith angle above or below 65 degrees. The
snow depth comes from the IFS, which has a proper snow analysis.

**What that means for the app.** In February every CAMS cell in the Rockies
has more than 2 cm of snow in the model. The `uv_index` the app fetches already
carries a snow enhancement for that cell. `albedoFactor` then multiplies by
1.425 for fresh snow, open. That is the same physical effect applied twice, by
two parties, neither of which knows about the other.

**How big is the real effect, measured.** For the UV index proper - horizontal
irradiance, which is what the app's headline number claims to be - snow-covered
terrain raises clear-sky erythemal irradiance by 15-25% in total (up to 22% in
one Swiss series; 23-27% in partly snow-covered Alpine terrain). Under overcast
the relative enhancement is two to four times larger, because clouds return
more of the reflected light. The mechanism is multiple scattering between the
ground and the atmosphere, which is why cloud matters and why "fraction of the
surface in view" is not the right construct (see finding 6).

So the app's +42% is at or above the *entire* clear-sky snow effect, stacked on
a number that already has some of it. On a bluebird day at the hill that is an
over-report of perhaps 20-35% on the index. On the wearer's face and under his
chin the reflected component does add substantially, which is a real argument -
but it is a *dose* argument for v2, and the number on screen says "UV index".

**The altitude coefficient has the same problem, smaller.** The published
altitude figures are measured between station pairs: 10.7% per 1000 m in the
Swiss Alps (yearly clear-sky noon mean; 17.4% direct, 8.5% diffuse), 7-16% in
Germany, 5-23% in Bolivia, and higher in winter than summer. The authors say
the seasonal variation is driven by solar elevation, *albedo* and turbidity.
The high station is snow-covered for much of the year, so some of the "altitude
effect" in those numbers is the snow at the top. Taking 0.10 from that
literature and then adding snow separately counts a slice of it again. This is
a 1-3% per 1000 m matter and is inside the noise; it is noted for the record,
not as a priority.

**What I would do.** The API cannot tell the app what albedo CAMS assumed, so
this cannot be solved exactly. The honest position for the index:

- Treat the snow setting as the *local increment over the cell*, not the whole
  snow effect. A 40 km Rockies cell is largely forest and rock; its effective
  cell-scale albedo is far below a groomed piste. A residual of roughly +15-20%
  for fresh snow and +5-10% for old snow is defensible as "the piste is brighter
  than the average of its cell". Keep the old-vs-fresh distinction, since CAMS
  makes it too.
- Print the snow term as approximate ("about +15% snow"), not as a percentage
  with implied precision.
- Later, cheaply: fetch `uv_index_clear_sky` alongside `uv_index` (about 500
  bytes). The ratio is the model's cloud transmission, and the snow enhancement
  scales with it. That is also the single most useful extra number for a skier
  (see finding 11).

Do not resolve this by keeping +42% "because it is conservative". The brief is
explicit that over-reporting is the failure mode the wearer cares about.

---

## 3. Position and altitude are only sampled when a fetch starts

**Kind:** correctness bug that is also assumption blindness. **Confidence:
high** - this is a code path, traced.

**The trace.** `UvState.latitude`, `longitude` and `watchAltitude` are written
in exactly two places: `UvClient.start()` (cached-fix branch) and
`UvClient.onPosition()`. Both are on the way to a fetch. `UvForecast.ingest()`
then copies `state.latitude/longitude` into `forecast.lat/lon`. `cacheState()`
calls `forecast.state(now, state.latitude, state.longitude)`, so after any
successful fetch the two positions are the same object's values and
`distanceKm` is 0.0 until the next fetch *starts*. The 25 km / 100 km branches
can only fire in the window between `start()` and `onResponse()`, or after a
failed fetch at a new place.

`onShow()` decides whether to fetch by asking `cacheState()`. So the decision
"have you moved?" is answered by data that only changes if you fetch.

**The Saturday.** Check the UV at home before leaving (a natural thing to do -
it is the whole point). Drive 90 minutes. Open the app at the hill. Age is
under two hours, distance is zero, state is CURRENT, no fetch. The screen shows
Calgary's UV, corrected against Calgary's grid elevation using the altitude the
barometer read in Calgary, with "1 h ago" in white. It is the "five-minute-old
fetch from the last town" case the brief says the freshness design exists to
catch, and the design cannot see it.

**The v1b consequence.** The background service is planned to read the
last-known position from storage, written by the foreground. The foreground
writes it only when it fetches, and after v1b the foreground will rarely fetch.
So the background will fetch for wherever the app last fetched in the
foreground, for as long as nobody presses START. Finding 4 makes this worse.

**What to change.** Sample the free sources on every `onShow()`, before
judging freshness, and do not persist them there:

```
// sketch, not compiled. In UvMainView.onShow(), before cacheState():
var info = Position.getInfo();
if (info != null) {
    var pos = info.position;
    if (pos != null) {
        var deg = pos.toDegrees();
        // same 0,0 guard as UvClient, plus a range guard (see finding 4)
        ...state.latitude = deg[0].toFloat(); state.longitude = deg[1].toFloat();
    }
}
var act = Activity.getActivityInfo();
var alt = (act != null) ? act.altitude : null;
if (alt != null) { state.watchAltitude = alt.toFloat(); }
```

`Position.getInfo()` and `Activity.getActivityInfo()` read what the system
already holds; neither powers a sensor. With that in place the distance check
does its job, the altitude on screen is where you are standing rather than
where you last fetched, and the position the background will read is the one
the foreground last *saw*, not last *fetched for* (persist it in `onShow` too
once v1b needs it). The glance should do the altitude half of this on draw as
well - it is a struct read, not a sensor read - subject to confirming that
`Toybox.Activity` is available in the glance scope on this device, which the
compiler will say in one cycle.

---

## 4. The cached fix on a real watch is old, and the app never asks how old

**Kind:** assumption blindness. **Confidence: high** on the platform behaviour
(Garmin's own forums, several threads, one on this exact device), **medium** on
how often it bites, which is a wrist test.

**What the platform says.** `Position.getInfo()` without an active fix returns
the last known position with `accuracy == QUALITY_LAST_KNOWN`. Developers
report that an unknown position can come back as `null`, `[0,0]`, `[180,180]`
"and other values" even with `QUALITY_LAST_KNOWN`. There is an open bug report
for epix 2 specifically where the last-known location returned a wrong,
non-null value a day after the last GPS activity. `Position.Info.when` carries
the GPS timestamp of the fix as a `Time.Moment`.

**Why the simulator hid it.** The simulator's cached fix is Olathe or whatever
you typed, and it is always "correct" because you just typed it. Every fetch
logged `quality=LAST_KNOWN`, which the log entry took as vindication of not
gating on quality. It vindicated not gating on *quality*. It said nothing about
*age*.

**On the wrist.** Before a ski activity is started, the last known position is
the end of the last thing that used GPS - a run in Calgary on Thursday. The
app fetches for Calgary, the fetch succeeds, the number is plausible, the
diagnostics say "(cached)". Nothing flags it. The brief's "deliberate
asymmetry" - a last-known fix is fine for a 40 km cell - is true when the fix
is recent and false when it is from another town, and the app cannot tell the
difference because it does not look.

**What to change.** Small:

- Read `info.when`. If it is null or older than a threshold (30-60 minutes is
  reasonable; a chairlift ride does not move you out of a cell, a drive does),
  treat the cached fix as unusable and fall through to the existing one-shot
  path, which already has its 45 s timeout. During a recorded activity the
  receiver is live and `when` is fresh, so this costs nothing on the hill.
- Log the fix age in the console line and show it on the diagnostics page
  ("(cached, 2 d)" is a very different thing from "(cached, 3 min)").
- Extend the 0,0 guard to a range guard: reject `|lat| > 90` or `|lon| > 180`.
  The `[180,180]` report is exactly the kind of value that would otherwise go
  to Open-Meteo and come back HTTP 200 with a number.

Findings 3 and 4 are one story: the app assumes it knows where you are, and it
only knows where it last fetched, from a fix of unknown age.

---

## 5. The series is read as a step function, and the hours are instantaneous

**Kind:** physics / dishonest interface. **Confidence: high.**

Open-Meteo documents that most hourly variables are instantaneous values at
the indicated hour; only accumulations like precipitation are preceding-hour
sums. So `uv_index[14]` is the model's value *at* 14:00, and `valueAt()` shows
it until 14:59:59.

UV changes fastest on the shoulders of the day, which in a Canadian winter is
most of the ski day. At 15:55 in March the 15:00 value might be 2.8 and the
16:00 value 1.7; the screen says 2.8 to one decimal place. In the morning the
error runs the other way. On the shoulders this is a 30-50% error printed with
0.1 precision - larger than either correction the app is built around.

**What to change.** Linear interpolation between `values[idx]` and
`values[idx + 1]` by the fraction of the hour elapsed. It is two array reads
and a multiply, and it belongs in `UvForecast.valueAt()` so the glance gets it
too. Handle the sentinel: if either neighbour is -1.0 (or `idx + 1` is past the
end), fall back to the step value. Since `raw` then changes continuously, the
console `raw=` line will no longer match the JSON value for the hour; note that
in the log so a future session does not read it as a UTC regression.

---

## 6. "Surroundings" does not do what the label promises, and f is not a thing

**Kind:** dishonest interface, with the physics behind it. **Confidence:
high** on the physics; the design response is a judgement call.

**The label.** "Enclosed: forest, narrow valley, street". A wearer choosing it
believes they have told the app they are in shade.

**What it does.** It multiplies the *reflected* term by 0.10 instead of 0.50.
The direct beam and the sky-diffuse component - which together are all of the
UV in a forest - are untouched. Enclosed + old snow reads as API + 5%. Enclosed
+ grass reads as "no correction".

**What forests and streets actually do.** Measured: a tree canopy cuts
erythemal UV by about 90% when it blocks the sun and about 40% when it does
not; per-species protection factors run 1.3-3.4. High-rise street canyons leave
about 10% of the unobstructed exposure at noon. So "Enclosed" shows roughly the
API number while reality is 0.1-0.6 of it. Relative to what the wearer thinks
they set, that is an over-report by a factor of two to ten.

**Why f cannot be rescued by tuning.** The brief asks whether "fraction of the
reflecting surface in view" corresponds to anything measurable. For the UV
*index* - horizontal irradiance - it does not. The snow enhancement of the
index comes from light bouncing between the ground and the atmosphere (hence
larger under cloud), not from how much ground a person can see. The quantity
that does describe enclosure is the sky view factor, and it scales the *whole*
diffuse component, not the reflected part. f = 0.5 × 0.85 landing near the
measured snow range is a coincidence of two guesses.

**What I would do.** Either of these is honest; the current half-measure is
not:

- **Drop Surroundings from v1.** Say plainly that shade is not modelled, that
  the number is for open sky. Shade belongs in v2 as a dose *pause*, which is
  already the design for "in the shade, dose stops". This is my recommendation:
  it removes a setting that misleads and costs nothing the app is currently
  delivering.
- **Or make it scale the total** with wide factors and honest labels
  ("Partly shaded: about half", "Under trees: a fifth or less"). That is a
  bigger design and a range display, and it still cannot tell direct shadow
  from open shade.

If Surroundings stays, its options should at least be renamed so that "open"
means "on the snowfield/beach" and nothing implies shade is accounted for.

---

## 7. Freshness measures fetch age, but the data changes twice a day

**Kind:** assumption blindness, with a v1b battery consequence. **Confidence:
high** on the cadence.

CAMS global is updated every 12 hours (00 and 12 UTC runs). The forecast the
app fetches at 09:00 and again at 11:00 is the same model run and the same
numbers. So the comment in `UvForecast` - "past two hours the cloud state it
described has moved on" - describes a nowcast, and this is a forecast. Two
hours after a fetch, refetching returns the same value; the yellow "2 h old"
implies degradation that has not happened and a fix that a refetch will not
provide.

For v1a this is theatre rather than harm. For v1b it is a design input: a
30-minute background refresh of a twice-daily product spends the phone link and
battery for nothing. What actually makes the cache wrong is (a) a new CAMS run
landing, roughly every 12 h, and (b) the wearer moving to a different cell -
which is finding 3.

**What to change.** `FRESH_SECONDS` to something like 6 h (or simply drop the
"fresh" tier and keep covered/usable/expired); refetch on location change once
finding 3 is fixed; and plan the v1b temporal event around a few fetches a day
plus movement, not a half-hour clock. The 25 km / 100 km thresholds are fine
against a 40 km cell - they are just inert today.

---

## 8. Situational settings never expire, and the default hides itself

**Kind:** assumption blindness. **Confidence: high.**

Both halves of this are the genre the brief asked for.

**Sticky.** Set "Fresh snow" on Saturday at the hill. Monday's lunchtime walk
downtown shows "+42% fresh snow" over the city's number, and will every day
until someone opens the settings page. The line is visible, which is better
than invisible, but a setting described as "you change it when you arrive at
the ski hill" has no counterpart for leaving. This is a standing over-report
for the majority of the week.

**Invisible default.** On the hill, with the surface never set, the screen
shows an altitude line and nothing about surface, because grass-open rounds to
+1% and the 2% threshold hides the *word* along with the number. The one thing
the wearer needs to be told at that moment - "the app thinks you are on
grass" - is the thing that is hidden.

**What to change.** Always print the surface name on the reading page in the
dim tint, with the percentage only when it clears the threshold ("grass" in the
city, "+15% fresh snow" on the hill). And expire any non-grass surface at local
midnight or after ~12 h, back to grass. The timestamp can live in
`Application.Storage`, which needs no key declaration, rather than adding a
property. Keep the 2% threshold for the *number*; it was the word that should
not have been hidden.

---

## 9. The constants, briefly

These are all inside the noise of findings 1 and 2. They are answered because
the brief asked, not because they change what the watch says.

| Constant | Verdict |
|---|---|
| `k_alt = 0.10` | Mid-range of the station-pair literature (5-23% per km measured; 10.7% Swiss clear-sky mean), but that literature includes snow at the high station. Atmosphere-only is nearer 0.06-0.08. With snow applied separately, 0.08 is the honest mid. Fix finding 1 first; today the coefficient is multiplied by roughly zero on the hill |
| Fresh snow 0.85 | Fine as a surface albedo (UV albedo of fresh snow runs higher still, 0.9+). The problem is what it is multiplied by, not the value |
| Old snow 0.50 | Fine. CAMS uses a four-day no-new-snow rule for "old"; matching that is reasonable |
| Water 0.07 | Fine, and the low-sun worry does not matter: reflectance does climb to 0.2-0.5 at solar zenith angles above 75 degrees, but the UV at those angles is close to nothing, and reflected water contributes under 20% even to a vertical surface. Leave it |
| Sand, concrete, grass | Fine |
| Clamps | Fine. The two input clamps already bound the total factor at 1.45 × 1.60 = 2.32×; a display cap would only hide what they already bound |
| Uncapped output | Right. The high Andes routinely read above 25 and the record is 43. 12 → 24 on a glacier is physically possible; it is just not what a correctly composed correction produces at a Canadian ski hill (finding 2) |
| 2% display threshold | Right for the number, wrong for the word (finding 8) |

---

## 10. Correctness items worth a line each

- **`migrate()` runs in `onStart()`, which also runs in the background process
  once v1b adds `(:background)` to the app class.** `AppBase.onStart` fires
  before `getServiceDelegate`, so there is no flag to check yet. A schema wipe
  from the background's private storage snapshot is exactly the unreliable
  write the comment says it must never do. Move the migration into
  `getInitialView()` and `getGlanceView()`, and note that "wipe on mismatch"
  must be replaced with a real migration before v2 stores a day's dose.
- **EXPIRED still draws the number big, coloured and banded.** Only the small
  status line changes. For STALE that is right. For EXPIRED - a different sky
  or more than 12 h old - the number should be greyed, so that "a number for
  somewhere else" and "a number for here" do not look the same.
- **The corrected number is printed to 0.1.** "8.9" from a model whose terms
  are ±30% each. The band is the honest output; consider an integer or a range
  ("8-10") for the corrected value and keep the API value at one decimal,
  which matches the wearer's own stated preference in the brief.
- **`onPosition` after `cancel()`.** If `LOCATION_DISABLE` does not cancel a
  pending one-shot, a late `onPosition` on a superseded client would start a
  second web request. Low likelihood; a `_cancelled` flag checked at the top
  of `onPosition` closes it.
- **Storage `values` round-trip.** Traced; fine. Sentinel -1.0, uniformity
  check, base-plus-step, `asArray` narrowing, and the ingest-before-elevation
  ordering are all correct.

---

## 11. One thing to add rather than fix: the clear-sky ceiling

The largest error in the whole chain is not either correction. It is the cloud
forecast at 40 km over mountains. When CAMS says overcast and the hill is
bluebird, the app under-reports by a factor of two or three, with every line
on the screen looking healthy. That is the dangerous direction for skin, and
the brief's preference for under-reporting was argued from trust, not from
burns.

`uv_index_clear_sky` is one more hourly variable on the same request, roughly
500 bytes. Showing it as the ceiling - "3.1 now, up to 7 if it clears" - is
the single most honest thing the reading page could add, it is what a skier
looking at a blue sky actually needs, and its ratio to `uv_index` is the cloud
transmission that finding 2 wants for the snow term. v1b or v3; noted here so
the fetch and the storage shape can allow for it.

---

## What I checked and agree with

Recorded so the next session does not re-open them.

- The endpoint choice (CAMS erythemal over the GFS approximation), unixtime,
  `forecast_days=2`, UTC alignment, and the hour index. All sound.
- Base-plus-step storage with the uniformity check, and refusing an irregular
  series rather than degrading. Right call.
- The 0,0 guard, and the decision to refuse 0,0 as the *only* hard position
  failure. Right, with the range extension in finding 4.
- A failed fetch leaving the cached reading on screen, marked. Right.
- Never asking for a Fitzpatrick numeral; MED as a stored moving value; burn
  time as a range. Evidence-based and settled.
- The glance reading only, and sharing the correction code with the app.
- Schema versioning in storage, for v1.
- The three-page layout, the page dots, BACK returning to the reading page.

---

## Suggested order

1. Run the elevation test (finding 1). It is five minutes and it decides
   whether the altitude correction exists.
2. Sample position and altitude in `onShow()` and gate the cached fix on its
   age (findings 3 and 4). Together they are the difference between an app
   that corrects for where you are and one that corrects for where you were.
3. Cut the snow term to a local increment and label it approximate (finding
   2). Decide what to do with Surroundings (finding 6).
4. Interpolate the hour (finding 5), show the surface word always and expire it
   (finding 8), loosen the freshness clock (finding 7).
5. Move `migrate()` before v1b (finding 10). Plan `uv_index_clear_sky` into
   v1b's fetch (finding 11).

---

## Sources

Open-Meteo, elevation semantics and `elevation=nan`:
- https://open-meteo.com/en/docs (forecast API return object; "elevation" and `cell_selection`)
- https://github.com/open-meteo/open-meteo/issues/1155 (elevation=nan returning the wrong height, Dec 2024)
- https://openmeteo.substack.com/p/improving-weather-forecasts-with (the 90 m DEM and downscaling)

Open-Meteo, air-quality API, update cadence, hourly convention:
- https://open-meteo.com/en/docs/air-quality-api
- https://github.com/open-meteo/open-data (model update intervals; `cams_global` every 12 h)
- https://open-meteo.com/en/docs/ecmwf-api and sibling pages (instantaneous vs preceding-hour variables)

CAMS UV index method, snow albedo:
- https://climate-adapt.eea.europa.eu/en/observatory/evidence/projections-and-tools/cams-uv-index-forecast/uv_index_cams_background_and_methodology.pdf/@@download/file
- https://kunden.dwd.de/uvi/data/UV_forecast.pdf

Altitude effect:
- Schmucki & Philipona 2002, "Ultraviolet radiation in the Alps: the altitude effect", Optical Engineering
- Pfeifer, Koepke & Reuder 2006, "Effects of altitude and aerosol on UV radiation", JGR - https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2005JD006444
- https://acp.copernicus.org/preprints/acp-2016-210/acp-2016-210.pdf (parameterisation and the summary of measured ranges)

Snow enhancement:
- McKenzie et al. 1998, "Effects of snow cover on UV irradiance and surface albedo: A case study", JGR - https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/98JD02704
- Kylling et al. 2001, "Ultraviolet radiation in partly snow covered terrain", GRL - https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2001GL013034
- Gröbner & Hülsen, "Effect of snow albedo and topography on UV radiation" - https://niwa.co.nz/sites/default/files/effect_of_snow_albedo_and_topography.pdf
- https://csl.noaa.gov/assessments/ozone/2006/chapters/chapter7.pdf

Canopy and street canyon:
- Downs et al. 2025, Photochemistry and Photobiology - https://onlinelibrary.wiley.com/doi/10.1111/php.13988
- Na et al. 2014, Urban Forestry & Urban Greening - https://www.itreetools.org/eco/resources/NaEtAl2014_ReducingUV.pdf
- https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0135562

Water:
- https://pubmed.ncbi.nlm.nih.gov/29315607/ (The Solar Ultraviolet Environment at the Ocean)
- https://www.sasec.org.za/papers2019/8.pdf (water albedo vs solar zenith angle)

Record UV:
- https://www.science.org/content/article/record-levels-uv-measured-south-america

Connect IQ position and altitude:
- https://forums.garmin.com/developer/connect-iq/f/discussion/6626/position-accuracy-is-always-position-quality_last_known
- https://forums.garmin.com/developer/connect-iq/f/discussion/243349/questions-related-position-and-storage-apis
- https://forums.garmin.com/developer/connect-iq/i/bug-reports/toybox-activity-getactivityinfo-currentlocation-gives-wrong-values-one-day-after-activity-on-epix2
- https://developer.garmin.com/connect-iq/api-docs/Toybox/Position/Info.html (`when`, `accuracy`)
- https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html (`altitude`: barometer or GPS, may be null)
