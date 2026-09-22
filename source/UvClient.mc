import Toybox.Lang;
import Toybox.Communications;
import Toybox.Position;
import Toybox.Activity;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;

// Fetches UV from Open-Meteo's air-quality endpoint and records the outcome in
// UvState.
//
// Why this endpoint and not the main forecast API: the forecast API's uv_index
// comes from GFS, which uses a simplified approximation. The air-quality
// endpoint serves CAMS, which computes biologically effective (erythemal) UV
// properly. CAMS is coarser at roughly 40 km, which is exactly why the watch's
// own barometric altitude matters - see the build plan.
//
// The endpoint's contract was verified against Open-Meteo's documentation:
// uv_index is a valid hourly variable here, the response carries a top-level
// elevation field, forecast_days accepts 0-7, and timeformat=unixtime returns
// GMT+0 epoch seconds. The default timezone is GMT, so the series runs 00:00 to
// 23:00 UTC of the current UTC day. Time.now().value() is also UTC, so the two
// are directly comparable in currentHourIndex.
//
// timeformat=unixtime keeps the payload small. ISO timestamps roughly double
// the size of the time array for no benefit on-device. Payload size is the
// usual cause of death for a Connect IQ background fetch, so the habit starts
// here even though v0 runs in the foreground.
class UvClient {

    private const BASE_URL = "https://air-quality-api.open-meteo.com/v1/air-quality";

    // A one-shot acquisition that never completes used to leave requestInFlight
    // true forever: the screen sat on "..." with no error, indistinguishable
    // from still trying. Bound it so a failure names itself.
    private const GPS_TIMEOUT_MS = 45000;

    private var _onDone as Method(success as Boolean) as Void;
    private var _gpsTimer as Timer.Timer or Null = null;
    private var _gpsActive as Boolean = false;

    function initialize(onDone as Method(success as Boolean) as Void) {
        _onDone = onDone;
    }

    // Resolve a position, then fetch. Tries the free cached fix first and only
    // powers up the GPS if there is nothing usable.
    public function start() as Void {
        var state = UvState.get();
        state.requestInFlight = true;
        state.clearError();

        readAltitude();

        var info = Position.getInfo();
        var cached = (info != null) ? info.position : null;
        var gpsAltitude = (info != null) ? info.altitude : null;
        var quality = (info != null) ? info.accuracy : null;

        if (cached != null) {
            var deg = cached.toDegrees();
            // A cached fix at exactly 0,0 means "never had one", not Null Island.
            if (!(deg[0] == 0.0 && deg[1] == 0.0)) {
                // Into Float locals first: .format() on a Float is a pattern
                // this file already proves compiles, whereas formatting the
                // array element directly is not worth the risk of a cycle.
                var latf = deg[0].toFloat();
                var lonf = deg[1].toFloat();
                state.latitude = latf;
                state.longitude = lonf;
                state.fixSource = FIX_CACHED;

                // The barometer is the better source and readAltitude() has
                // already tried it. If it gave nothing, the cached fix carries a
                // GPS altitude worth falling back to. onPosition already did
                // this; the cached path did not, which was an asymmetry rather
                // than a decision.
                if (state.watchAltitude == null && gpsAltitude != null) {
                    state.watchAltitude = gpsAltitude.toFloat();
                }

                System.println("GPS cached " + latf.format("%.4f") + ","
                               + lonf.format("%.4f")
                               + " quality=" + qualityText(quality));
                requestUv();
                return;
            }
        }

        // Nothing cached. Acquire one, which costs battery and can take a while
        // outdoors and may never succeed indoors.
        System.println("No usable cached fix; acquiring one-shot GPS");
        _gpsActive = true;
        Position.enableLocationEvents(
            Position.LOCATION_ONE_SHOT,
            method(:onPosition)
        );
        startGpsTimer();
    }

    public function onPosition(info as Position.Info) as Void {
        cancelGpsTimer();
        stopGps();

        var state = UvState.get();

        var fix = info.position;
        if (fix == null) {
            fail(null, "No GPS fix");
            return;
        }

        var deg = fix.toDegrees();

        // The same 0,0 guard the cached path has always had. Without it a
        // callback carrying "no fix yet" sends the app to Null Island, and
        // Open-Meteo answers with a perfectly plausible tropical UV over
        // HTTP 200 - a success that proves nothing and hides a broken position
        // path. This is the one failure mode that can make the v0 test lie.
        if (deg[0] == 0.0 && deg[1] == 0.0) {
            fail(null, "GPS returned 0,0");
            return;
        }

        var latf = deg[0].toFloat();
        var lonf = deg[1].toFloat();
        state.latitude = latf;
        state.longitude = lonf;
        state.fixSource = FIX_LIVE;

        // GPS altitude as a fallback if the barometer gave us nothing.
        var gpsAltitude = info.altitude;
        if (state.watchAltitude == null && gpsAltitude != null) {
            state.watchAltitude = gpsAltitude.toFloat();
        }

        // Quality is logged, not gated on. A last-known or poor fix is still
        // fine for a 40 km UV grid cell, and refusing one would block the
        // simulator test for no safety gain. 0,0 is the case that actually
        // misleads, and it is caught above.
        System.println("GPS live " + latf.format("%.4f") + ","
                       + lonf.format("%.4f")
                       + " quality=" + qualityText(info.accuracy));

        requestUv();
    }

