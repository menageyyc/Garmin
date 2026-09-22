import Toybox.Lang;
import Toybox.Application;
import Toybox.Math;

// How stale the cached forecast is. Declared at file scope rather than inside
// the class - Monkey C is reliable about enums here, less so nested in a class
// body - and prefixed so it cannot collide with FixSource in UvState.mc.
(:glance)
enum CacheState {
    CACHE_ABSENT  = 0,    // nothing has ever been fetched
    CACHE_CURRENT = 1,    // recent, nearby, covers this hour
    CACHE_STALE   = 2,    // still covers this hour, but old or you have moved
    CACHE_EXPIRED = 3     // no value for now, or a different sky entirely
}

// The cached hourly UV series, and everything needed to judge whether it still
// describes where you are standing.
//
// v0 kept a single number. That was right for a build whose only job was
// proving the pipe, and wrong for an app: one failed fetch and the screen went
// blank. v1 keeps the whole series with the time and place it was fetched for,
// so a failed fetch degrades to "an hour old" rather than to nothing, and a
// cache fetched 400 km away is refused rather than shown.
//
// The series is stored as a base timestamp plus a fixed step rather than as a
// parallel array of timestamps. That halves the storage, and it is safe only
// because UvClient verifies the step is uniform before it ever gets here - an
// irregular series is a failed fetch, not a degraded mode.
(:glance)
class UvForecast {

    private const KEY_BASE   = "fb";
    private const KEY_STEP   = "fs";
    private const KEY_VALUES = "fv";
    private const KEY_ELEV   = "fe";
    private const KEY_LAT    = "fla";
    private const KEY_LON    = "flo";
    private const KEY_AT     = "fat";

    // Missing hours are stored as -1.0 rather than null. Application.Storage
    // round-trips a null inside an array loosely enough that it is not worth
    // relying on, and a negative UV index is impossible, so the sentinel
    // cannot be mistaken for data. ingest() writes it; valueAt() reads it.
    // CAMS is hourly. Past two hours the cloud state it described has moved
    // on, even though the hour slot it covers is still the right one.
    private const FRESH_SECONDS = 7200;
    private const USABLE_SECONDS = 43200;

    // The CAMS cell is roughly 40 km, so 25 km is comfortably inside the cell
    // that was fetched for. Past 100 km it is a different sky and the number
    // is no longer about where you are.
    private const NEAR_KM = 25.0;
    private const FAR_KM = 100.0;

    private const DEG_TO_RAD = 0.0174532925;
    private const KM_PER_DEGREE = 111.32;

    public var baseEpoch as Number or Null = null;
    public var stepSeconds as Number = 3600;
    public var values as Array or Null = null;
    public var gridElevation as Float or Null = null;
    public var lat as Float or Null = null;
    public var lon as Float or Null = null;
    public var fetchedAt as Number or Null = null;

    function initialize() {
    }

    public function hasSeries() as Boolean {
        return baseEpoch != null && values != null;
    }

    public function hourCount() as Number {
        var vals = values;
        return (vals == null) ? 0 : vals.size();
    }

    // The index into the series covering the given instant, or -1. Integer
    // division truncates toward zero, which equals floor here because the
    // epoch-before-base case is refused first.
    public function indexAt(epoch as Number) as Number {
        var base = baseEpoch;
        if (base == null) {
            return -1;
        }
        var vals = values;
        if (vals == null) {
            return -1;
        }
        if (epoch < base) {
            return -1;
        }
        var idx = (epoch - base) / stepSeconds;
        if (idx >= vals.size()) {
            return -1;
        }
        return idx;
    }

    // The raw API value for that hour, before any on-watch correction. Null
    // means no value - out of range, or a gap the model left in the series.
    public function valueAt(epoch as Number) as Float or Null {
        var idx = indexAt(epoch);
        if (idx < 0) {
            return null;
        }
        var vals = values;
        if (vals == null) {
            return null;
        }
        var v = UvNum.asFloat(vals[idx]);
        if (v == null || v < 0.0) {
            return null;
        }
        return v;
    }

    public function ageSeconds(nowEpoch as Number) as Number or Null {
        var at = fetchedAt;
        if (at == null) {
            return null;
        }
        return nowEpoch - at;
    }

    // Equirectangular approximation. At the tens of kilometres that decide
    // whether a cache is still yours, it is within a rounding error of the
    // great circle and costs a cosine instead of a haversine.
    public function distanceKm(curLat as Float or Null, curLon as Float or Null) as Float or Null {
        var a = curLat;
        if (a == null) {
            return null;
        }
        var b = curLon;
        if (b == null) {
            return null;
        }
        var fa = lat;
        if (fa == null) {
            return null;
        }
        var fb = lon;
        if (fb == null) {
            return null;
        }

        var meanLat = (a + fa) / 2.0 * DEG_TO_RAD;
        var dLat = (a - fa) * KM_PER_DEGREE;
        var dLon = (b - fb) * KM_PER_DEGREE * Math.cos(meanLat);
        return Math.sqrt(dLat * dLat + dLon * dLon).toFloat();
    }

