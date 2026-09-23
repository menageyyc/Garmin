# Windows 11 setup and the build loop

Target: epix Pro (Gen 2) 47 mm. Phone: Pixel 10 Pro XL (Android, which matters —
see "Why Android helps" below).

---

## 0. Install Java first

**The Monkey C compiler and language server are both Java programs.** Without a
JVM on PATH the extension fails at startup with:

```
Monkey C Language Server client: couldn't create connection to server.
Launching server using command java failed. Error: spawn java ENOENT
```

`ENOENT` means the `java` executable was not found. It says nothing about the
SDK.

1. Install **[Eclipse Temurin JDK 21 (LTS)](https://adoptium.net/)**, Windows
   x64. Temurin is the standard free build; Oracle's JDK carries licensing
   conditions you do not need. Garmin's documented floor is Java 8 or higher, so
   a current LTS is comfortably above it.
2. **In the installer, explicitly enable "Add to PATH" and "Set JAVA_HOME
   variable".** On Temurin's Windows installer these are optional features and
   are not always on by default. Missing this is how people install Java and
   still get `ENOENT`.
3. **Fully quit and reopen VS Code.** Not "Reload Window" — the process needs to
   restart to inherit the new PATH.
4. Verify in a *new* terminal:

   ```
   java -version
   ```

## 1. Install the SDK

1. Go to **https://developer.garmin.com/connect-iq/sdk/** and download the
   **Connect IQ SDK Manager** for Windows.
2. Sign in with a Garmin account (free — the same one your watch uses is fine).
3. In the SDK Manager, download the **latest SDK**. When it asks whether to make
   it the active SDK, say yes.
4. Still in the SDK Manager, open the **Devices** tab. Devices are grouped by
   **API level**, and each group shows how many are installed — by default most
   are not. Expand the groups, find **epix Pro (Gen 2) 47mm**, and install it.

   > The simulator cannot emulate a device you have not downloaded, and the
   > compiler cannot target one either. This is the most common reason a first
   > build fails.

   While you are there, **note which API level group epix Pro appears under**.
   That is the device's real API level and it tells us what the app may use.
5. Close the SDK Manager.

### Confirmed setup

| | |
|---|---|
| SDK | Connect IQ **9.2.0** (June 9 2026) |
| Device | **epix Pro (Gen 2) 47mm / quatix 7 Pro** |
| Device API level | **5.2** |
| Manifest `minApiLevel` | **5.2.0** |

The Devices tab goes up to API level 6.0, which is Connect IQ 9. epix Pro sits
at 5.2 — a current SDK still builds for it, but do not reach for a Connect IQ 9
API and expect this watch to run it.

`minApiLevel` is set to the device's own 5.2 rather than the 3.3.0 glance floor.
Nothing in v0 needs a 5.x API, but declaring 5.2.0 stops the compiler rejecting
anything introduced between 3.3 and 5.2 — the `Communications` error constants
in `UvClient.mc` are the likely candidates. Only one device is targeted, so this
costs nothing now. When support widens in v3, lower it and add explicit `has`
checks for what older hardware lacks.

### Confirm the device id

The manifest guesses `epix2pro47mm`. Check it against the SDK's own folder names:

```
%APPDATA%\Garmin\ConnectIQ\Devices
```

Each subfolder is named with a device id. In PowerShell:

```powershell
Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Devices" -Directory |
  Where-Object Name -like "*epix*" | Select-Object Name
```

If the id differs, change the one line in `manifest.xml`. Nothing else depends
on it.

### A freebie for later

The Devices list pairs products that share a profile. **epix Pro (Gen 2) 47mm is
the same target as quatix 7 Pro**, the 51mm covers D2 Mach 1 Pro and tactix 7
AMOLED, and epix (Gen 2) covers quatix 7 Sapphire. So the v3 widening is cheaper
than it looks: three resolutions across the epix Pro family (390, 416, 454) reach
six or more actual products.

## 2. Install the VS Code extension

1. Install **Visual Studio Code** if you do not have it.
2. Extensions (`Ctrl+Shift+X`) → search **"Monkey C"** → install the one
   published by **Garmin**.
3. Restart VS Code.
4. `Ctrl+Shift+P` → **Monkey C: Verify Installation**. Fix anything it reports
   before going further — it is much easier to debug here than during a build.
   This step catches the Java problem above, among others.

## 3. Generate your developer key

**Garmin does not issue you a key. You create one yourself.** Nothing during the
SDK install hands you a key, and there is no account page to fetch one from — if
you were waiting for one to appear, it never will. Every Connect IQ app is
signed with your own RSA 4096-bit private key, and this step makes it.

`Ctrl+Shift+P` → **Monkey C: Generate a Developer Key**

It asks where to save. **Choose somewhere outside this repository** — something
like `C:\Users\<you>\.garmin\developer_key.der`. The extension then sets the
path in its own settings automatically, so there is nothing further to configure.

`Monkey C: Verify Installation` checks for this key along with the SDK and Java,
so it will fail until the key exists. That failure is expected before this step,
not a sign anything is broken.

> **If you move or rename the key file, the stored path breaks.** The extension
> saved the path when it generated the key, and it does not follow renames.
> Re-run `Ctrl+Shift+P` → **Monkey C: Set Developer Key** (or the generate
> command), choose **Select existing developer key**, and browse to the file's
> new name. Keep the `.der` ending intact — Windows hides file extensions by
> default, so check via right-click → Properties if unsure.

> **How much does losing it actually matter?** It depends entirely on whether
> you publish.
>
> - **Sideloading only:** near enough zero. Generate a new one and carry on.
> - **Published to the store:** the key identifies your app listing. Lose it and
>   you can never update that app again — you would have to publish a new
>   listing and abandon your users.
>
> Since you cannot know today whether this app gets published later, back the
> file up somewhere outside the repo. It costs nothing now and cannot be
> recovered later. `.gitignore` already excludes `*.der` so it cannot be
> committed by accident.

## 3b. Get the code onto your machine

Do this once. Afterwards, updating is a double-click.

**Install git** — open PowerShell (Start → type "PowerShell" → Enter) and run:

```powershell
winget install --id Git.Git -e --source winget
```

winget ships with Windows 11, so nothing to download first. Accept the UAC
prompt if it appears. **Then fully quit and reopen VS Code** so it picks up the
new PATH.

**Clone the repo** — in VS Code:

1. `Ctrl+Shift+P` → **Git: Clone**
2. Paste `https://github.com/menageyyc/Garmin.git`
3. Choose a parent folder — something short like `C:\Users\matt\dev`. Git
   creates the `Garmin` folder inside it, so do not make one yourself
4. When it asks, choose **Open** to switch to the cloned folder

The repo is public, so no login is needed, and the working branch is the repo's
default branch, so there is nothing to switch to.

**Delete the old ZIP folder** once the clone works, so there is no confusion
about which copy is live.

### Updating afterwards

Three ways, all equivalent — use whichever you remember:

- **Double-click `update.bat`** in the project folder. Prints whether it worked.
- **Click the sync icon** in VS Code's bottom-left status bar, beside the branch
  name. `.vscode/settings.json` enables autofetch, so a "↓1" appears there
  within a few minutes of a push.
- `Ctrl+Shift+P` → **Git: Pull**

Then press **F5**. No more re-downloading, no more copying folders.

## 4. Build and run in the simulator

**Open the project folder first.** This is the step that silently breaks
everything else. VS Code must have the folder *open as a workspace* — browsing
to it inside a file dialog is not the same thing. If the welcome tab still says
"You have no recent folders", no project is open and the build has nothing to
work on.

1. **File → Open Folder**, and pick the extracted repo folder — the one
   containing `manifest.xml`, `monkey.jungle`, `source` and `resources`.
   A ZIP usually extracts into a nested folder, so you may need to go one level
   in: `garmin\Garmin-claude-garmin-uv-tracking-app-7y6gk6\`, not `garmin\`.
2. Confirm the file list in the left sidebar shows `manifest.xml` and
   `monkey.jungle` at the top level. If it does not, you opened the wrong folder.
3. `Ctrl+Shift+P` → **Monkey C: Build for Device**.
4. It asks two things in turn:
   - **Select Output Folder** — where to put the built `.prg`. Use `bin` inside
     the project (create it if the dialog offers "New folder"). `.gitignore`
     already excludes `bin/`.
   - **Device** — pick **epix Pro (Gen 2) 47mm**.
5. If the device prompt never appears, the extension has not recognised the
   project. That is almost always the folder problem in step 1.

To run in the simulator instead of producing a file, press **F5**. That is the
faster loop and where most work should happen.

The simulator does everything the watch does except be on your wrist, and it is
where you should spend most of your time. You can feed it a fake GPS position
(**Settings → Set Position**) and watch the HTTP traffic, which is how you will
debug the Open-Meteo call without going outside.

---

## 5. Getting it onto the actual watch

**Yes, you connect the watch to the laptop by USB.** Use the charging/data cable
that came with it — the proprietary 4-pin connector on the watch end.

The important detail: **epix Pro mounts as an MTP device, not a USB drive.**
Garmin removed USB Drive Mode on the fenix 7 / epix Gen 2 generation. On
Windows 11 this is fine — MTP is native — but it means the watch appears under
*This PC* as a portable device rather than getting a drive letter, and some
command-line tools cannot write to it. File Explorer can.

**To sideload:**

1. Build the `.prg` (**Monkey C: Build for Device**). It lands in `bin/`.
2. Connect the watch by USB.
3. In File Explorer, open the watch → `Internal Storage` → `GARMIN` → `APPS`.
4. Copy the `.prg` in.
5. Eject the watch properly and disconnect.

The app appears in the app list, and its glance appears in the glance carousel.

> Expect the `.prg` to **vanish** from `GARMIN\APPS` after the watch processes
> it — installed apps are moved into storage you cannot browse. That is normal,
> not a failed copy. A `.SET` file with a matching name shows up under
> `GARMIN\Apps\SETTINGS` once the app is accepted.

---

## Why Android helps

Connect IQ web requests travel over whichever pipe is available: Bluetooth via
the phone, WiFi, or LTE. On iOS, `makeWebRequest` commonly fails with
`BLE_CONNECTION_UNAVAILABLE` unless Garmin Connect is open or was opened
recently. **On Android this is far less fragile** — the Pixel keeps the link
alive in the background, so requests generally just work.

epix Pro also has WiFi, so some fetches may complete with no phone nearby at
all. Do not design around that — treat it as a bonus, not a guarantee.

---

## First run in the simulator

**Windows Firewall will prompt for `simulator.exe`. Allow it.** The simulator
makes the web request on the app's behalf, so blocking it makes every fetch fail
in a way that looks like an API fault rather than a firewall.

**Give the simulator a position.** It has no GPS. The menu is
**Settings → Set Position** — *not* the Simulation menu, which is where this
document used to send you. Without a position the app correctly reports
"No position" and never calls the API.

**It is one field, not two.** The dialog takes latitude and longitude together
as a single comma-separated string in decimal degrees, and rejects anything
else with *"Please enter position in latitude, longitude format in degrees"*.
Six decimal places, comma and space:

```
13.756331, 100.501765
```

The simulator's own default is `38.856147, -94.800953` — Olathe, Kansas, which
`Position.getInfo()` already returns as a cached fix, so a fetch works with no
position set at all.

If the position line still reads "No position" after setting one, fall back to
**Simulation → FIT Data → Simulate Data**. Some builds of the simulator only
populate position once data is being generated or played back.

**Altitude does work in the simulator.** An earlier version of this document
predicted "No altitude" from *Set Position* alone. That was wrong — observed
2026-09-22, `Activity.getActivityInfo().altitude` returns the simulator's
default of about **-18 m** with no FIT data playing at all. The altitude line
reads `-18 m` and carries no `vs grid` suffix until a fetch succeeds and
supplies the API's grid elevation. Use **Simulation → FIT Data → Simulate
Data** if you want a realistic varying altitude rather than the default.

**The simulator launches the GLANCE, not the app, by default.** This is the
single most confusing thing about running this project, because the glance
renders perfectly and then does nothing — which is exactly what it is supposed
to do. The glance never fetches; it only displays what the app already saved.

How to tell which one you are looking at:

| | Glance | App |
|---|---|---|
| Text | small `UV` and `--`, **left-aligned**, near the top | big **centred** number, `UV INDEX`, three diagnostic lines, `START = retry` |
| Memory readout | around `6.8/59.9kB` | far larger — a watch-app on epix Pro has roughly a megabyte |

**The fix is in the simulator's own menu bar, not VS Code:**
**Settings → Glance Launch Mode → Launch in Normal Mode.** Then re-run (F5, or
the restart arrow on VS Code's debug toolbar).

**Press START to refetch.** You do not have to restart the app between
attempts. The screen shows `START = retry` at the bottom as a reminder.

**Watch the console, not just the screen.** Three small lines on a round screen
is a poor channel for what we are actually trying to learn. The app now prints
the GPS fix and its quality, the barometric altitude, the outgoing request, and
on success a line like:

```
UV OK uv=4.35 gridElev=1048 m idx=20/24 slot+1873s
```

`gridElev=ABSENT` would mean the response carried no `elevation` field.
`slot+Ns` should land between 0 and 3599 — anything outside that means the UTC
hour alignment is wrong. Copy the whole console output back rather than
retyping the screen.

## What v0 should show you

The v0 screen is a diagnostic, not a design. It answers four questions at once:

| Line | What it proves |
|---|---|
| Big number | The whole pipe works end to end |
| `51.05, -114.07 (cached)` | GPS resolved, and whether it cost battery |
| `1045 m  +38 vs grid` | The barometer works, and how far off the API's grid cell is |
| `HTTP 200 OK`, `Fetching...`, or a red error | Exactly which dependency failed, or that one is still in flight |

That third line is the one to watch **on the watch**. The gap between your
barometric altitude and the API's grid elevation is the whole reason this app
is worth building — if it reads plausibly, the altitude correction in v1 has
something real to work with.

**In the simulator this reads about `-18 m` with no `vs grid` suffix** until a
fetch succeeds. The suffix is the interesting half and needs a working fetch to
appear at all.

## Known unknowns to check while you are in there

- [ ] Is the manifest product id `epix2pro47mm` correct? See "Confirm the device
      id" above. Fix the one line in `manifest.xml` if it differs.
- [x] **ANSWERED 2026-09-22: yes.** `HTTP 200 OK`, with a correct grid
      elevation of 336 m for Olathe. Left below for the reasoning. The
      **documented** contract has now been verified and matches what the client
      assumes: `uv_index` is a valid hourly variable on this endpoint, it is
      CAMS-sourced, the response carries a top-level `elevation` field,
      `forecast_days` accepts 0–7, and `timeformat=unixtime` returns GMT+0
      epoch seconds against a default `timezone=GMT`. What remains untested is
      the live call — egress from Claude's sandbox is an allowlist and blocks
      every external host, so this can only be settled on your machine. If it
      fails, the fallback is the main forecast API, whose `uv_index` comes from
      GFS rather than CAMS. `BASE_URL` in `source/UvClient.mc` is the only line
      that changes.
- [ ] **Can a data field call `Attention.vibrate()` on this device?** Not needed
      for v0, but v2's entire alerting design rests on it. Worth ten minutes in
      the simulator before we build on the assumption.
- [ ] Note the app memory budget the simulator reports. Background services are
      commonly capped near 32 KB and that is the tightest constraint in the project.

## `monkeyc` is not on PATH, and that is normal

Running `monkeyc` in a terminal will fail even with the SDK correctly installed.
The SDK Manager does not add its `bin` folder to PATH. **A failing `monkeyc`
command is not evidence that the SDK is missing.**

You do not need the CLI. The VS Code Monkey C extension finds the SDK itself.
Verify the installation the supported way instead:

`Ctrl+Shift+P` → **Monkey C: Verify Installation**

If you *want* the CLI anyway, the compiler lives at:

```
%APPDATA%\Garmin\ConnectIQ\Sdks\<sdk-folder>\bin
```

Add that folder to your PATH. Note the folder name carries the SDK version, so
it changes on every SDK update and the PATH entry has to be updated with it —
another reason to prefer the extension. Once on PATH, running `monkeyc` with no
arguments prints usage, which is the reliable check.

## If the build complains about type annotations

Monkey C's type checker has several strictness levels and the default changes
between SDK releases. If you get errors about `as Float or Null` style
annotations rather than about real logic, lower it:
**Settings → search "monkeyC typeCheckLevel" → set to `Gradual` or `Silent`**.
That is a v0 convenience. Worth tightening once the toolchain is proven.

---

## Testing v1a

v1a replaces the v0 diagnostic screen. Same build loop - F5, simulator - but
what you are looking at is different, and there is a settings route now.

### The buttons

| Button | Does |
|---|---|
| **START** | Force a refresh. Always fetches, even when the cache is fine |
| **DOWN** / **UP** | Turn the page: reading -> diagnostics -> settings |
| **BACK** | Return to the reading page. From the reading page itself it leaves the app - that is the platform default, not a crash. Press F5 to relaunch |
| **MENU** | Same settings, as a shortcut. **Long press of UP** on this hardware; in the simulator the keyboard shortcut is **M** |

Three dots at the bottom show which page you are on. On the settings page,
START opens the picker instead of refreshing - the hint line says which.

The hint line is per-page: `START refresh`, `DOWN for settings`, `START to
change`. **If it instead reads `START refresh  MENU set` with the last letter
clipped off the edge, you are running a stale binary** - stop the debug session
before pressing F5, or the simulator serves the old `.prg` without rebuilding.
Three dots below it show the page. No dots means a stale binary too.

### Page 1 - the reading

The big number is now the **corrected** UV index, not the API's. Underneath:

```
        13.5
     VERY HIGH
      API 9.5
   +10% altitude
  +43% fresh snow
    4 min ago
```

- `API 9.5` is what Open-Meteo said for the grid cell, before the watch
  touched it. It is on the first page deliberately - "this app disagrees with
  every other UV app" deserves an answer without a page turn
- A correction that rounds to 0% is **not printed**. In a city, on grass, both
  do, and the line reads `no correction`. That is correct, not a fault
- The last line is freshness: `Just now`, `12 min ago`, `2 h old` in yellow,
  `Cache expired` in orange, or a fetch error in red

**In the simulator the altitude correction will look odd, and that is
expected.** The simulator reports a fixed `-18 m` regardless of position, so
against Olathe's 336 m grid elevation you get about `-35% altitude`. The
arithmetic is right; the input is fake. Use **Simulation -> FIT Data ->
Simulate Data** for a realistic altitude.

### Page 2 - diagnostics

Everything v0 showed, plus the series index:

```
   DIAGNOSTICS
 38.86, -94.80 (cached)
 -18 m / grid 336 m
 HTTP 200  idx 14/48
 Fresh snow, open
    4 min ago
```

`idx 14/48` is the hour slot within the cached series. 48 because v1 asks for
two days, not one - `forecast_days=1` returns the current *UTC* day, which cuts
at 18:00 local in Calgary and leaves the cache useless all evening.

### Changing the settings

Two routes, both writing the same store.

**On the watch:** MENU -> Surface -> pick one. (v1a also had Surroundings; removed in v1c.) The number on
the reading page changes as soon as you back out. This is the route that
matters - you change the surface when you arrive at the ski hill, not when you
install the app.

**From the IDE:** `Ctrl+Shift+P` -> **Monkey C: Edit Application Settings**.

> **Do not use the simulator's own File menu settings editor.** It has a
> long-standing bug where it ignores `listEntry` values, and every setting in
> this app is a list. The IDE-side editor is the one that works. If the editor
> shows no properties at all, use the simulator's **File -> Reset All App
> Data**, then close and reopen it.

### What to watch in the console

```
UV OK raw=9.50 eff=13.54 gridElev=4 m idx=14/48 slot+707s alt=-2% albedo=+42%
```

- `raw` vs `eff` is the correction doing its job
- `slot+Ns` must land between 0 and 3599. Outside that means the UTC hour
  alignment has broken, which was confirmed working on 2026-09-22 and should
  not regress
- `idx=N/48` - a `/24` here means `forecast_days` did not take
- `Irregular series` as an error means Open-Meteo returned a non-hourly time
  array. That has never happened; if it does, the endpoint has changed shape
  and that is worth investigating rather than working around

### Known unknowns for this build

- [ ] Does `Menu2` behave as written on API 5.2? Nothing in v0 used it
- [ ] Does the IDE settings editor show both list settings?
- [ ] Does setting a value on the watch and then opening the phone-side editor
      show the value the watch wrote? Both should be reading the same store
- [ ] Note the app memory budget the simulator reports now that the glance
      scope has grown. The glance read `~6.8/59.9 kB` in v0

---

## Testing v1c

v1c is the correction pass from the v1a review. Same build loop. What changed
on screen:

- **Surroundings is gone.** The settings page and MENU go straight to the
  surface list. The settings page ends `open sky; shade not modelled`
- **Fresh snow now reads `about +17% fresh snow`**, not `+42%`. Old snow is
  `about +7%`. The other surfaces are unchanged
- **The surface word always shows.** `grass, no correction` in a city,
  `grass` under an altitude line. Any surface other than grass resets to grass
  at local midnight
- **Diagnostics has a new second line:** `live GPS fix`, `cached fix, 3 min`,
  `cached fix, age ?` or `from last fetch`
- **An expired reading draws its number grey**, not in band colour
- **The number between hours is smoothed**, so it moves a little every
  minute. The console `raw=` is the smoothed value; `hr=` is the hour's own
  value from the JSON. They differ except at the top of the hour. **That is
  not a UTC regression**

### What to watch in the console

v1c's first build also printed `elev=nan` and `(cell)`. Both are gone; the
elevation lines to watch now are in "Testing the cell height" at the end of
this file.

- `GPS cached ... age=12 s` / `age=unknown` - how old the simulator says its
  fix is. **Worth reporting either way**; nobody knows yet what the simulator
  puts there
- `Cached fix too old: 2 d` then `acquiring one-shot GPS` means the age gate
  refused the fix. If that happens on every START in the simulator and ends in
  `GPS timed out`, report it - it is the one thing in v1c that could get in
  the way of testing, and it has a small fix

### The elevation test, part B

In `STATE.md`, 2026-09-23 entry. Two positions 4 km apart, copy both `UV OK`
lines.

Done 2026-09-23: `elevation=nan` came back `gridElev=ABSENT` at both
positions. That request parameter is gone; see the next section.

## Testing the cell height

The altitude correction needs the height of the ~45 km grid cell the UV
forecast was computed for. Open-Meteo does not store that for CAMS, so the app
now works it out: it reads which cell the UV answer came from, asks Open-Meteo's
Elevation API for 49 terrain heights spread across that cell, and averages
them. Once per cell, then kept - terrain does not move.

**What to do.** Pull, stop any debug session, F5. Then in the simulator:

1. **Settings -> Set Position** -> `51.115, -115.763` (Sunshine base). START.
2. **Set Position** -> `51.078, -115.779` (Sunshine Village). START.
3. **Set Position** -> `51.045, -114.070` (downtown Calgary). START.

Copy every line from the Debug Console that starts with `UV OK`, `GET` or
`Cell height`.

**What the console should say** on the first fetch at a new cell:

```
GET https://air-quality-api.open-meteo.com/v1/air-quality lat=51.1150 lon=-115.7630 days=2
UV OK raw=... cell=51.20,-115.60 cellElev=pending pointElev=1650 m idx=... alt=0% surface=1%
GET https://api.open-meteo.com/v1/elevation cell=51.20,-115.60 points=49
Cell height 1850 m from 49/49 points, cell=51.20,-115.60 alt=-15%
```

The numbers there are placeholders, not predictions. How to read the real ones:

- **`cell=`** is the grid cell the forecast came from. Both Sunshine positions
  should give the **same** cell (`51.20,-115.60` on paper). Calgary should
  give a different one
- **`Cell height ... 49/49 points`** is the new baseline. On the second
  Sunshine position there should be **no** `GET .../elevation` and no
  `Cell height` line: the UV OK line shows `cellElev=` with a number
  straight away, because the cell was already measured. That is the cache
  working
- **`pointElev=`** is what Open-Meteo's own `elevation` field says. It is not
  used any more, only logged. If the two Sunshine positions show two
  different `pointElev` values (roughly 1,650 and 2,150), that confirms the
  review's finding 1 - the default field is the height of the exact spot -
  and it is the test "part A" that was skipped
- **`alt=-15%`** at Sunshine in the simulator, and the reading page will
  print `-15% altitude`. **That is right.** The simulator's altitude is a
  fixed -18 m, so it looks as if you are standing well over a kilometre below
  the mountain cell, and the correction's floor (a delta of -1,500 m, i.e.
  -15%) catches it. Anything other than -15% there means the cell height
  came back under about 1,480 m. On the watch the barometer supplies the
  real height
- **`Cell height failed: ...`** means the second request failed. The UV
  reading still shows, the diagnostics page says `no grid`, and the
  altitude correction is off. Report the whole line
- **`cellElev=ABSENT`** with no `GET .../elevation` after it means the
  air-quality response carried no cell coordinates. Report it; the app
  cannot pick a cell without them

The diagnostics page's third line (`-18 m / grid 1850 m`) now shows the cell
height, not the point height.
