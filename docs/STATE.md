# Project state

Running log. Newest entries at the top of each section. Update this whenever a
decision is made or a phase moves.

**Build plan (design authority):**
https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

---

## RESUMING? READ THIS FIRST

**Where things stand:** v0 compiles clean and runs in the simulator. The whole
toolchain is proven. No runtime behaviour has been confirmed yet. A round of
diagnostic hardening has been pushed but **not yet compiled** - see the
2026-09-22 log entry.

**The immediate next action** is to verify the runtime path in the simulator:

1. Allow the Windows Firewall prompt for `simulator.exe` (blocking it makes
   every web request fail in a way that looks like an API fault)
2. Set a simulated GPS position via **Settings → Set Position**. Not the
   Simulation menu - this doc said that and was wrong. Without a position the
   app correctly shows "No position" and never calls the API
3. **Watch the console, not just the screen.** The app now prints the fix and
   its quality, the altitude, the outgoing request, and on success a line like
   `UV OK uv=4.35 gridElev=1048 m idx=20/24 slot+1873s`. `gridElev=ABSENT`
   means no `elevation` field came back; `slot+Ns` outside 0-3599 means the UTC
   hour alignment is wrong
4. **Press START to refetch.** No need to restart the app between attempts

**Expect `No altitude` in the simulator.** `Activity.getActivityInfo()` is only
populated while data is being generated or replayed, so *Set Position* alone
gives a position and no altitude. That is the simulator, not the barometer and
not a bug. Use **Simulation → FIT Data → Simulate Data** to exercise the
altitude line too.

**What that settles:** whether `air-quality-api.open-meteo.com` actually returns
UV the way the client expects. The *documented* contract is now verified and
matches the client (see the 2026-09-22 entry); the *live call* is what remains.
It has never been testable from Claude's sandbox - egress there is an allowlist
that blocks every external host - so it is the single largest unverified
assumption in the project. If it fails, the fallback is the main forecast API,
whose `uv_index` comes from GFS rather than CAMS, and `BASE_URL` in
`source/UvClient.mc` is the only line that changes.

**After that works:** v1 per the build plan - altitude and albedo correction,
colour bands, glance, background refresh with caching, settings.

**Do not re-litigate** anything in `CLAUDE.md`'s hard constraints or the
"Rejected approaches" table below. Each was researched against primary sources
and cost real time to establish.

**Working with Matt:** he is technically fluent but does not write code. Explain
reasoning in plain language. He builds and tests on his own Windows machine -
Claude's sandbox cannot reach Garmin or Open-Meteo. He pulls changes by
double-clicking `update.bat`, so push to the branch and tell him to run it.

---

## Current phase

**v0 BUILDS AND RUNS.** Compiles clean and launches in the simulator on
epix Pro (Gen 2) 47mm / quatix 7 Pro (5.2.0). Now verifying runtime behaviour:
position, altitude and the Open-Meteo fetch.

Next action: confirm the runtime path in the simulator - set a simulated GPS
position, allow the firewall prompt, and see whether the Open-Meteo call
returns a UV value. That settles open question 12, which has never been
testable from Claude's sandbox.

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
| 7 | App + glance + background memory budgets, from local SDK | Architecture limits | Open |
| 8 | Exact manifest device ID for epix Pro 47mm | Manifest | **Answered: `epix2pro47mm` is correct - compiler accepted it** |
| 9 | Do CIQ apps appear as assignable hotkey targets on Epix Pro? | Hotkey toggle | **Answered: NO. Not listed. Hotkey design dead** |
| 11 | Can a data field call `Attention.vibrate()` on Epix Pro? | v2 alerting rests on it | Open - test in simulator |
| 12 | Does `air-quality-api.open-meteo.com` return UV as expected? | v0 fetch | **Contract verified against docs; live call still open** - untestable from sandbox |
| 13 | Is the manifest product id `epix2pro47mm` correct? | Build target | **Answered: yes** |
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
| 2026-09-21 | Set minApiLevel to 5.2.0, the device's own level | Stops the compiler rejecting APIs introduced between 3.3 and 5.2. Costs nothing with one device targeted. Lower it in v3 and add `has` checks |
| 2026-09-21 | Target the 5.x-era API surface, not Connect IQ 9 | Epix Pro (Gen 2) is a 2023 device and is not a CIQ 9 device |
| 2026-09-22 | v0 refetches on every show, not only when no reading is cached | The old gate meant the app retried forever while broken and never once it worked - backwards for a build whose only job is exercising the fetch |
| 2026-09-22 | Poor GPS quality is logged, not gated on; 0,0 is a hard fail | A last-known fix is fine for a 40 km grid cell. 0,0 is the only case that silently misleads, because Open-Meteo answers for Null Island with a plausible tropical UV over HTTP 200 |

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
| Concluding the SDK is broken because `spawn java ENOENT` appears | That error means no JVM on PATH. The toolchain is Java-based; install a JDK |
| Concluding the SDK is missing because `monkeyc` fails in a terminal | The SDK Manager does not put its bin folder on PATH. Verify via the VS Code extension instead |
| Native repeating timer as a default in protect mode | The app cannot stop it either, so it keeps buzzing after the session ends. Fine in tan mode, where sessions are short |
| Fitzpatrick roman-numeral dropdown | Produces an authoritative-looking number that predicts almost nothing |
| Gating the fetch on `!hasReading()` | uvIndex is persisted, so one success permanently stopped the app calling the API |
| Failing the fetch on `QUALITY_NOT_AVAILABLE` | Would block the simulator test for no safety gain. The 0,0 guard is what actually prevents a false positive |

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
