import Toybox.Lang;
import Toybox.Communications;
import Toybox.Position;
import Toybox.Activity;
import Toybox.System;
import Toybox.Time;

// Fetches UV from Open-Meteo's air-quality endpoint and records the outcome in
// UvState.
//
// Why this endpoint and not the main forecast API: the forecast API's uv_index
// comes from GFS, which uses a simplified approximation. The air-quality
// endpoint serves CAMS, which computes biologically effective (erythemal) UV
// properly. CAMS is coarser at roughly 40 km, which is exactly why the watch's
// own barometric altitude matters - see the build plan.
//
// timeformat=unixtime keeps the payload small. ISO timestamps roughly double
// the size of the time array for no benefit on-device. Payload size is the
// usual cause of death for a Connect IQ background fetch, so the habit starts
// here even though v0 runs in the foreground.
class UvClient {

    private const BASE_URL = "https://air-quality-api.open-meteo.com/v1/air-quality";

    private var _onDone as Method(success as Boolean) as Void;

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
        if (info != null && info.position != null) {
            var deg = info.position.toDegrees();
            // A cached fix at exactly 0,0 means "never had one", not Null Island.
            if (!(deg[0] == 0.0 && deg[1] == 0.0)) {
                state.latitude = deg[0].toFloat();
                state.longitude = deg[1].toFloat();
                state.fixSource = FIX_CACHED;
                requestUv();
                return;
            }
        }

        // Nothing cached. Acquire one, which costs battery and can take a while
        // outdoors and may never succeed indoors.
        Position.enableLocationEvents(
            Position.LOCATION_ONE_SHOT,
            method(:onPosition)
        );
    }

    public function onPosition(info as Position.Info) as Void {
        var state = UvState.get();

        if (info == null || info.position == null) {
            fail(null, "No GPS fix");
            return;
        }

        var deg = info.position.toDegrees();
        state.latitude = deg[0].toFloat();
        state.longitude = deg[1].toFloat();
        state.fixSource = FIX_LIVE;

        // GPS altitude as a fallback if the barometer gave us nothing.
        if (state.watchAltitude == null && info.altitude != null) {
            state.watchAltitude = info.altitude.toFloat();
        }

        requestUv();
    }

    // Barometric altitude, which beats GPS altitude by a wide margin. Available
    // outside an activity on most fenix and epix hardware, but guard it: the
    // call can return null, and on devices without a barometer it always will.
    private function readAltitude() as Void {
        var state = UvState.get();
        var activityInfo = Activity.getActivityInfo();
        if (activityInfo != null && activityInfo.altitude != null) {
            state.watchAltitude = activityInfo.altitude.toFloat();
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

        state.uvIndex = uv;
        state.fetchedAtEpoch = Time.now().value();
        state.errorText = null;
        state.requestInFlight = false;
        // Persist so the glance, which cannot fetch, has something to show.
        state.save();
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

    // JSON values arrive typed as Object, which carries no arithmetic or
    // conversion methods - hence "Cannot find symbol ':toFloat' on type
    // '$.Toybox.Lang.Object'". Narrowing explicitly beats casting blind,
    // because Open-Meteo really does return an integer where a value happens
    // to be whole and a float otherwise, so both branches get taken.
    private function asFloat(value) as Lang.Float or Null {
        if (value instanceof Lang.Float)  { return value; }
        if (value instanceof Lang.Double) { return value.toFloat(); }
        if (value instanceof Lang.Number) { return value.toFloat(); }
        if (value instanceof Lang.Long)   { return value.toFloat(); }
        return null;
    }

    private function asNumber(value) as Lang.Number or Null {
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long)   { return value.toNumber(); }
        return null;
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
        state.httpCode = code;
        state.errorText = text;
        state.requestInFlight = false;
        System.println("UV fetch failed: " + text + " (code " + (code == null ? "none" : code.toString()) + ")");
        _onDone.invoke(false);
    }
}
