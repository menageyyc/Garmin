import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;

// Where the fix came from, so a failure is diagnosable at a glance. Declared
// at file scope rather than inside the class - Monkey C is reliable about
// enums here, less so nested in a class body.
(:glance)
enum FixSource {
    FIX_NONE = 0,
    FIX_CACHED = 1,     // Position.getInfo(), free, possibly old
    FIX_LIVE = 2        // a real one-shot acquisition
}

// Shared state.
//
// The glance and the app do not share memory - a glance runs as its own build
// scope with its own budget - so anything both need goes through
// Application.Storage. The app fetches and writes; the glance only reads.
// Getting this wrong is the usual reason a glance shows stale or empty data
// while the app looks fine.
(:glance)
class UvState {

    // Bumped whenever the shape of what is stored changes. v0 kept a single
    // UV value under "uv"; v1 keeps a whole series under a different set of
    // keys. Rather than leave the old keys orphaned - or worse, read one with
    // the wrong expectations - the first v1 run wipes the store outright.
    // There is nothing in a v0 store worth migrating: it held one number that
    // is refetched within seconds.
    private const KEY_LAT = "lat";
    private const KEY_LON = "lon";
    private const KEY_ALT = "wa";

    // Where the watch currently thinks it is.
    public var latitude as Float or Null = null;
    public var longitude as Float or Null = null;
    public var fixSource as Number = FIX_NONE;

    // Metres, barometric where available. Persisted because the glance has no
    // way to take a fresh reading cheaply and the correction needs a number.
    // Altitude changes slowly next to how often a glance is drawn.
    public var watchAltitude as Float or Null = null;

    public var forecast as UvForecast;

    // Null means no request has completed yet. Not persisted - diagnostics are
    // about this run, not the last one.
    public var httpCode as Number or Null = null;
    public var errorText as String or Null = null;
    public var requestInFlight as Boolean = false;

    private static var _instance as UvState or Null = null;

    // Built through a local: returning the field directly gives the checker
    // "UvState or Null", because it cannot see that the assignment above
    // guarantees non-null by the time we return.
    public static function get() as UvState {
        var inst = _instance;
        if (inst == null) {
            inst = new UvState();
            inst.load();
            _instance = inst;
        }
        return inst;
    }

    function initialize() {
        forecast = new UvForecast();
    }

    // Called once from the app before anything reads storage. Safe to call
    // from the foreground only - a background process cannot be relied on to
    // write storage, so it must never be the thing that runs a migration.
    // Schema 1. The literal rather than a class const: a const declared in a
    // class body is not something a static method is guaranteed to see, and
    // this is not worth a compile cycle to find out. Bump both numbers
    // together whenever the stored shape changes.
    public static function migrate() as Void {
        var stored = UvNum.asNumber(Application.Storage.getValue("sch"));
        if (stored != null) {
            if (stored == 1) {
                return;
            }
        }
        Application.Storage.clearValues();
        Application.Storage.setValue("sch", 1);
    }

    // Storage can return null for any key, including one written earlier, so
    // every read is guarded rather than assumed.
    public function load() as Void {
        latitude      = UvNum.asFloat(Application.Storage.getValue(KEY_LAT));
        longitude     = UvNum.asFloat(Application.Storage.getValue(KEY_LON));
        watchAltitude = UvNum.asFloat(Application.Storage.getValue(KEY_ALT));

        if (latitude != null && longitude != null) {
            fixSource = FIX_CACHED;
        }

        forecast.load();
    }

    public function savePosition() as Void {
        Application.Storage.setValue(KEY_LAT, latitude);
        Application.Storage.setValue(KEY_LON, longitude);
        Application.Storage.setValue(KEY_ALT, watchAltitude);
    }

    public function hasPosition() as Boolean {
        return latitude != null && longitude != null;
    }

    // The API's own number for this hour, uncorrected.
    public function rawNow() as Float or Null {
        return forecast.valueAt(Time.now().value());
    }

    // What the correction makes of it. Null whenever the cache cannot speak
    // for this hour, which the view renders as "--" rather than as zero -
    // "no data" and "no UV" are different claims and must not look alike.
    public function effectiveNow() as Float or Null {
        var raw = rawNow();
        if (raw == null) {
            return null;
        }
        return UvCorrection.effective(raw,
                                      watchAltitude,
                                      forecast.gridElevation,
                                      UvSettings.albedo(),
                                      UvSettings.fraction());
    }

    public function cacheState() as Number {
        return forecast.state(Time.now().value(), latitude, longitude);
    }

    // Minutes since the cached series was fetched, for the staleness line.
    public function ageMinutes() as Number or Null {
        var secs = forecast.ageSeconds(Time.now().value());
        if (secs == null) {
            return null;
        }
        return (secs / 60).toNumber();
    }

    // Altitude the API assumed, versus where you actually are. Positive means
    // you are above the grid cell and are getting more UV than it reports.
    public function altitudeDelta() as Float or Null {
        var wa = watchAltitude;
        if (wa == null) {
            return null;
        }
        var ge = forecast.gridElevation;
        if (ge == null) {
            return null;
        }
        return wa - ge;
    }

    public function clearError() as Void {
        httpCode = null;
        errorText = null;
    }
}
