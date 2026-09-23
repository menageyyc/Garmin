import Toybox.Lang;
import Toybox.Communications;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;

// Fetches the UV forecast from Open-Meteo's air-quality endpoint and records
// the outcome in UvState.
//
// Why this endpoint and not the main forecast API: the forecast API's uv_index
// comes from GFS, which uses a simplified approximation. The air-quality
// endpoint serves CAMS, which computes biologically effective (erythemal) UV
// properly. CAMS is coarser at roughly 40 km, which is exactly why the watch's
// own barometric altitude matters - see the build plan.
//
// The endpoint's contract was verified against Open-Meteo's documentation and
// then live in the simulator on 2026-09-22: HTTP 200 at both a night and a
// daylight position, a top-level elevation field that varies correctly by
// location, and a unixtime series aligned to UTC, confirmed by catching the
// hour index advance across an hour boundary. None of that needs re-testing.
//
// One thing those tests could NOT show: both sites were flat, so they could
// not tell a point terrain height from a grid-cell mean. The 2026-09-23 review
// found the default is the point height. v1c asked for the cell's own height
// with elevation=nan, and the simulator showed the endpoint returns nothing
// for it: Open-Meteo stores no terrain heights for CAMS. So the response's
// elevation is now logged but not used, and the cell height comes from a
// second request, made once per cell - see UvCell and requestCellHeight().
//
// timeformat=unixtime keeps the payload small. ISO timestamps roughly double
// the size of the time array for no benefit on-device. Payload size is the
// usual cause of death for a Connect IQ background fetch, and since v1b the
// same request also runs in the background service, whose budget is the
// tightest in the project.
//
// This is the foreground half. The request and the parser are shared with the
// background service through UvFetch, so the two cannot drift apart (v1b).
class UvClient {

    // A one-shot acquisition that never completes used to leave requestInFlight
    // true forever: the screen sat on "..." with no error, indistinguishable
    // from still trying. Bound it so a failure names itself.
    private const GPS_TIMEOUT_MS = 45000;

    private var _onDone as Method(success as Boolean) as Void;
    private var _gpsTimer as Timer.Timer or Null = null;
    private var _gpsActive as Boolean = false;

    // Set by cancel(). If LOCATION_DISABLE does not withdraw a pending one-shot,
    // a late onPosition on a superseded client would otherwise start a second
    // web request (2026-09-23 review, finding 10).
    private var _cancelled as Boolean = false;

    // The centre of the grid cell the last UV response answered for, held
    // while its height is being fetched.
    private var _cellLat as Float or Null = null;
    private var _cellLon as Float or Null = null;

    function initialize(onDone as Method(success as Boolean) as Void) {
        _onDone = onDone;
    }

    // Resolve a position, then fetch. Tries the free cached fix first and only
    // powers up the GPS if there is nothing usable - which now includes a
    // cached fix known to be more than an hour old. See UvSense.
    public function start() as Void {
        var state = UvState.get();
        state.requestInFlight = true;
        state.clearError();

        UvSense.sampleAltitude();

        if (UvSense.sampleCachedFix()) {
            requestUv();
            return;
        }

        // Nothing usable cached. Acquire one, which costs battery and can take
        // a while outdoors and may never succeed indoors.
        System.println("No usable cached fix; acquiring one-shot GPS");
        _gpsActive = true;
        Position.enableLocationEvents(
            Position.LOCATION_ONE_SHOT,
            method(:onPosition)
        );
        startGpsTimer();
    }

