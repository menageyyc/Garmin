# Project state

Running log. Newest entries at the top of each section. Update this whenever a
decision is made or a phase moves.

**Build plan (design authority):**
https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

---

## Current phase

**Pre-v0 — scoping.** Nothing built yet. No source in the repo.

Next action: scaffold the v0 project skeleton (manifest targeting epix Pro 47 mm,
resources, one view) and get the Windows toolchain proven end to end on the
user's machine. Blocking items 6-8 are all read from the locally installed SDK.

---

## Open questions

| # | Question | Blocks | Status |
|---|---|---|---|
| 1 | Epix Pro size | First build target | **Answered: 47 mm (416x416)** |
| 2 | User's OS | SDK install + signing key | **Answered: Windows** |
| 3 | User's Fitzpatrick type | Default MED seed | **Answered: Type II (~250 J/m2)** |
| 4 | Sun detection method | v2 design | **Answered: activity + manual session** |
| 5 | Store-published or sideload-only | Review, health wording, licence | Open |
| 6 | CIQ system version (Settings > System > About) | Target API level | Open |
| 7 | App + glance + background memory budgets, from local SDK | Architecture limits | Open |
| 8 | Exact manifest device ID for epix Pro 47mm | Manifest | Open |
| 9 | Do CIQ apps appear as assignable hotkey targets on Epix Pro? | Whether the hotkey toggle survives | Open |
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
