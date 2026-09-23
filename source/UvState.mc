import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;
import Toybox.System;

// Where the fix came from, so a failure is diagnosable at a glance. Declared
// at file scope rather than inside the class - Monkey C is reliable about
// enums here, less so nested in a class body.
(:glance)
enum FixSource {
    FIX_NONE = 0,       // no fix read this run; any position is from the last fetch
    FIX_CACHED = 1,     // Position.getInfo(), free, possibly old
    FIX_LIVE = 2        // a real one-shot acquisition
}

// Shared state.
//
// The glance and the app do not share memory - a glance runs as its own build
// scope with its own budget - so anything both need goes through
// Application.Storage. The app fetches and writes. The glance reads, and
// since v1b also writes one thing: a forecast the background service hands
// it (receiveBackground).
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
    // Position keys are UvFetch's, because the background service reads them
    // too (v1b) and one spelling cannot drift from the other.
    private const KEY_ALT = "wa";

    // Where the watch currently thinks it is.
    public var latitude as Float or Null = null;
    public var longitude as Float or Null = null;
    public var fixSource as Number = FIX_NONE;

    // How old the fix was when it was read, in seconds. Null means unknown -
    // the platform did not say. Not persisted: it describes this run's read.
    // Added 2026-09-23: a real watch's cached fix is wherever GPS last ran,
    // which can be another town days ago, and "(cached)" alone hid that.
    public var fixAgeSeconds as Number or Null = null;

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

    // Called from getInitialView() and getGlanceView() before anything reads
    // storage - never from AppBase.onStart(), which also runs in the background
    // process once the app is a background application (v1b). A background
    // process cannot be relied on to write storage, so it must never be the
    // thing that runs a migration.
    //
    // Wipe-on-mismatch is acceptable only while the store holds nothing that
    // cannot be refetched. Before v2 stores a day's dose, this must become a
    // real migration.
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
        latitude      = UvNum.asFloat(Application.Storage.getValue(UvFetch.KEY_LAT));
        longitude     = UvNum.asFloat(Application.Storage.getValue(UvFetch.KEY_LON));
        watchAltitude = UvNum.asFloat(Application.Storage.getValue(KEY_ALT));

        // A restored position is where the last fetch was made, not a fix read
        // in this run, so fixSource stays FIX_NONE until one is. The
        // diagnostics page says so rather than calling it "cached".

        forecast.load();
    }

    // Called on every show (v1b) as well as before every fetch, so the
    // background service fetches for where the watch last was, not where
    // it last fetched (2026-09-23 review, finding 3).
    public function savePosition() as Void {
        Application.Storage.setValue(UvFetch.KEY_LAT, latitude);
        Application.Storage.setValue(UvFetch.KEY_LON, longitude);
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
                                      UvSettings.increment());
    }

    // The same correction applied to the clear-sky value: what the big number
    // would read if the forecast cloud does not turn up. v1b.
    public function effectiveClearNow() as Float or Null {
        var clear = forecast.clearAt(Time.now().value());
        if (clear == null) {
            return null;
        }
        return UvCorrection.effective(clear,
                                      watchAltitude,
                                      forecast.gridElevation,
                                      UvSettings.increment());
    }

    // Takes delivery of what the background service handed back, in the app
    // or in the glance - whichever process AppBase.onBackgroundData() fires
    // in. Only these foreground processes write the forecast keys, so there
    // is one writer per key (decision 3, 2026-09-23).
    //
    // A failure leaves the cached series alone, as a failed foreground fetch
    // does. A payload older than what is already stored is dropped: a
    // START press can land a fresher series while the background ran.
    //
    // Checking is off: the payload is Any, and every value is narrowed.
    (:typecheck(false))
    public function receiveBackground(data) as Void {
        var now = Time.now().value();
        Application.Storage.setValue(UvFetch.KEY_BG_AT, now);

        if (!(data instanceof Lang.Dictionary)) {
            Application.Storage.setValue(UvFetch.KEY_BG_ERROR, "no data");
            return;
        }
        var err = data.get(UvFetch.P_ERROR);
        if (err != null) {
            var code = UvNum.asNumber(data.get(UvFetch.P_CODE));
            Application.Storage.setValue(UvFetch.KEY_BG_ERROR,
                    err.toString() + (code == null ? "" : " (" + code.toString() + ")"));
            return;
        }

        var at = UvNum.asNumber(data.get(UvFetch.P_AT));
        var have = forecast.fetchedAt;
        if (at != null && have != null && at < have) {
            Application.Storage.deleteValue(UvFetch.KEY_BG_ERROR);
            return;
        }
        if (!forecast.adopt(data, data.get(UvFetch.P_LAT), data.get(UvFetch.P_LON), at)) {
            Application.Storage.setValue(UvFetch.KEY_BG_ERROR, "bad payload");
            return;
        }

        // The height travels with the series, so a new cell's forecast is
        // never paired with an old cell's height. Absent means the service
        // could not get it; the correction is then off, as in the foreground.
        var height = UvNum.asFloat(data.get(UvFetch.P_HEIGHT));
        forecast.gridElevation = height;
        var cellLat = UvNum.asFloat(data.get(UvFetch.P_CELL_LAT));
        var cellLon = UvNum.asFloat(data.get(UvFetch.P_CELL_LON));
        if (height != null && cellLat != null && cellLon != null) {
            UvCell.remember(cellLat, cellLon, height);
        }
        forecast.save();
        Application.Storage.deleteValue(UvFetch.KEY_BG_ERROR);

        System.println("BG delivered: " + forecast.hourCount().toString() + " h, cell "
                       + (cellLat == null ? "?" : cellLat.format("%.2f")) + ","
                       + (cellLon == null ? "?" : cellLon.format("%.2f"))
                       + " height " + (height == null ? "none" : height.format("%.0f") + " m")
                       + " clear " + (forecast.clearValues == null ? "no" : "yes"));
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
