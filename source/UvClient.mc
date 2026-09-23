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
// found the default is the point height; the request now asks for the cell's
// own height with elevation=nan. That part does need testing - see STATE.md.
//
// timeformat=unixtime keeps the payload small. ISO timestamps roughly double
// the size of the time array for no benefit on-device. Payload size is the
// usual cause of death for a Connect IQ background fetch, and v1b moves this
// request into a background process with roughly 32 KB to work in, so the
// habit is not optional.
class UvClient {

    private const BASE_URL = "https://air-quality-api.open-meteo.com/v1/air-quality";

    // Two days, not one. forecast_days=1 returns the current UTC day, which
    // in Calgary cuts at 18:00 local - fine for "what is it now", useless for
    // a cache that has to survive an evening with no phone. The second day
    // costs about 500 bytes on the wire and is what v3's forward-looking curve
    // will read anyway.
    private const FORECAST_DAYS = "2";

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

    // Ask Open-Meteo for the grid cell's own height rather than the terrain
    // height at our coordinates. See requestUv(). Dropped for the rest of this
    // client's life if the endpoint refuses it.
    private var _cellElevation as Boolean = true;

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

        var params = {
            "latitude"      => lat.format("%.4f"),
            "longitude"     => lon.format("%.4f"),
            "hourly"        => "uv_index",
            "forecast_days" => FORECAST_DAYS,
            "timeformat"    => "unixtime"
        };

        // By default Open-Meteo's "elevation" is the height of a 90 m terrain
        // model at our exact coordinates. On a piste that matches the
        // barometer, the delta is about zero, and the altitude correction
        // vanishes exactly where it matters. elevation=nan is documented to
        // return the grid cell's own height instead - the height CAMS itself
        // corrected for, and so the right baseline. (2026-09-23 review,
        // finding 1. Open-Meteo issue #1155 reported nan returning the wrong
        // height in Dec 2024; the simulator test in STATE.md checks it.)
        if (_cellElevation) {
            params.put("elevation", "nan");
        }

        var options = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("GET " + BASE_URL + " lat=" + lat.format("%.4f")
                       + " lon=" + lon.format("%.4f")
                       + " days=" + FORECAST_DAYS
                       + " elev=" + (_cellElevation ? "nan" : "default"));
        Communications.makeWebRequest(BASE_URL, params, options, method(:onResponse));
    }

    public function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        var state = UvState.get();

        // If the endpoint refuses elevation=nan, drop it and ask again once.
        // Two ways that could show: an HTTP 400, or a body the watch's JSON
        // parser rejects (-400) - JSON has no NaN, so an "elevation": NaN
        // echoed back would fail to parse. A refused parameter must not cost
        // the wearer a reading: without it the altitude correction reads about
        // zero on a hill, which is an under-report, the safe direction.
        if (_cellElevation && (code == 400
                               || code == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE)) {
            _cellElevation = false;
            System.println("Code " + code.toString() + " with elevation=nan; retrying without it");
            requestUv();
            return;
        }

        state.httpCode = code;

        if (code != 200) {
            fail(code, httpHint(code));
            return;
        }

        if (!(data instanceof Dictionary)) {
            fail(code, "Unexpected payload");
            return;
        }

        var hourly = data.get("hourly");
        if (!(hourly instanceof Dictionary)) {
            fail(code, "No hourly block");
            return;
        }

        var times = hourly.get("time");
        var series = hourly.get("uv_index");
        if (!(times instanceof Array) || !(series instanceof Array)) {
            fail(code, "No UV series");
            return;
        }

        var now = Time.now().value();
        var forecast = state.forecast;

        if (!forecast.ingest(times, series, state.latitude, state.longitude, now)) {
            fail(code, "Irregular series");
            return;
        }

        // With elevation=nan the API reports the height of the grid cell it
        // answered for, and that is the baseline the altitude correction works
        // against. Without it, the number is the terrain height at our
        // coordinates - see requestUv(). Assigned
        // only after ingest has accepted the series: setting it first would
        // leave a refused fetch pairing the new cell's elevation with the old
        // cell's series, which is a quietly wrong number rather than an error.
        // A response with no elevation field is still usable - it corrects for
        // the surface alone and the screen says "no grid".
        var elevation = UvNum.asFloat(data.get("elevation"));
        forecast.gridElevation = elevation;

        forecast.save();

        state.errorText = null;
        state.requestInFlight = false;

        // The console is a far better diagnostic channel than five small lines
        // on a round screen. slot+Ns should land between 0 and 3599; anything
        // outside that means the UTC alignment has broken.
        var idx = forecast.indexAt(now);
        var base = forecast.baseEpoch;
        var slotText = "?";
        if (base != null && idx >= 0) {
            slotText = "slot+" + (now - (base + idx * forecast.stepSeconds)).toString() + "s";
        }

        var raw = state.rawNow();
        var hour = forecast.stepValueAt(now);
        var eff = state.effectiveNow();
        System.println("UV OK raw=" + (raw == null ? "none" : raw.format("%.2f"))
                       + " hr=" + (hour == null ? "none" : hour.format("%.2f"))
                       + " eff=" + (eff == null ? "none" : eff.format("%.2f"))
                       + " gridElev=" + (elevation == null ? "ABSENT" : elevation.format("%.0f") + " m")
                       + (_cellElevation ? " (cell)" : " (point)")
                       + " idx=" + idx.toString() + "/" + forecast.hourCount().toString()
                       + " " + slotText
                       + " alt=" + UvCorrection.altitudePercent(state.watchAltitude, elevation).toString() + "%"
                       + " surface=" + UvCorrection.surfacePercent(UvSettings.increment()).toString() + "%");

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
