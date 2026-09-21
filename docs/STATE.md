# Project state

Running log. Newest entries at the top of each section. Update this whenever a
decision is made or a phase moves.

**Build plan (design authority):**
https://claude.ai/code/artifact/2a4141df-b000-4c79-a063-a72a89183f17

---

## Current phase

**Pre-v0 — scoping.** Nothing built yet. No source in the repo.

Next action: confirm the open questions below, then scaffold the v0 project
skeleton (manifest, resources, one view) and get the toolchain proven end to end
on the user's machine.

---

## Open questions

| # | Question | Blocks | Status |
|---|---|---|---|
| 1 | Epix Pro size: 42 / 47 / 51 mm | First build target, layout baseline | Open |
| 2 | User's OS | SDK install + signing key commands | Open |
| 3 | User's Fitzpatrick type | Default MED seed | Open |
| 4 | v2 dose scope: today only, or today + 7-day load | v2 sizing | Open |
| 5 | Store-published or sideload-only | Review process, health wording, licence | Open |
| 6 | CIQ system version on the watch (Settings > System > About) | Target API level | Open |
| 7 | App + glance + background memory budgets, from local SDK device reference | Architecture limits | Open |
| 8 | Exact manifest device IDs, from local SDK devices folder | Manifest | Open |

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

---

## Rejected approaches

| Approach | Why rejected |
|---|---|
| Ambient light sensor for sun detection | Not exposed to Connect IQ; open request since ~2020, never shipped |
| GPS signal quality as an indoor/outdoor proxy | Battery cost too high for continuous use |
| OpenUV API | Requires a key; 50 req/day free tier; key extractable from a published app |
| Dose gauge that recovers in shade | Biologically wrong. Same-day dose does not decay |
| "No phone needed" as a capability claim | False. No Garmin watch has a UV sensor. Caching is what enables offline display |

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
