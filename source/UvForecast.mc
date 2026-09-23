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
// because UvFetch.parse() verifies the step is uniform before it ever gets
// here - an irregular series is a failed fetch, not a degraded mode.
(:glance)
class UvForecast {

    private const KEY_BASE   = "fb";
    private const KEY_STEP   = "fs";
    private const KEY_VALUES = "fv";
    private const KEY_ELEV   = "fe";
    private const KEY_LAT    = "fla";
    private const KEY_LON    = "flo";
    private const KEY_AT     = "fat";
    private const KEY_CLEAR  = "fc";

    // Missing hours are stored as -1.0 rather than null. Application.Storage
    // round-trips a null inside an array loosely enough that it is not worth
    // relying on, and a negative UV index is impossible, so the sentinel
    // cannot be mistaken for data. UvFetch.parse() writes it; interpolate()
    // reads it.

    // Fetch age is not data age. CAMS runs twice a day, so a refetch two hours
    // later returns the same model run and the same numbers; v1a's two-hour
    // "fresh" window marked a reading yellow when nothing had changed and a
    // refetch would not have fixed it. Six hours is inside one run. What
    // actually makes the cache wrong is a new run landing, or moving to a
    // different cell - which the distance check now catches, because the
    // current position is sampled on every show (2026-09-23 review).
    private const FRESH_SECONDS = 21600;
    private const USABLE_SECONDS = 43200;

    // Past 100 km it is a different sky and the number is no longer about
    // where you are. Nearer than that, what matters is whether you are still
    // in the cell the forecast came from - see state(). v1a-v1c used 25 km
    // for that, which predates knowing the grid.
    private const FAR_KM = 100.0;

    private const DEG_TO_RAD = 0.0174532925;
    private const KM_PER_DEGREE = 111.32;

    public var baseEpoch as Number or Null = null;
    public var stepSeconds as Number = 3600;
    public var values as Array or Null = null;
    // uv_index_clear_sky, the same shape as values. Null for a series
    // fetched before v1b, or when the response carried none.
    public var clearValues as Array or Null = null;
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

    // The raw API value for this instant, before any on-watch correction. Null
    // means no value - out of range, or a gap the model left in the series.
    //
    // Interpolated between the hour either side. Open-Meteo's hourly values
    // are instantaneous at the indicated hour, so v1a's step read showed the
    // 15:00 value until 15:59 - up to 30-50% off on the shoulders of the day,
    // which in a Canadian winter is most of the ski day. At a gap in the model
    // series, or at the end of it, this falls back to the hour's own value.
    //
    // Consequence for the console: "raw=" no longer equals the JSON value for
    // the hour except at the top of it. That is not a UTC regression.
    public function valueAt(epoch as Number) as Float or Null {
        var vals = values;
        if (vals == null) {
            return null;
        }
        return interpolate(vals, epoch);
    }

    // The clear-sky value for this instant, interpolated the same way. v1b.
    public function clearAt(epoch as Number) as Float or Null {
        var vals = clearValues;
        if (vals == null) {
            return null;
        }
        if (vals.size() != hourCount()) {
            return null;
        }
        return interpolate(vals, epoch);
    }

    private function interpolate(vals as Array, epoch as Number) as Float or Null {
        var idx = indexAt(epoch);
        if (idx < 0) {
            return null;
        }
        var base = baseEpoch;
        if (base == null) {
            return null;
        }
        // Two single tests, not one compound one: v is used in arithmetic
        // below, and a combined null test does not narrow reliably here.
        var v = UvNum.asFloat(vals[idx]);
        if (v == null) {
            return null;
        }
        if (v < 0.0) {
            return null;
        }

        if (idx + 1 >= vals.size()) {
            return v;
        }
        var next = UvNum.asFloat(vals[idx + 1]);
        if (next == null) {
            return v;
        }
        if (next < 0.0) {
            return v;
        }

        var elapsed = epoch - (base + idx * stepSeconds);
        var frac = elapsed.toFloat() / stepSeconds.toFloat();
        return v + (next - v) * frac;
    }