    public function onPosition(info as Position.Info) as Void {
        if (_cancelled) {
            return;
        }
        cancelGpsTimer();
        stopGps();

        var state = UvState.get();

        var fix = info.position;
        if (fix == null) {
            fail(null, "No GPS fix");
            return;
        }

        var deg = fix.toDegrees();
        var latf = deg[0].toFloat();
        var lonf = deg[1].toFloat();

        // The same guard the cached path has. Without it a callback carrying
        // "no fix yet" sends the app to Null Island, and Open-Meteo answers
        // with a perfectly plausible tropical UV over HTTP 200 - a success
        // that proves nothing and hides a broken position path.
        if (!UvSense.plausible(latf, lonf)) {
            fail(null, "GPS gave no real fix");
            return;
        }

        state.latitude = latf;
        state.longitude = lonf;
        state.fixSource = FIX_LIVE;
        state.fixAgeSeconds = 0;

        // GPS altitude as a fallback if the barometer gave us nothing.
        var gpsAltitude = info.altitude;
        if (state.watchAltitude == null && gpsAltitude != null) {
            state.watchAltitude = gpsAltitude.toFloat();
        }

        // Quality is logged, not gated on. A last-known or poor fix is still
        // fine for a 40 km UV grid cell, and refusing one would block the
        // simulator test for no safety gain - every fetch there reports
        // LAST_KNOWN. 0,0 and out-of-range values are what actually mislead,
        // and they are caught above. Age is checked on the cached path, in
        // UvSense; a live fix is new by definition.
        System.println("GPS live " + latf.format("%.4f") + ","
                       + lonf.format("%.4f")
                       + " quality=" + qualityText(info.accuracy));

        requestUv();
    }

    private function startGpsTimer() as Void {
        cancelGpsTimer();
        var t = new Timer.Timer();
        t.start(method(:onGpsTimeout), GPS_TIMEOUT_MS, false);
        _gpsTimer = t;
    }

    private function cancelGpsTimer() as Void {
        var t = _gpsTimer;
        if (t != null) {
            t.stop();
            _gpsTimer = null;
        }
    }

    public function onGpsTimeout() as Void {
        _gpsTimer = null;
        stopGps();
        fail(null, "GPS timed out");
    }

    // Releases anything this client still holds, so a superseded fetch cannot
    // leave a GPS timer armed or the receiver enabled behind it. Also what
    // makes UvMainView._client a read rather than a write-only field - the
    // compiler was right to warn about that, and silencing it by deleting the
    // reference would risk the client being collected while a callback is
    // still registered against it.
    public function cancel() as Void {
        _cancelled = true;
        cancelGpsTimer();
        stopGps();
    }