    // Barometric altitude, which beats GPS altitude by a wide margin. Available
    // outside an activity on most fenix and epix hardware, but guard it: the
    // call can return null, and on devices without a barometer it always will.
    private function readAltitude() as Void {
        var state = UvState.get();
        var activityInfo = Activity.getActivityInfo();
        var altitude = (activityInfo != null) ? activityInfo.altitude : null;
        if (altitude != null) {
            state.watchAltitude = altitude.toFloat();
            System.println("Baro altitude " + altitude.format("%.0f") + " m");
        } else {
            // Expected in the simulator. Activity.getActivityInfo() is only
            // populated while data is being generated or played back, so
            // Settings > Set Position alone yields a position but no altitude.
            // On the watch this line means no barometer reading was available.
            System.println("No barometric altitude (normal in the simulator "
                           + "unless FIT data is playing)");
        }
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

        var params = {
            "latitude"     => lat.format("%.4f"),
            "longitude"    => lon.format("%.4f"),
            "hourly"       => "uv_index",
            "forecast_days" => "1",
            "timeformat"   => "unixtime"
        };

        var options = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("GET " + BASE_URL + " lat=" + lat.format("%.4f")
                       + " lon=" + lon.format("%.4f"));
        Communications.makeWebRequest(BASE_URL, params, options, method(:onResponse));
    }

    public function onResponse(code as Number, data as Dictionary or String or Null) as Void {
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

        // The API reports the elevation of the grid cell it answered for. That
        // is the baseline the altitude correction works against in v1.
        var elevation = asFloat(data.get("elevation"));
        if (elevation != null) {
            state.gridElevation = elevation;
        }

        var hourly = data.get("hourly");
        if (!(hourly instanceof Dictionary)) {
            fail(code, "No hourly block");
            return;
        }

        var times = hourly.get("time");
        var values = hourly.get("uv_index");
        if (!(times instanceof Array) || !(values instanceof Array) || times.size() == 0) {
            fail(code, "No UV series");
            return;
        }

        var idx = currentHourIndex(times);
        if (idx < 0 || idx >= values.size()) {
            fail(code, "No value for now");
            return;
        }

        // A null here is normal, not a fault: the series carries gaps where the
        // model has no value for an hour.
        var uv = asFloat(values[idx]);
        if (uv == null) {
            fail(code, "No value for now");
            return;
        }

        var now = Time.now().value();

        state.uvIndex = uv;
        state.fetchedAtEpoch = now;
        state.errorText = null;
        state.requestInFlight = false;
        // Persist so the glance, which cannot fetch, has something to show.
        state.save();

        // The console is a far better diagnostic channel than three small lines
        // on a round screen, and these are the values that actually settle
        // whether the endpoint behaves the way the client assumes. "slot+Ns"
        // should land between 0 and 3599 - anything outside that means the UTC
        // alignment in currentHourIndex is wrong.
        var elevText = "ABSENT";
        var ge = state.gridElevation;
        if (ge != null) {
            elevText = ge.format("%.0f") + " m";
        }
        var stamp = stampAt(times, idx);
        var slotText = "?";
        if (stamp != null) {
            slotText = "slot+" + (now - stamp).toString() + "s";
        }
        System.println("UV OK uv=" + uv.format("%.2f")
                       + " gridElev=" + elevText
                       + " idx=" + idx.toString() + "/" + values.size().toString()
                       + " " + slotText);

        _onDone.invoke(true);
    }

    // The series is hourly from midnight local. Pick the last entry at or
    // before now rather than the nearest, so a reading is never from the future.
    private function currentHourIndex(times as Array) as Number {
        var now = Time.now().value();
        var best = -1;
        for (var i = 0; i < times.size(); i += 1) {
            var t = asNumber(times[i]);
            if (t != null && t <= now) {
                best = i;
            } else {
                break;
            }
        }
        // Before the first entry, fall back to the first rather than failing.
        return best < 0 ? 0 : best;
    }

    // Takes the array as a typed parameter for the same reason currentHourIndex
    // does: indexing a narrowed local outside a typed signature is the sort of
    // thing this checker is unpredictable about, and it costs nothing to avoid.
    private function stampAt(times as Array, idx as Number) as Number or Null {
        return asNumber(times[idx]);
    }

    // JSON values carry no arithmetic or conversion methods, hence "Cannot find
    // symbol ':toFloat'". Narrowing explicitly beats casting blind, because
    // Open-Meteo really does return an integer where a value happens to be whole
    // and a float otherwise, so both branches get taken.
    //
    // (:typecheck(false)) is the honest resolution to a genuine dead end, not a
    // shortcut. Container lookups yield Any, Monkey C's top type. Any sits above
    // Object, so it cannot be passed to a parameter declared Object. But Any has
    // no writable name either - it is what an untyped parameter already is, and
    // spelling it draws "Cannot resolve type 'Any'". Strict mode meanwhile
    // insists every parameter carry a type. There is no annotation that
    // satisfies both, and these functions exist precisely to inspect a value
    // whose type is unknown until runtime, which is the one job a static checker
    // cannot do. All of them return fully typed values, so nothing downstream
    // loses checking.
    (:typecheck(false))
    private function asFloat(value) as Lang.Float or Null {
        if (value instanceof Lang.Float)  { return value; }
        if (value instanceof Lang.Double) { return value.toFloat(); }
        if (value instanceof Lang.Number) { return value.toFloat(); }
        if (value instanceof Lang.Long)   { return value.toFloat(); }
        return null;
    }

    (:typecheck(false))
    private function asNumber(value) as Lang.Number or Null {
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long)   { return value.toNumber(); }
        return null;
    }

    // Position.Quality is an enum whose value may also be null on some paths.
    // Same reasoning as above: this exists to describe a value at runtime.
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