    // The hour's own value, uninterpolated. Only for the console, so a future
    // session can still compare against the JSON.
    public function stepValueAt(epoch as Number) as Float or Null {
        var idx = indexAt(epoch);
        if (idx < 0) {
            return null;
        }
        var vals = values;
        if (vals == null) {
            return null;
        }
        return UvNum.asFloat(vals[idx]);
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

    // Age and place are judged together, because either alone can be
    // misleading: a five-minute-old fetch from the last town is not current,
    // and a six-hour-old fetch from right here is still roughly right.
    //
    // "Here" means the same CAMS cell (v1b, 2026-09-23). Open-Meteo answers
    // every position in a cell with that cell's values, so a different cell
    // is a different forecast however close it is, and the same cell is the
    // same forecast however far across it you have walked.
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
        if (age <= FRESH_SECONDS && inFetchedCell(curLat, curLon)) {
            return CACHE_CURRENT;
        }
        if (age <= USABLE_SECONDS) {
            return CACHE_STALE;
        }
        return CACHE_EXPIRED;
    }


    // Unknown counts as the same cell, as unknown distance always did: with
    // no position to compare, age alone decides.
    private function inFetchedCell(curLat as Float or Null, curLon as Float or Null) as Boolean {
        var a = curLat;
        if (a == null) {
            return true;
        }
        var b = curLon;
        if (b == null) {
            return true;
        }
        var fa = lat;
        if (fa == null) {
            return true;
        }
        var fb = lon;
        if (fb == null) {
            return true;
        }
        return UvCell.sameCell(a, b, fa, fb);
    }

    // Takes a series UvFetch.parse() has already accepted - from the
    // foreground client, or from the background service's payload, which
    // carries the same keys. Returns false and changes nothing if the pieces
    // are not there.
    //
    // Checking is off because the parsed dictionary hands back Any; each
    // value is narrowed before it is kept.
    (:typecheck(false))
    public function adopt(parsed, fetchLat, fetchLon, nowEpoch) as Lang.Boolean {
        if (!(parsed instanceof Lang.Dictionary)) {
            return false;
        }
        var base = UvNum.asNumber(parsed.get(UvFetch.P_BASE));
        var step = UvNum.asNumber(parsed.get(UvFetch.P_STEP));
        var vals = UvNum.asArray(parsed.get(UvFetch.P_UV));
        if (base == null || step == null || vals == null) {
            return false;
        }
        if (step <= 0) {
            return false;
        }
        var clear = UvNum.asArray(parsed.get(UvFetch.P_CLEAR));
        if (clear != null && clear.size() != vals.size()) {
            clear = null;
        }

        baseEpoch = base;
        stepSeconds = step;
        values = vals;
        clearValues = clear;
        lat = UvNum.asFloat(fetchLat);
        lon = UvNum.asFloat(fetchLon);
        fetchedAt = UvNum.asNumber(nowEpoch);
        return true;
    }

    public function load() as Void {
        baseEpoch     = UvNum.asNumber(Application.Storage.getValue(KEY_BASE));
        gridElevation = UvNum.asFloat(Application.Storage.getValue(KEY_ELEV));
        lat           = UvNum.asFloat(Application.Storage.getValue(KEY_LAT));
        lon           = UvNum.asFloat(Application.Storage.getValue(KEY_LON));
        fetchedAt     = UvNum.asNumber(Application.Storage.getValue(KEY_AT));
        values        = UvNum.asArray(Application.Storage.getValue(KEY_VALUES));
        clearValues   = UvNum.asArray(Application.Storage.getValue(KEY_CLEAR));

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

    // Isolated so the type suppression covers these two calls and nothing
    // else. Storage.setValue takes Application.PropertyValueType; the series
    // is held as a bare Lang.Array because that is what comes back out of
    // storage, and the two spellings do not necessarily satisfy the checker
    // even though the runtime accepts them. Six other setValue calls above
    // keep their checking.
    (:typecheck(false))
    private function putValues() as Void {
        Application.Storage.setValue(KEY_VALUES, values);
        Application.Storage.setValue(KEY_CLEAR, clearValues);
    }
}
