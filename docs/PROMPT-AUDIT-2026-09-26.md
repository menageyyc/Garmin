# Prompt audit - 2026-09-26

Run as `/claude-api prompt-audit` on branch `claude/api-prompt-audit-lxundf`.
**No audited file has been edited.** The fixes are proposed below as a diff
(`docs/prompt-audit-2026-09-26.patch`). Take the hunks you want and leave the
rest.

## Assumptions (Step 0)

- **Scope:** everything in this repository that an AI agent reads as
  instructions:
  - `CLAUDE.md`, read by every Claude session
  - `.github/copilot-instructions.md`, read by GitHub Copilot in VS Code
  - `docs/STATE.md`, which `CLAUDE.md:11` tells every session to read before
    doing anything. Its resume block, current-phase section, open questions,
    decisions table and rejected-approaches table act as rules. The session
    log is a record, so it was used as evidence, not audited as instructions
  - `docs/REVIEW-BRIEF-v1a.md`, the prompt written for the Fable 5.1 cold
    review

  Every line of those four files was read.
- **Not audited as prompt text:**
  - `docs/TOOLCHAIN.md` and `README.md`, which are written for Matt
  - `docs/REVIEW-v1a-findings.md`, which is a model's output
  - The linked build-plan artifact, which is outside the repo and was not
    fetched
  - Nothing outside the repo, such as `~/.claude/`
  - `.vscode/settings.json` was only searched for prompt, model and Copilot
    keys. There were none
  - There is no `.claude/` folder, no skills, no subagents, no hooks
- **No application code calls an LLM.** The app is Monkey C calling
  Open-Meteo. So Group 3 (tool descriptions) and Group 4 (request config)
  **do not apply**.
- **Target model:**
  - Claude Opus 5.5 for `CLAUDE.md` and `docs/STATE.md`. That is the model
    running this audit, and the project moved to it on 2026-09-23
    (`STATE.md:220`, `:1007`)
  - Claude Fable 5.1 for the review brief, which was written for it
  - `.github/copilot-instructions.md` is read by GitHub Copilot, which runs
    whatever model is selected in VS Code, possibly not an Anthropic one. Its
    findings are about facts in the repo, which apply to any model
- **Newer vs older passages** were ordered with `git blame`, never file dates.

## Summary

The instruction files are **well written for current models**. Every hard
constraint and Monkey C convention in `CLAUDE.md` gives its reason. The review
brief supplies context and evidence and asks to be challenged, which is the
style current models reward. **Group 1 (dated prompt wording): zero findings.**

Every finding is **Group 2: facts that have gone stale, and files that now
contradict themselves.** `STATE.md` has grown by adding new entries, and older
passages that now contradict them were never marked. That matters here more than
usual, because `.github/copilot-instructions.md:9` tells Copilot "Do not
contradict a documented decision". `CLAUDE.md:22` tells Claude not to
relitigate settled decisions. So an unmarked superseded row is not just old
text: both agents are told to defend it.

The three with the most impact:

1. **`STATE.md:3` says "Newest entries at the top of each section". They are
   at the bottom.** The session log runs 2026-09-21 (line 337) to 2026-09-23
   (line 1755), and the decisions table is in the same order. Every session is
   told to read this file first, and this line tells it that the scoping notes
   from 2026-09-21 are the latest state.
2. **Four rows in the decisions table were overruled later and are not
   marked:**
   - the hotkey toggle (`:235`)
   - surroundings (`:261`)
   - Fable reviewing v2 (`:272`)
   - the background channel "UNDER REVIEW" (`:256`)

   Newer rows and open questions reverse each one.
3. **`CLAUDE.md:52` still says the background budget is "commonly 32 KB".**
   It was measured at 59 kB with 13 kB used (`STATE.md:32-33`, `:202`). Two
   source comments repeat the old figure.

**Counts:**

| Group | Result |
|---|---|
| 1. Dated prompt wording | 0 |
| 2. Brittle configuration files | 11 findings (9 high, 2 medium), plus 4 low-confidence flags |
| 3. Tool descriptions | not applicable |
| 4. Request config and architecture | not applicable |

**Proposed only, not applied.** The prompt-audit guide says Group 2 edits
(stale facts and contradictions) always need your confirmation. The
replacement text is based on other files in the repo, and anyone with commit
access can change those files.

