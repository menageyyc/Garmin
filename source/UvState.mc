import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;

// Shared state for v0.
//
// The glance and the app do not share memory - a glance runs as its own build
// scope with its own budget - so anything both need goes through
// Application.Storage. The app fetches and writes; the glance only reads.
// Getting this wrong is the usual reason a glance shows stale or empty data
// while the app looks fine.
(:glance)
class UvState {

    // Where the fix came from, so a failure is diagnosable at a glance.
    enum FixSource {
        FIX_NONE = 0,
        FIX_CACHED = 1,     // Position.getInfo(), free, possibly old
        FIX_LIVE = 2        // a real one-shot acquisition
    }

    private const KEY_UV       = "uv";
    private const KEY_UV_AT    = "uvAt";
    private const KEY_LAT      = "lat";
    private const KEY_LON      = "lon";
    private const KEY_GRID_ELEV = "gridElev";

    public var latitude as Float or Null = null;
    public var longitude as Float or Null = null;
    public var fixSource as Number = FIX_NONE;

    // Metres. watchAltitude is the barometer; gridElevation is what the API
    // used for its cell. The difference drives the altitude correction in v1.
    public var watchAltitude as Float or Null = null;
    public var gridElevation as Float or Null = null;

    public var uvIndex as Float or Null = null;
    public var fetchedAtEpoch as Number or Null = null;

    // Null means no request has completed yet. Not persisted - diagnostics are
    // about this run, not the last one.
    public var httpCode as Number or Null = null;
    public var errorText as String or Null = null;
    public var requestInFlight as Boolean = false;

    private static var _instance as UvState or Null = null;

    public static function get() as UvState {
        if (_instance == null) {
            _instance = new UvState();
            _instance.load();
        }
        return _instance;
    }

    function initialize() {
    }

    // Storage can return null for any key, including one written earlier, so
    // every read is guarded rather than assumed.
    public function load() as Void {
        uvIndex        = readFloat(KEY_UV);
        gridElevation  = readFloat(KEY_GRID_ELEV);
        latitude       = readFloat(KEY_LAT);
        longitude      = readFloat(KEY_LON);

        var at = Application.Storage.getValue(KEY_UV_AT);
        fetchedAtEpoch = (at instanceof Number) ? at : null;

        if (latitude != null && longitude != null) {
            fixSource = FIX_CACHED;
        }
    }

    public function save() as Void {
        Application.Storage.setValue(KEY_UV, uvIndex);
        Application.Storage.setValue(KEY_UV_AT, fetchedAtEpoch);
        Application.Storage.setValue(KEY_LAT, latitude);
        Application.Storage.setValue(KEY_LON, longitude);
        Application.Storage.setValue(KEY_GRID_ELEV, gridElevation);
    }

    private function readFloat(key as String) as Float or Null {
        var v = Application.Storage.getValue(key);
        if (v == null) {
            return null;
        }
        // Storage round-trips numerics loosely; normalise rather than trust.
        if (v instanceof Float || v instanceof Number || v instanceof Double) {
            return v.toFloat();
        }
        return null;
    }

    public function hasPosition() as Boolean {
        return latitude != null && longitude != null;
    }

    public function hasReading() as Boolean {
        return uvIndex != null;
    }

    // Altitude the API assumed, versus where you actually are. Positive means
    // you are above the grid cell and are getting more UV than it reports.
    public function altitudeDelta() as Float or Null {
        if (watchAltitude == null || gridElevation == null) {
            return null;
        }
        return watchAltitude - gridElevation;
    }

    // Minutes since the reading was taken, for a staleness hint. v1 turns this
    // into a real stale/fresh distinction once the background fetch exists.
    public function ageMinutes() as Number or Null {
        if (fetchedAtEpoch == null) {
            return null;
        }
        var delta = Time.now().value() - fetchedAtEpoch;
        return (delta / 60).toNumber();
    }

    public function clearError() as Void {
        httpCode = null;
        errorText = null;
    }
}