    // One-shot is meant to power the receiver down on its own, but saying so
    // explicitly costs nothing and makes the timeout path unambiguous.
    private function stopGps() as Void {
        if (_gpsActive) {
            _gpsActive = false;
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    private function requestUv() as Void {
        var state = UvState.get();

        var lat = state.latitude;
        var lon = state.longitude;
        if (lat == null || lon == null) {
            fail(null, "No position");
            return;
        }

        // Persist position and altitude before the request goes out, not
        // after. They are true whatever the network does, and the glance needs
        // an altitude to correct with even when every fetch today has failed.
        state.savePosition();

        // No elevation parameter. elevation=nan was tried in v1c and returns
        // no elevation at all on this endpoint, because Open-Meteo holds no
        // terrain heights for CAMS. The cell height comes from
        // requestCellHeight() instead.
        System.println("GET " + UvFetch.UV_URL + " lat=" + lat.format("%.4f")
                       + " lon=" + lon.format("%.4f")
                       + " days=" + UvFetch.FORECAST_DAYS);
        Communications.makeWebRequest(UvFetch.UV_URL, UvFetch.uvParams(lat, lon),
                                      UvFetch.jsonOptions(), method(:onResponse));
    }

    public function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (_cancelled) {
            return;
        }
        var state = UvState.get();
        state.httpCode = code;

        if (code != 200) {
            fail(code, httpHint(code));
            return;
        }

        if (!(data instanceof Dictionary)) {
            fail(code, "Unexpected payload");
            return;
        }

        // parse() returns the series, or a String saying why not. toString()
        // hands fail() a String whether or not the checker narrows the union.
        var parsed = UvFetch.parse(data);
        if (parsed instanceof String) {
            fail(code, parsed.toString());
            return;
        }

        var now = Time.now().value();
        var forecast = state.forecast;

        if (!forecast.adopt(parsed, state.latitude, state.longitude, now)) {
            fail(code, "Irregular series");
            return;
        }

        // The baseline for the altitude correction is the height of the grid
        // cell CAMS computed for. That cell is worked out from the position
        // the series was fetched for, by the same nearest-point rounding
        // Open-Meteo uses - NOT from the response's "latitude"/"longitude",
        // which name the 0.1 degree greenhouse-gas grid mixed into the same
        // request (see UvCell.cellLat). UvCell keeps the heights of the last
        // four cells it measured. Known cell: use it now. New cell: no baseline
        // until requestCellHeight() comes back,
        // so for a second or two the correction is off and diagnostics says
        // "no grid". That is an under-report, the safe direction, and far
        // better than pairing a new cell's forecast with an old cell's height.
        //
        // Assigned only after adopt has accepted the series, for the same
        // reason: a refused fetch must not leave the old series carrying a
        // new cell's height.
        //
        // Each coordinate is read into a local and tested on its own - a
        // combined null test does not narrow the second one.
        var needHeight = false;
        forecast.gridElevation = null;
        // The cell's name for the console, as text. Built here rather than
        // from a local initialised to null: a null-initialised local is
        // inferred as Null and will not take a Float later.
        var cellText = "?";
        var fetchLat = forecast.lat;
        var fetchLon = forecast.lon;
        if (fetchLat != null) {
            if (fetchLon != null) {
                var cLat = UvCell.cellLat(fetchLat);
                var cLon = UvCell.cellLon(fetchLon);
                cellText = cLat.format("%.2f") + "," + cLon.format("%.2f");
                var known = UvCell.cached(cLat, cLon);
                forecast.gridElevation = known;
                if (known == null) {
                    _cellLat = cLat;
                    _cellLon = cLon;
                    needHeight = true;
                }
            }
        }

        forecast.save();

        state.errorText = null;
        state.requestInFlight = false;

        // The response's own "elevation" is the terrain height at our exact
        // coordinates. Not used for anything, but logged: it is the evidence
        // for what the default field means, which v1c's test part A would have
        // shown and was skipped.
        var pointElevation = UvNum.asFloat(data.get("elevation"));

        // The response's own coordinates. Logged only, as "resp=": they name
        // the 0.1 degree greenhouse-gas cell, not the UV cell, and seeing the
        // two side by side is how that was found.
        var respLat = UvNum.asFloat(data.get("latitude"));
        var respLon = UvNum.asFloat(data.get("longitude"));

        // The console is a far better diagnostic channel than five small lines
        // on a round screen. slot+Ns should land between 0 and 3599; anything
        // outside that means the UTC alignment has broken.
        var idx = forecast.indexAt(now);
        var base = forecast.baseEpoch;
        var slotText = "?";
        if (base != null && idx >= 0) {
            slotText = "slot+" + (now - (base + idx * forecast.stepSeconds)).toString() + "s";
        }

        var grid = forecast.gridElevation;
        var raw = state.rawNow();
        var hour = forecast.stepValueAt(now);
        var eff = state.effectiveNow();
        var clear = forecast.clearAt(now);
        System.println("UV OK raw=" + (raw == null ? "none" : raw.format("%.2f"))
                       + " hr=" + (hour == null ? "none" : hour.format("%.2f"))
                       + " eff=" + (eff == null ? "none" : eff.format("%.2f"))
                       + " clr=" + (clear == null ? "none" : clear.format("%.2f"))
                       + " cell=" + cellText
                       + " resp=" + (respLat == null ? "?" : respLat.format("%.2f"))
                       + "," + (respLon == null ? "?" : respLon.format("%.2f"))
                       + " cellElev=" + (grid == null ? (needHeight ? "pending" : "ABSENT") : grid.format("%.0f") + " m")
                       + " pointElev=" + (pointElevation == null ? "ABSENT" : pointElevation.format("%.0f") + " m")
                       + " idx=" + idx.toString() + "/" + forecast.hourCount().toString()
                       + " " + slotText
                       + " alt=" + UvCorrection.altitudePercent(state.watchAltitude, grid).toString() + "%"
                       + " surface=" + UvCorrection.surfacePercent(UvSettings.increment()).toString() + "%");

        _onDone.invoke(true);

        if (needHeight) {
            requestCellHeight();
        }
    }

    // The mean terrain height of the cell, from a grid of points across it.
    // One request per new cell, ever - see UvCell. The UV reading is already
    // saved and on screen by the time this runs; a failure here leaves the
    // altitude correction off ("no grid") and costs nothing else.
    private function requestCellHeight() as Void {
        var lat = _cellLat;
        if (lat == null) {
            return;
        }
        var lon = _cellLon;
        if (lon == null) {
            return;
        }

        System.println("GET " + UvCell.ELEVATION_URL + " cell=" + lat.format("%.2f") + ","
                       + lon.format("%.2f") + " points=" + UvCell.pointCount().toString());
        Communications.makeWebRequest(UvCell.ELEVATION_URL, UvCell.heightParams(lat, lon),
                                      UvFetch.jsonOptions(), method(:onCellHeight));
    }

    public function onCellHeight(code as Number, data as Dictionary or String or Null) as Void {
        if (_cancelled) {
            return;
        }
        if (code != 200) {
            System.println("Cell height failed: " + httpHint(code) + "; altitude correction off");
            return;
        }
        if (!(data instanceof Dictionary)) {
            System.println("Cell height failed: unexpected payload; altitude correction off");
            return;
        }

        var heights = data.get("elevation");
        var mean = UvCell.meanOf(heights);
        if (mean == null) {
            System.println("Cell height failed: " + UvCell.validCount(heights).toString() + "/"
                           + UvCell.pointCount().toString() + " points usable; altitude correction off");
            return;
        }

        var lat = _cellLat;
        if (lat == null) {
            return;
        }
        var lon = _cellLon;
        if (lon == null) {
            return;
        }
        UvCell.remember(lat, lon, mean);

        var state = UvState.get();
        var forecast = state.forecast;
        forecast.gridElevation = mean;
        forecast.save();

        System.println("Cell height " + mean.format("%.0f") + " m from "
                       + UvCell.validCount(heights).toString() + "/" + UvCell.pointCount().toString()
                       + " points, cell=" + lat.format("%.2f") + "," + lon.format("%.2f")
                       + " alt=" + UvCorrection.altitudePercent(state.watchAltitude, mean).toString() + "%");

        _onDone.invoke(true);
    }

    // Position.Quality is an enum whose value may also be null on some paths.
    // This exists to describe a value at runtime, which is the one job a static
    // checker cannot do.
    (:typecheck(false))
    private function qualityText(quality) as Lang.String {
        if (quality == null)                            { return "unknown"; }
        if (quality == Position.QUALITY_NOT_AVAILABLE)  { return "NOT_AVAILABLE"; }
        if (quality == Position.QUALITY_LAST_KNOWN)     { return "LAST_KNOWN"; }
        if (quality == Position.QUALITY_POOR)           { return "POOR"; }
        if (quality == Position.QUALITY_USABLE)         { return "USABLE"; }
        if (quality == Position.QUALITY_GOOD)           { return "GOOD"; }
        return "?";
    }

    private function httpHint(code as Number) as String {
        // The negative codes are Connect IQ's own, not HTTP, and they are the
        // ones worth naming because they point at the phone link.
        if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return "No phone/WiFi link";
        }
        if (code == Communications.BLE_HOST_TIMEOUT) {
            return "Link timed out";
        }
        if (code == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return "Request timed out";
        }
        if (code == Communications.NETWORK_RESPONSE_TOO_LARGE) {
            return "Response too large";
        }
        if (code == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
            return "Bad response body";
        }
        return "HTTP " + code.toString();
    }

    // A failed fetch leaves the cached series alone. v0 cleared the reading on
    // every attempt because its whole job was exercising the pipe; an app that
    // blanks the screen the moment the phone wanders out of range is a worse
    // app than one that says "two hours old".
    private function fail(code as Number or Null, text as String) as Void {
        var state = UvState.get();
        cancelGpsTimer();
        state.httpCode = code;
        state.errorText = text;
        state.requestInFlight = false;
        System.println("UV fetch failed: " + text + " (code " + (code == null ? "none" : code.toString()) + ")");
        _onDone.invoke(false);
    }
}