---

## Findings

### 1. `docs/STATE.md:3-4` - High

- **What the file says:** "Running log. Newest entries at the top of each section."
- **Pattern:** Group 2: volatile specifics (the repo contradicts this claim)
- **Why it no longer fits:** The file itself contradicts it. The session log runs oldest to newest (2026-09-21 at line 337, the last 2026-09-23 entry at line 1755), and so does the decisions table (rows 228-292). The line dates from the first commit (756b305, 2026-09-21), when every section was still one entry long. `CLAUDE.md:11` tells every session to read this file before anything else. A model takes "newest at the top" literally, so it would treat the scoping notes as the current state.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..471264a 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -1,6 +1,7 @@
 # Project state
 
-Running log. Newest entries at the top of each section. Update this whenever a
-decision is made or a phase moves.
+Running log. Entries are appended in the order they were written, so the
+newest is at the bottom of each section; the resume block below is the current
+summary. Update this whenever a decision is made or a phase moves.
 
 **Build plan (design authority):**
```

### 2. `CLAUDE.md:52-53; also source/UvBackground.mc:27-29 and :150-153` - High

- **What the file says:** "Background service memory is the tightest budget in the project (commonly 32 KB)."
- **Pattern:** Group 2: volatile specifics (a measured value has replaced the assumption)
- **Why it no longer fits:** `STATE.md:32-33` and `:202` (question 7, answered 2026-09-23) give the measured figures: 59 kB budget, 13 kB used, "Not the 32 kB commonly quoted". The CLAUDE.md line (756b305, 2026-09-21) was written before that measurement. A session that believes 32 kB will turn down designs that fit easily. "Parse and discard" is still sound advice and is kept. The two `UvBackground.mc` comments say the same thing ("not yet measured", "commonly quoted near 32 kB"), so they are included, because leaving them would keep the stale figure in the codebase. `TOOLCHAIN.md:372` repeats it inside a v0 checklist that is already finished. That is a record, so it is left alone.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/CLAUDE.md b/CLAUDE.md
index 10eb644..d71a547 100644
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -50,6 +50,7 @@ These are settled. Do not relitigate them without a reason recorded in `docs/STA
 
 - Monkey C, Connect IQ SDK. Language and API level confirmed in `docs/STATE.md`.
-- Background service memory is the tightest budget in the project (commonly 32 KB).
-  Parse and discard; never hold a whole API response.
+- Background service memory is measured at 59 kB on the target, with v1b using
+  13 kB; the glance is ~59.9 kB (`docs/STATE.md`, question 7). Both are small
+  beside the app's 763.6 kB. Parse and discard; never hold a whole API response.
 - Layouts are resolution-relative, never pixel-hardcoded, so added devices stay cheap.
 - **Local variable types are inferred.** `var x as Float;` is a compile error.
diff --git a/source/UvBackground.mc b/source/UvBackground.mc
index 880fb95..9d60b4a 100644
--- a/source/UvBackground.mc
+++ b/source/UvBackground.mc
@@ -25,7 +25,7 @@ import Toybox.Time;
 //   That is a second request inside the same 30 seconds; UvCell remembers
 //   four cells, so it is rare.
