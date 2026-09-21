# Project state

Running log. Newest entries at the top of each section. Update this whenever a
decision is made or a phase moves.

**Build plan (design authority):**
https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

---

## Current phase

**v0 scaffolded, untested.** Source is in the repo but has never been
compiled — this sandbox cannot reach Garmin to fetch the SDK. First build
happens on Matt's Windows 11 machine.

Next action: Matt installs the SDK per `docs/TOOLCHAIN.md`, builds v0 in the
simulator, and reports what breaks. Expect compile errors — nothing here has
been through a compiler. Items 6-8 and 11 all get answered during that pass.

---

## Open questions

| # | Question | Blocks | Status |
|---|---|---|---|
| 1 | Epix Pro size | First build target | **Answered: 47 mm (416x416)** |
| 2 | User's OS | SDK install + signing key | **Answered: Windows** |
| 3 | User's Fitzpatrick type | Default MED seed | **Supplied: type II (~250 J/m2) - UNRELIABLE self-report, re-derive in settings** |
| 4 | Sun detection method | v2 design | **Answered: activity + manual session** |
| 5 | Store-published or sideload-only | Review, health wording, licence | Open |
| 6 | Which API level group does epix Pro sit under in the SDK Manager? | Target API level | Open - expand the Devices tab groups |
| 7 | App + glance + background memory budgets, from local SDK | Architecture limits | Open |
| 8 | Exact manifest device ID for epix Pro 47mm | Manifest | Open |
| 9 | Do CIQ apps appear as assignable hotkey targets on Epix Pro? | Hotkey toggle | **Answered: NO. Not listed. Hotkey design dead** |
| 11 | Can a data field call `Attention.vibrate()` on Epix Pro? | v2 alerting rests on it | Open - test in simulator |
| 12 | Does `air-quality-api.open-meteo.com` return UV as expected? | v0 fetch | Open - untestable from sandbox |
| 13 | Is the manifest product id `epix2pro47mm` correct? | Build target | Open - check SDK device list |
| 10 | Does v2 include the 7-day load, or today's gauge alone? | v2 scope | Open |

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
| 2026-09-21 | Keep minApiLevel at 3.3.0 | Permissive, and epix Pro is well above it. Raise only for a specific newer API |
| 2026-09-21 | Target the 5.x-era API surface, not Connect IQ 9 | Epix Pro (Gen 2) is a 2023 device and is not a CIQ 9 device |

---

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Ambient light sensor for sun detection | Not exposed to Connect IQ; open request since ~2020, never shipped |
| GPS signal quality as an indoor/outdoor proxy | Battery cost too high for continuous use |
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
| Native repeating timer as a default in protect mode | The app cannot stop it either, so it keeps buzzing after the session ends. Fine in tan mode, where sessions are short |
| Fitzpatrick roman-numeral dropdown | Produces an authoritative-looking number that predicts almost nothing |

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
