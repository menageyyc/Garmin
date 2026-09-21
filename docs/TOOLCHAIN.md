# Windows 11 setup and the build loop

Target: epix Pro (Gen 2) 47 mm. Phone: Pixel 10 Pro XL (Android, which matters —
see "Why Android helps" below).

---

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

## 3. Generate your developer key

`Ctrl+Shift+P` → **Monkey C: Generate a Developer Key**

This creates the key and sets its path in the extension settings automatically.

> **Back this file up somewhere safe, outside this repo.** There is no way to
> recover it. If you ever publish to the store and then lose the key, you can
> never update that app again — you would have to publish a new listing and
> lose your users. `.gitignore` already excludes key files so you cannot commit
> it by accident.

## 4. Build and run in the simulator

1. Open this folder in VS Code.
2. `Ctrl+Shift+P` → **Monkey C: Build for Device**, or press the run/play button.
3. Pick **epix Pro (Gen 2) 47mm** when prompted.

The simulator does everything the watch does except be on your wrist, and it is
where you should spend most of your time. You can feed it a fake GPS position
(**Simulation → Position**) and watch the HTTP traffic, which is how you will
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

## What v0 should show you

The v0 screen is a diagnostic, not a design. It answers four questions at once:

| Line | What it proves |
|---|---|
| Big number | The whole pipe works end to end |
| `51.05, -114.07 (cached)` | GPS resolved, and whether it cost battery |
| `1045 m  +38 vs grid` | The barometer works, and how far off the API's grid cell is |
| `HTTP 200 OK` or a red error | Exactly which dependency failed |

That third line is the one to watch. The gap between your barometric altitude
and the API's grid elevation is the whole reason this app is worth building —
if it reads plausibly, the altitude correction in v1 has something real to work
with.

## Known unknowns to check while you are in there

- [ ] Is the manifest product id `epix2pro47mm` correct? See "Confirm the device
      id" above. Fix the one line in `manifest.xml` if it differs.
- [ ] Does `air-quality-api.open-meteo.com` return a UV value? This could not be
      tested from Claude's sandbox — egress to Open-Meteo is blocked there. If it
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