    // Age and distance are judged together, because either alone can be
    // misleading: a five-minute-old fetch from the last town is not current,
    // and a six-hour-old fetch from right here is still roughly right.
    public function state(nowEpoch as Number, curLat as Float or Null, curLon as Float or Null) as Number {
        if (valueAt(nowEpoch) == null) {
            return hasSeries() ? CACHE_EXPIRED : CACHE_ABSENT;
        }

        var km = distanceKm(curLat, curLon);
        if (km != null && km > FAR_KM) {
            return CACHE_EXPIRED;
        }

        var age = ageSeconds(nowEpoch);
        if (age == null) {
            return CACHE_STALE;
        }
        if (age <= FRESH_SECONDS && (km == null || km <= NEAR_KM)) {
            return CACHE_CURRENT;
        }
        if (age <= USABLE_SECONDS) {
            return CACHE_STALE;
        }
        return CACHE_EXPIRED;
    }


    // Turns Open-Meteo's hourly block into the stored series, or refuses it.
    //
    // The base-plus-step format is only safe if the step really is uniform, so
    // that is checked across the whole array rather than assumed from the
    // first two entries. An irregular series is a failed fetch that says so,
    // not a degraded mode that quietly mis-indexes - if this ever fires, the
    // endpoint has changed shape and the right response is to find out why.
    //
    // Checking is off for the same reason the narrowing helpers have it off:
    // both arrays arrive as Any out of the JSON parser, and every value that
    // leaves this function is narrowed before it is stored.
    (:typecheck(false))
    public function ingest(times, rawValues, fetchLat, fetchLon, nowEpoch) as Lang.Boolean {
        var n = times.size();
        if (n < 2 || rawValues.size() != n) {
            return false;
        }

        var first = UvNum.asNumber(times[0]);
        var second = UvNum.asNumber(times[1]);
        if (first == null || second == null) {
            return false;
        }
        var step = second - first;
        if (step <= 0) {
            return false;
        }

        var prev = second;
        for (var i = 2; i < n; i += 1) {
            var t = UvNum.asNumber(times[i]);
            if (t == null || t - prev != step) {
                return false;
            }
            prev = t;
        }

        var out = [];
        for (var j = 0; j < n; j += 1) {
            var v = UvNum.asFloat(rawValues[j]);
            if (v == null || v < 0.0) {
                out.add(-1.0);
            } else {
                out.add(v);
            }
        }

        baseEpoch = first;
        stepSeconds = step;
        values = out;
        lat = fetchLat;
        lon = fetchLon;
        fetchedAt = nowEpoch;
        return true;
    }

    public function load() as Void {
        baseEpoch     = UvNum.asNumber(Application.Storage.getValue(KEY_BASE));
        gridElevation = UvNum.asFloat(Application.Storage.getValue(KEY_ELEV));
        lat           = UvNum.asFloat(Application.Storage.getValue(KEY_LAT));
        lon           = UvNum.asFloat(Application.Storage.getValue(KEY_LON));
        fetchedAt     = UvNum.asNumber(Application.Storage.getValue(KEY_AT));
        values        = UvNum.asArray(Application.Storage.getValue(KEY_VALUES));

        // Two single tests rather than one compound ternary. A combined
        // condition does not narrow reliably in this checker, and "step is
        // non-null here" is exactly what it would have to work out.
        stepSeconds = 3600;
        var step = UvNum.asNumber(Application.Storage.getValue(KEY_STEP));
        if (step != null) {
            if (step > 0) {
                stepSeconds = step;
            }
        }
    }

    public function save() as Void {
        Application.Storage.setValue(KEY_BASE, baseEpoch);
        Application.Storage.setValue(KEY_STEP, stepSeconds);
        Application.Storage.setValue(KEY_ELEV, gridElevation);
        Application.Storage.setValue(KEY_LAT, lat);
        Application.Storage.setValue(KEY_LON, lon);
        Application.Storage.setValue(KEY_AT, fetchedAt);
        putValues();
    }

    // Isolated so the type suppression covers this one call and nothing else.
    // Storage.setValue takes Application.PropertyValueType; the series is held
    // as a bare Lang.Array because that is what comes back out of storage, and
    // the two spellings do not necessarily satisfy the checker even though the
    // runtime accepts them. Six other setValue calls above keep their checking.
    (:typecheck(false))
    private function putValues() as Void {
        Application.Storage.setValue(KEY_VALUES, values);
    }
}