-// - Memory is the tightest budget in the project and not yet measured for
-//   this device. The response is parsed and dropped inside onUv; only the
-//   two 48-value arrays are held across the height request.
+// - Memory: 59 kB on this device, 13 kB used (measured 2026-09-23). The
+//   response is parsed and dropped inside onUv; only the two 48-value arrays
+//   are held across the height request.
 (:background)
 class UvBackground extends System.ServiceDelegate {
diff --git a/source/UvBackground.mc b/source/UvBackground.mc
index 880fb95..49dc92b 100644
--- a/source/UvBackground.mc
+++ b/source/UvBackground.mc
@@ -148,8 +148,7 @@ class UvBackground extends System.ServiceDelegate {
     }
 
-    // The background budget is the one memory figure this project has never
-    // measured, and the tightest (commonly quoted near 32 kB). Logged at the
-    // point where the parsed series is held alongside the response, which is
-    // about as full as this process gets.
+    // Logged at the point where the parsed series is held alongside the
+    // response, which is about as full as this process gets. Measured at
+    // 13/59 kB on 2026-09-23.
     private function memoryText() as String {
         var stats = System.getSystemStats();
```

### 3. `docs/STATE.md:159-188 ("Current phase")` - High

- **What the file says:** "surface and surroundings are settable on the watch and from the phone" (:165); "The cold review is done ... Read it before v1b." (:169-170)
- **Pattern:** Group 2: time-sensitive content (the same information kept in two places has drifted apart)
- **Why it no longer fits:** This section repeats the resume block (lines 11-155) and has drifted from it. Surroundings was dropped on 2026-09-23 (decision row 274; `source/UvSettings.mc:14`). "Read it before v1b" is an instruction for a phase that is finished (line 161 says v1b is complete). The five dated paragraphs below it (176-188) repeat session-log entries (1006, 1160, 1588, 1741, 1755). The fix keeps one current statement and points to the resume block, so the information lives in one place. **Smaller alternative** if you'd rather keep the section as it is: change only "surface and surroundings are" to "the surface is" on :165 and delete "Read it before v1b." on :170.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..14ef13a 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -159,32 +159,8 @@ pushing elsewhere means he never receives the work.
 ## Current phase
 
-**v1a, v1c and v1b COMPLETE in the simulator** (v1b closed 2026-09-23; not yet on the watch). Builds clean and runs on epix Pro (Gen 2) 47mm / quatix 7 Pro
-(5.2.0). The reading page shows UV corrected for altitude and surface with the
-API's own figure beneath it; the hourly series is cached with the time and
-place it was fetched for, so a failed fetch degrades to "two hours old" rather
-than blanking; surface and surroundings are settable on the watch and from the
-phone; three pages with a page indicator, and BACK returns to the reading page
-rather than quitting.
-
-**The cold review is done: `docs/REVIEW-v1a-findings.md`.** Read it before
-v1b. Its top four findings change v1b's inputs: the `elevation` field is
-probably the point terrain height rather than the cell mean (one simulator test
-decides it), CAMS already applies a snow albedo so the app's +42% double
-counts, position and altitude are only sampled when a fetch starts so the
-distance check can never fire, and a real watch's cached fix is of unknown age.
-
-**2026-09-23: the review has been verified, and v1c written** (see that day's
-two session log entries). v1b waits for v1c, because findings 3, 4, 7 and 10
-change what v1b is built on.
-
-**2026-09-23: v1c closed.** The cell-height re-test passed on every point.
-Question 25's figures are on screen.
-
-**2026-09-23: v1b COMPLETE in the simulator.** Background refresh, glance
-delivery, clear-sky ceiling, freshness by cell. **Next: the watch, or v2** -
-see the resume block.
-
-**2026-09-23: the wrist test.** Matt chose it over v2; recommendation
-re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
+**v1a, v1c and v1b complete in the simulator; nothing on the watch yet.** The
+wrist test is next - plan in `docs/TOOLCHAIN.md`, "Testing on the watch". What
+the app does now, and what is waiting, is in the resume block at the top of
+this file; the history of each phase is in the session log.
 
 ---
```

### 4. `docs/STATE.md:235` - High

- **What the file says:** "| 2026-09-21 | One hotkey toggles session via toggle-on-launch |"
- **Pattern:** Group 2: contradicting instructions (a superseded decision is not marked)
- **Why it no longer fits:** Four other places contradict it: question 9 ("Hotkey design dead", :204), decision row 243 ("Hotkey targets exclude CIQ apps"), the rejected-approaches row at :310, and `.github/copilot-instructions.md:48-50`. Blame can't order row 235 against row 243 because both are from the first commit. But the file's own answers settle it, so this is a stale fact, not an open conflict. Copilot is told not to contradict documented decisions, so this row tells it to defend a design that is known to be dead. The fix follows the file's own convention for superseded rows (row 278).
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..bb476bc 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -233,5 +233,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 2026-09-21 | Altitude + albedo correction done on-watch | The watch's barometer beats CAMS' ~40 km grid elevation; albedo is known only to the wearer |
 | 2026-09-21 | Target Epix Pro 47 mm, 416x416 baseline | User's device |
-| 2026-09-21 | One hotkey toggles session via toggle-on-launch | App reads state at startup, flips, confirms, exits. Does not waste a second hotkey slot |
+| 2026-09-21 | ~~One hotkey toggles session via toggle-on-launch~~ **SUPERSEDED same day: CIQ apps are not hotkey targets (question 9); see "Session launched via glance carousel" below** | App reads state at startup, flips, confirms, exits. Does not waste a second hotkey slot |
 | 2026-09-21 | Checkpoint prompt: 30 min at UVI >= 6, else 60 min | Caps worst-case phantom dose at ~1.4 MED for type II. Chosen to bound error, not for comfort |
 | 2026-09-21 | Session safety rests on auto-stop, not the prompt | Background services cannot vibrate or beep, so the prompt is silent and unreliable as a nag |
```

### 5. `docs/STATE.md:256` - High

- **What the file says:** "**UNDER REVIEW 2026-09-23:** ... The channel choice is reopened as a v1b design decision"
- **Pattern:** Group 2: contradicting instructions
- **Why it no longer fits:** Resolved the same day by decision row 286 ("decision 3": keep `Background.exit()`, for one-writer-per-key reasons). A reader of row 256 alone is told a design question is open when v1b has shipped with it decided.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..f3e6d8e 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -254,5 +254,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 2026-09-22 | Poor GPS quality is logged, not gated on; 0,0 is a hard fail | A last-known fix is fine for a 40 km grid cell. 0,0 is the only case that silently misleads, because Open-Meteo answers for Null Island with a plausible tropical UV over HTTP 200 |
 | 2026-09-22 | v1 split into v1a (foreground) and v1b (background + glance) | Adding `(:background)` scoping to the app class is the same class of bug as the glance scoping problem that bit v0. Isolating it means a compile failure names itself instead of hiding in 600 new lines |
-| 2026-09-22 | The background service returns data via `Background.exit()`, never by writing storage | A background process gets its own snapshot of the object store, and cannot write Application Properties at all. This **corrects the build plan's architecture diagram**, which draws the service writing to storage directly. **UNDER REVIEW 2026-09-23:** the Properties half holds, but Garmin's Storage docs say a background process CAN write `Application.Storage` from API 3.2, with `onStorageChanged()` to tell the other process. The channel choice is reopened as a v1b design decision; see that day's last log entry |
+| 2026-09-22 | The background service returns data via `Background.exit()`, never by writing storage | A background process gets its own snapshot of the object store, and cannot write Application Properties at all. This **corrects the build plan's architecture diagram**, which draws the service writing to storage directly. **Reason corrected 2026-09-23:** the Properties half holds, but Garmin's Storage docs say a background process CAN write `Application.Storage` from API 3.2. `Background.exit()` was kept for different reasons - see "Background data returns through `Background.exit()`" (decision 3) below |
 | 2026-09-22 | The background service reads the last-known position from storage; the foreground writes it | `Position` calls from a background process are reported to fail with permission errors. A 40 km grid cell does not need a fresh fix, and never powering the GPS from the background is also the right battery answer |
 | 2026-09-22 | `forecast_days=2`, not 1 | `forecast_days=1` returns the current UTC day, which cuts at 18:00 local in Calgary. About 500 extra bytes buys a cache that survives an evening with no phone, and v3's forward curve needs it anyway |
```

### 6. `docs/STATE.md:261` - High

- **What the file says:** "| 2026-09-22 | Surface and surroundings are settable on the watch as well as the phone |"
- **Pattern:** Group 2: contradicting instructions
- **Why it no longer fits:** Surroundings was dropped on 2026-09-23 (row 274, rejected-approaches row 324: "Do not bring back a shade setting that scales anything less than the total"). Read on its own, row 261 is a documented decision to keep a setting that has been removed.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..4048590 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -259,5 +259,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 2026-09-22 | A failed fetch leaves the cached reading on screen, marked stale | v0 cleared the reading on every attempt because its only job was exercising the pipe. An app that blanks the moment the phone wanders out of range is worse than one that says "two hours old" |
 | 2026-09-22 | An irregular hourly series is a failed fetch, not a degraded mode | Storing base-plus-step instead of a parallel timestamp array halves the storage, but is only safe if the step really is uniform. Verified across the whole array at parse time; refusing loudly beats mis-indexing quietly |
-| 2026-09-22 | Surface and surroundings are settable on the watch as well as the phone | They are situational - you change the surface on arriving at the ski hill, not on install. Both routes write the same `Application.Properties` store, so neither shadows the other |
+| 2026-09-22 | Surface ~~and surroundings~~ settable on the watch as well as the phone (surroundings dropped 2026-09-23, see below) | They are situational - you change the surface on arriving at the ski hill, not on install. Both routes write the same `Application.Properties` store, so neither shadows the other |
 | 2026-09-22 | Skin type deferred from v1 to v2 | Nothing in v1 consumes MED; burn time and dose are v2 and v3. Shipping a setting that changes nothing visible teaches people to ignore the settings screen |
 | 2026-09-22 | Storage schema versioned; the first v1 run wipes the v0 store | v0 kept a single number under a different set of keys. There is nothing there worth migrating - it is refetched within seconds - and reading an old key with new expectations is how silent wrongness starts |
```

### 7. `docs/STATE.md:272` - High

- **What the file says:** "Fable 5.1 does a review pass when v1a is green, and again at the v2 dose integrator"
- **Pattern:** Group 2: contradicting instructions
- **Why it no longer fits:** Question 24 (:220) and the 2026-09-23 log (:1007-1009) reopen the v2 half: Matt is leaning towards Opus 5.5 and hasn't decided. With the Copilot rule in place, the decisions table currently states the reverse of the open question.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..e7b4995 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -270,5 +270,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 2026-09-22 | Per-profile "this one is outdoors" setting, default off | Covers the outdoor activity recorded with GPS off, which is otherwise permanently ambiguous. Set once for Trail Run and never thought about again |
 | 2026-09-22 | GPS quality is gated on for exposure detection but deliberately NOT for the forecast fetch | Same field, two jobs. A last-known fix is fine for picking a 40 km grid cell; it is useless for telling a treadmill from a road. A future session must not "fix" this inconsistency |
-| 2026-09-22 | Fable 5.1 does a review pass when v1a is green, and again at the v2 dose integrator | It is Anthropic's most capable widely released model, for demanding reasoning and long-horizon agentic work. The dose integrator is the health-adjacent maths where being wrong matters to skin |
+| 2026-09-22 | Fable 5.1 does a review pass when v1a is green, and again at the v2 dose integrator. **The v2 half reopened 2026-09-23 - see question 24** | It is Anthropic's most capable widely released model, for demanding reasoning and long-horizon agentic work. The dose integrator is the health-adjacent maths where being wrong matters to skin |
 | 2026-09-23 | v1c (correction pass) comes before v1b | The review showed v1a's position, altitude and freshness logic - what v1b would be built on - was wrong |
 | 2026-09-23 | Surroundings setting dropped | It scaled only the reflected term, so "Enclosed: forest" left nearly all forest UV untouched while the wearer believed shade was counted. f is not a measurable quantity for the UV index. The number is for open sky; shade becomes a v2 dose pause |
```

### 8. `docs/STATE.md:210 (question 15)` - High

- **What the file says:** "Open - the first build will say"
- **Pattern:** Group 2: volatile specifics
- **Why it no longer fits:** Answered: `Menu2`, `MenuItem` and `Application.Properties` "are all now exercised" (:70-71, :874-876), and "the settings picker works" (:930-931).
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..ab3080c 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -208,5 +208,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 10 | Does v2 include the 7-day load, or today's gauge alone? | v2 scope | Open |
 | 14 | Does the phone-side App Settings editor show both list settings, and does the on-watch MENU route write the same value? | v1a settings | Open - test in simulator |
-| 15 | Does `Menu2` + `Menu2InputDelegate` behave as written on API 5.2? | v1a settings | Open - the first build will say |
+| 15 | Does `Menu2` + `Menu2InputDelegate` behave as written on API 5.2? | v1a settings | **Answered 2026-09-22: yes.** Compiled and ran; the on-watch settings picker works |
 | 16 | Does `Background.exit()` deliver to `onBackgroundData` in the glance on this device, not only in the app? | v1b glance freshness | **ANSWERED 2026-09-23 (simulator): yes.** With the glance on screen, a triggered run printed `BG delivered` and no app-view lines. Real hardware still to confirm |
 | 17 | Exact `Activity.SubSport` constant names for the indoor variants (treadmill, spin, lap swim, indoor rowing, elliptical, virtual) | v2 exposure gate | Open - read them off the local SDK's API docs, or let the compiler reject a wrong one |
```

### 9. `docs/STATE.md:214 (question 19)` - High

- **What the file says:** "**Answered 2026-09-23 (decision), awaiting compile.**"
- **Pattern:** Group 2: volatile specifics
- **Why it no longer fits:** The same cell goes on to say it was tested and re-tested ("passed"), and the log confirms it (:1443). "Awaiting compile" is out of date.
- **Confidence:** High
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..5447ffa 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -212,5 +212,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 17 | Exact `Activity.SubSport` constant names for the indoor variants (treadmill, spin, lap swim, indoor rowing, elliptical, virtual) | v2 exposure gate | Open - read them off the local SDK's API docs, or let the compiler reject a wrong one |
 | 18 | What `currentLocationAccuracy` actually reports indoors on epix Pro, versus outdoors mid-run | v2 exposure gate - this is the whole test | Open - needs a real wrist test, not the simulator |
-| 19 | Is the air-quality endpoint's `elevation` the point terrain height (DEM) or the CAMS cell mean, and does `elevation=nan` return the cell mean? | v1c - decides whether the altitude correction exists on a hill | **Answered 2026-09-23 (decision), awaiting compile.** `elevation=nan` returns nothing on this endpoint, because Open-Meteo holds no terrain heights for any CAMS domain (source code read). The app now averages 49 Elevation API heights across the cell named in the response. The new console logs `pointElev=` too, which settles what the default field means for free (the skipped part A). **Tested 2026-09-23:** `pointElev=1687 m` and `2192 m` at the two Sunshine positions (real ~1,660 / ~2,160 m), so the default field IS the point terrain height - finding 1 confirmed. The mean works (49/49 points, 1,993 m); the response's coordinates turned out to name the wrong grid, and the cell is now computed on the watch. **Re-tested 2026-09-23 on the computed cell: passed** - `51.20,-115.60` at both Sunshine positions (2,060 m), `51.20,-114.00` at Calgary (1,101 m), cache hit at the second Sunshine position |
+| 19 | Is the air-quality endpoint's `elevation` the point terrain height (DEM) or the CAMS cell mean, and does `elevation=nan` return the cell mean? | v1c - decides whether the altitude correction exists on a hill | **Answered 2026-09-23, compiled and tested.** `elevation=nan` returns nothing on this endpoint, because Open-Meteo holds no terrain heights for any CAMS domain (source code read). The app now averages 49 Elevation API heights across the cell named in the response. The new console logs `pointElev=` too, which settles what the default field means for free (the skipped part A). **Tested 2026-09-23:** `pointElev=1687 m` and `2192 m` at the two Sunshine positions (real ~1,660 / ~2,160 m), so the default field IS the point terrain height - finding 1 confirmed. The mean works (49/49 points, 1,993 m); the response's coordinates turned out to name the wrong grid, and the cell is now computed on the watch. **Re-tested 2026-09-23 on the computed cell: passed** - `51.20,-115.60` at both Sunshine positions (2,060 m), `51.20,-114.00` at Calgary (1,101 m), cache hit at the second Sunshine position |
 | 20 | Surroundings: drop it, or rework it to scale total UV? | v1c | **Answered 2026-09-23: dropped** |
 | 21 | Snow terms: accept ~+15-20% fresh / ~+5-10% old as the increment over CAMS? | v1c | **Answered 2026-09-23: accepted.** Midpoints used: +17.5% / +7.5% |
```

### 10. `docs/STATE.md:213 (question 18) and :57-58 (resume block)` - Medium

- **What the file says:** "Open - needs a real wrist test, not the simulator"; "18 (indoor GPS accuracy, a wrist test)"
- **Pattern:** Group 2: contradicting instructions
- **Why it no longer fits:** The newest log entry (:1787-1789, 2026-09-23) says the v1 wrist test *cannot* answer it: it needs a reading during a recorded activity, which v2's data field will take. The resume block lists it as something v2 needs answered first, when v2 is what answers it. Medium, not high, because it is still "a wrist test" in a loose sense. What is wrong is which build can run it.
- **Confidence:** Medium
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..97b1730 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -211,5 +211,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 16 | Does `Background.exit()` deliver to `onBackgroundData` in the glance on this device, not only in the app? | v1b glance freshness | **ANSWERED 2026-09-23 (simulator): yes.** With the glance on screen, a triggered run printed `BG delivered` and no app-view lines. Real hardware still to confirm |
 | 17 | Exact `Activity.SubSport` constant names for the indoor variants (treadmill, spin, lap swim, indoor rowing, elliptical, virtual) | v2 exposure gate | Open - read them off the local SDK's API docs, or let the compiler reject a wrong one |
-| 18 | What `currentLocationAccuracy` actually reports indoors on epix Pro, versus outdoors mid-run | v2 exposure gate - this is the whole test | Open - needs a real wrist test, not the simulator |
+| 18 | What `currentLocationAccuracy` actually reports indoors on epix Pro, versus outdoors mid-run | v2 exposure gate - this is the whole test | Open - needs a reading taken on the wrist *during* a recorded activity, which is the v2 data field's job; the v1 wrist test cannot answer it |
 | 19 | Is the air-quality endpoint's `elevation` the point terrain height (DEM) or the CAMS cell mean, and does `elevation=nan` return the cell mean? | v1c - decides whether the altitude correction exists on a hill | **Answered 2026-09-23 (decision), awaiting compile.** `elevation=nan` returns nothing on this endpoint, because Open-Meteo holds no terrain heights for any CAMS domain (source code read). The app now averages 49 Elevation API heights across the cell named in the response. The new console logs `pointElev=` too, which settles what the default field means for free (the skipped part A). **Tested 2026-09-23:** `pointElev=1687 m` and `2192 m` at the two Sunshine positions (real ~1,660 / ~2,160 m), so the default field IS the point terrain height - finding 1 confirmed. The mean works (49/49 points, 1,993 m); the response's coordinates turned out to name the wrong grid, and the cell is now computed on the watch. **Re-tested 2026-09-23 on the computed cell: passed** - `51.20,-115.60` at both Sunshine positions (2,060 m), `51.20,-114.00` at Calgary (1,101 m), cache hit at the second Sunshine position |
 | 20 | Surroundings: drop it, or rework it to scale total UV? | v1c | **Answered 2026-09-23: dropped** |
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..ae48519 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -57,5 +57,6 @@ The two candidates as they were offered, kept for reference:
    questions it needs first: 10 (7-day load in scope?), 11 (can a data field
    vibrate?), 17 (indoor sub-sport constant names), 18 (indoor GPS accuracy,
-   a wrist test), 24 (which model reviews the integrator). Hard constraints
+   which v2's data field itself will measure), 24 (which model reviews the
+   integrator). Hard constraints
    3, 4 and 7 in CLAUDE.md govern it
 
```

### 11. `docs/STATE.md:209 (question 14)` - Medium

- **What the file says:** "show both list settings"
- **Pattern:** Group 2: volatile specifics
- **Why it no longer fits:** Only one list setting is left since surroundings was removed (row 274; `resources/settings/`). The question is still open, but its wording describes the old app.
- **Confidence:** Medium
- **Action:** rewrite

```diff
diff --git a/docs/STATE.md b/docs/STATE.md
index 1396a5c..d4282df 100644
--- a/docs/STATE.md
+++ b/docs/STATE.md
@@ -207,5 +207,5 @@ re-checked and kept. Plan in `docs/TOOLCHAIN.md`, "Testing on the watch".
 | 13 | Is the manifest product id `epix2pro47mm` correct? | Build target | **Answered: yes** |
 | 10 | Does v2 include the 7-day load, or today's gauge alone? | v2 scope | Open |
-| 14 | Does the phone-side App Settings editor show both list settings, and does the on-watch MENU route write the same value? | v1a settings | Open - test in simulator |
+| 14 | Does the phone-side App Settings editor show the surface setting, and does the on-watch MENU route write the same value? | v1a settings | Open - test in simulator |
 | 15 | Does `Menu2` + `Menu2InputDelegate` behave as written on API 5.2? | v1a settings | Open - the first build will say |
 | 16 | Does `Background.exit()` deliver to `onBackgroundData` in the glance on this device, not only in the app? | v1b glance freshness | **ANSWERED 2026-09-23 (simulator): yes.** With the glance on screen, a triggered run printed `BG delivered` and no app-view lines. Real hardware still to confirm |
```

### Flags - low confidence, no edit proposed

**F-a. What the sandbox can reach: the files disagree, and the newer one
loosens the restriction.**
- The older text:
  - `CLAUDE.md:38`: "Trying a different hostname is never the workaround."
  - `STATE.md:151-152` (2026-09-22): "Claude's sandbox reaches nothing
    external except `WebSearch`"
- The newer text, `STATE.md:1400-1401` (2026-09-23): "raw.githubusercontent.com
  is reachable from the sandbox". Reading Open-Meteo's source that way was the
  evidence that found the wrong-cell bug.
- The guide's rule is to flag, not rewrite, when the newer passage allows a
  network fetch. It was not tested here, because the audit does not probe
  network paths, and cloud sessions can run under different network policies.
- **For you to decide:** should `raw.githubusercontent.com` be written into
  `CLAUDE.md` constraint 6 as a known way to read source code (not APIs), or
  was that particular session's network policy a one-off?

**F-b. `docs/REVIEW-BRIEF-v1a.md` is a finished brief, and several of its
facts have since been overturned.**
- :118, "A background service **cannot write to storage**". Overturned at
  `STATE.md:1499-1512`
- :128, background budget "unknown ... 32 kB". Overturned at `STATE.md:202`
- :74 and :84-87, the openness `f`. Dropped, row 274
- :134, "Twelve source files". There are now 16

It is the record of what the Fable reviewer was given, and
`REVIEW-v1a-findings.md` responds to it, so editing it would falsify that
record. Its *style* matches current models well. If the v2 review goes ahead
(question 24), write a new brief in the same style rather than reusing this
one.

**F-c. `STATE.md:293` and `:802-814`, :948-960 tie the prompting style to model
names** ("served Opus well and would work against Fable"). Group 2 treats
pinned model names in instruction text as fragile. Now that the project runs on
Opus 5.5, Anthropic's migration notes say Opus 5 prompts "should perform well
out of the box", and they call for re-testing only Opus 5-specific instructions
about verbosity, over-verification and scope. `CLAUDE.md` has none of those.
Nothing needs to change now. Re-check it when question 24 is decided.

**F-d. `.github/copilot-instructions.md` is clean on its own.** It agrees with
`CLAUDE.md` and `STATE.md` on every point it repeats. Its "Precedence" rule
("Do not contradict a documented decision", :9) is the reason findings 4-7
matter. The fix belongs in `STATE.md`, not in the Copilot file, whose way out
("say so to the user with your evidence", :12-14) is well judged.

---

## Not findings (checked and kept)

- **Every "never" and "do not" in `CLAUDE.md`** (lines 22, 32, 53-56, 67, 42)
  comes with its reason or a recorded compile error. Each one is a real
  project constraint, so the guide keeps them (keep-list items 1 and 5; 1e).
- **The Monkey C traps** (`CLAUDE.md:55-82`) are facts about the toolchain that
  a model cannot know without being told. Each one stops a compile error that
  actually happened from happening again.
- **The same constraints repeated** across `CLAUDE.md`, the Copilot file and
  the brief: every copy agrees, so this redundancy is doing its job (keep-list
  item 8).
- **"Do not re-litigate" / "Do not re-test this"** (`STATE.md:85`, :107, :144)
  give their reasons, and the exception for review sessions (:146-148) is
  exactly right.
- **`STATE.md:153`, "Push to the default branch
  `claude/garmin-uv-tracking-app-7y6gk6`"**: confirmed as the remote's default
  branch. This session was told to push to `claude/api-prompt-audit-lxundf`,
  and that instruction was followed. It is noted here, not treated as a
  finding.

## How to apply

In a Claude session: "apply hunks N, M from
`docs/prompt-audit-2026-09-26.patch`", or all of them. Every hunk above applies
cleanly on its own to the current files, and the combined patch applies too.
Findings 3 and 4-7 are the ones that change what an agent will do. The rest
bring the record up to date.
