import Toybox.Lang;
import Toybox.Communications;

// What the foreground client and the background service share: the request,
// the parser, and the names of everything passed between processes.
//
// v1b (2026-09-23). Before it, the parse lived in UvForecast.ingest(), inside
// a glance class the background has no business loading. One parser, called
// from both paths, means the uniform-step check and the -1 sentinel cannot
// drift apart between a fetch made on the wrist and one made in the
// background.
//
// Three scopes on purpose: the app fetches with it, the background service
// fetches with it, and the glance unpacks the background's payload by these
// key names in onBackgroundData().
(:glance :background)
module UvFetch {

    const UV_URL = "https://air-quality-api.open-meteo.com/v1/air-quality";

    // Two days, not one. forecast_days=1 returns the current UTC day, which
    // in Calgary cuts at 18:00 local - fine for "what is it now", useless for
    // a cache that has to survive an evening with no phone.
    const FORECAST_DAYS = "2";

    // uv_index_clear_sky added in v1b (decision 4, 2026-09-23): the UV under
    // a cloudless sky, from the same model run. The cloud forecast over
    // mountains at 40 km is the largest error in the whole chain, and this
    // is the ceiling when it is wrong (review finding 11).
    const HOURLY = "uv_index,uv_index_clear_sky";

    // Where the foreground last saw the watch. UvState writes these keys; the
    // background reads them, because Position from a background process is
    // reported to fail. The names must match UvState's.
    const KEY_LAT = "lat";
    const KEY_LON = "lon";

    // The background's last result, written by whichever process takes
    // delivery, read by the diagnostics page.
    const KEY_BG_AT = "bgt";
    const KEY_BG_ERROR = "bge";

    // Keys of the parsed series, and of the payload the background hands back
    // through Background.exit(). Short because the payload is capped near
    // 8 kB - it is under 1 kB, but there is no reason to spend it on names.
    const P_BASE = "b";         // epoch of the first hour
    const P_STEP = "s";         // seconds between values
    const P_UV = "v";           // uv_index, -1.0 for a missing hour
    const P_CLEAR = "c";        // uv_index_clear_sky, same shape; may be absent
    const P_LAT = "la";         // position the series was fetched for
    const P_LON = "lo";
    const P_AT = "t";           // when it was fetched, epoch seconds
    const P_CELL_LAT = "ca";    // the 0.4 degree cell, see UvCell
    const P_CELL_LON = "co";
    const P_HEIGHT = "h";       // that cell's mean height; absent if unknown
    const P_ERROR = "e";        // present only when the background failed
    const P_CODE = "k";         // the HTTP code with it, if there was one

    function uvParams(lat as Float, lon as Float) as Dictionary {
        return {
            "latitude"      => lat.format("%.4f"),
            "longitude"     => lon.format("%.4f"),
            "hourly"        => HOURLY,
            "forecast_days" => FORECAST_DAYS,
            "timeformat"    => "unixtime"
        };
    }

    function jsonOptions() as Dictionary {
        return {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }

    // Open-Meteo's hourly block, as the stored series, or a String naming
    // why it was refused.
    //
    // The base-plus-step format is only safe if the step really is uniform,
    // so that is checked across the whole array rather than assumed from the
    // first two entries. An irregular series is a failed fetch that says so,
    // not a degraded mode that quietly mis-indexes.
    //
    // A missing or odd-sized clear-sky array costs only the clear-sky line;
    // the UV series is still accepted.
    //
    // Checking is off for the reason UvNum gives: everything here arrives as
    // Any out of the JSON parser, and every value is narrowed before it goes
    // into the result.
    (:typecheck(false))
    function parse(data) as Lang.Dictionary or Lang.String {
        if (!(data instanceof Lang.Dictionary)) {
            return "Unexpected payload";
        }
        var hourly = data.get("hourly");
        if (!(hourly instanceof Lang.Dictionary)) {
            return "No hourly block";
        }
        var times = hourly.get("time");
        var uv = hourly.get("uv_index");
        if (!(times instanceof Lang.Array)) {
            return "No UV series";
        }
        if (!(uv instanceof Lang.Array)) {
            return "No UV series";
        }

        var n = times.size();
        if (n < 2 || uv.size() != n) {
            return "Irregular series";
        }
        var first = UvNum.asNumber(times[0]);
        var second = UvNum.asNumber(times[1]);
        if (first == null || second == null) {
            return "Irregular series";
        }
        var step = second - first;
        if (step <= 0) {
            return "Irregular series";
        }
        var prev = second;
        for (var i = 2; i < n; i += 1) {
            var t = UvNum.asNumber(times[i]);
            if (t == null || t - prev != step) {
                return "Irregular series";
            }
            prev = t;
        }

        var out = {
            P_BASE => first,
            P_STEP => step,
            P_UV   => sentinelled(uv)
        };
        var clear = hourly.get("uv_index_clear_sky");
        if (clear instanceof Lang.Array) {
            if (clear.size() == n) {
                out.put(P_CLEAR, sentinelled(clear));
            }
        }
        return out;
    }

    // Missing hours become -1.0 rather than null. Storage round-trips a null
    // inside an array loosely enough that it is not worth relying on, and a
    // negative UV index is impossible, so the sentinel cannot pass for data.
    (:typecheck(false))
    function sentinelled(values) as Lang.Array {
        var out = [];
        for (var i = 0; i < values.size(); i += 1) {
            var v = UvNum.asFloat(values[i]);
            if (v == null || v < 0.0) {
                out.add(-1.0);
            } else {
                out.add(v);
            }
        }
        return out;
    }

    // The background's successful payload: the parsed series plus where and
    // when it was fetched, and the cell's height if it is known.
    (:typecheck(false))
    function payload(parsed, lat, lon, at, cellLat, cellLon, height) as Lang.Dictionary {
        parsed.put(P_LAT, lat);
        parsed.put(P_LON, lon);
        parsed.put(P_AT, at);
        parsed.put(P_CELL_LAT, cellLat);
        parsed.put(P_CELL_LON, cellLon);
        if (height != null) {
            parsed.put(P_HEIGHT, height);
        }
        return parsed;
    }

    // Checking off: the literal starts as a String-valued dictionary, and a
    // strict checker may refuse the Number put into it afterwards.
    (:typecheck(false))
    function failure(text as Lang.String, code as Lang.Number or Null) as Lang.Dictionary {
        var out = { P_ERROR => text };
        if (code != null) {
            out.put(P_CODE, code);
        }
        return out;
    }
}
