import Toybox.Lang;
import Toybox.Position;
import Toybox.Activity;
import Toybox.System;
import Toybox.Time;

// Where the watch is, and how high, read from what the system already holds.
//
// Neither read powers a sensor: Position.getInfo() returns the last fix the
// system has, and Activity.getActivityInfo() the latest barometric altitude.
// That is why both can run on every onShow() rather than only when a fetch
// starts.
//
// Added 2026-09-23, from the cold review. In v1a both were read only inside
// UvClient.start(), and the forecast stored a copy of the same position, so
// the "have you moved?" check compared the fetch position with itself and could
// never fire. Check the UV at home, drive to the hill, open the app: home's
// number, home's altitude, labelled current. Sampling here, before freshness is
// judged, is what lets the distance check do its job.
//
// App scope only - not (:glance). Whether Toybox.Position is available in the
// glance scope on this device is unverified, and the glance only draws.
module UvSense {

    // A cached fix older than this is treated as unknown position. A chairlift
    // ride does not move you out of a 40 km cell; a drive does. During a
    // recorded activity the receiver is live and the fix is seconds old, so
    // this costs nothing on the hill.
    const MAX_FIX_AGE_SECONDS = 3600;

    // Barometric altitude, which beats GPS altitude by a wide margin. Keeps the
    // last known value if the call gives nothing.
    //
    // In the simulator this returns a fixed -18 m regardless of the simulated
    // position, so "vs grid" there is correct arithmetic over a fake input.
    function sampleAltitude() as Void {
        var state = UvState.get();
        var activityInfo = Activity.getActivityInfo();
        var altitude = (activityInfo != null) ? activityInfo.altitude : null;
        if (altitude != null) {
            state.watchAltitude = altitude.toFloat();
            System.println("Baro altitude " + altitude.format("%.0f") + " m");
        } else {
            System.println("No barometric altitude available");
        }
    }

    // Reads the cached fix into UvState if it is usable: present, plausible,
    // and not known to be old. Returns whether it was.
    //
    // A fix with no timestamp is accepted with its age unknown, and says so on
    // the diagnostics page. Refusing it would send every such read to a
    // one-shot GPS acquisition, up to 45 s each time the app opens, on the
    // strength of a missing field rather than evidence the fix is wrong.
    function sampleCachedFix() as Boolean {
        var state = UvState.get();
        var info = Position.getInfo();
        if (info == null) {
            return false;
        }
        var cached = info.position;
        if (cached == null) {
            return false;
        }

        var deg = cached.toDegrees();
        var latf = deg[0].toFloat();
        var lonf = deg[1].toFloat();
        if (!plausible(latf, lonf)) {
            System.println("Cached fix rejected: " + latf.format("%.4f") + ","
                           + lonf.format("%.4f"));
            return false;
        }

        var age = fixAge(info);
        if (age != null) {
            if (age > MAX_FIX_AGE_SECONDS) {
                System.println("Cached fix too old: " + ageText(age));
                return false;
            }
        }

        state.latitude = latf;
        state.longitude = lonf;
        state.fixSource = FIX_CACHED;
        state.fixAgeSeconds = age;

        // The barometer is the better source. If it has never given anything,
        // the cached fix carries a GPS altitude worth falling back to.
        var gpsAltitude = info.altitude;
        if (state.watchAltitude == null && gpsAltitude != null) {
            state.watchAltitude = gpsAltitude.toFloat();
        }

        System.println("GPS cached " + latf.format("%.4f") + "," + lonf.format("%.4f")
                       + " age=" + (age == null ? "unknown" : ageText(age)));
        return true;
    }

    // 0,0 means "never had a fix", not Null Island. Out-of-range values have
    // been reported from Position on real watches ([180,180] among them), and
    // any of them would go to Open-Meteo and come back HTTP 200 with a number.
    function plausible(lat as Float, lon as Float) as Boolean {
        if (lat == 0.0 && lon == 0.0) {
            return false;
        }
        if (lat > 90.0 || lat < -90.0) {
            return false;
        }
        if (lon > 180.0 || lon < -180.0) {
            return false;
        }
        return true;
    }

    // Seconds since the fix, or null when the platform gives no timestamp.
    function fixAge(info as Position.Info) as Number or Null {
        var fixTime = info.when;
        if (fixTime == null) {
            return null;
        }
        return Time.now().value() - fixTime.value();
    }

    // "40 s", "12 min", "5 h", "2 d". For the console and the diagnostics page.
    function ageText(seconds as Number) as String {
        if (seconds < 60) {
            return seconds.toString() + " s";
        }
        if (seconds < 3600) {
            return (seconds / 60).toString() + " min";
        }
        if (seconds < 86400) {
            return (seconds / 3600).toString() + " h";
        }
        return (seconds / 86400).toString() + " d";
    }
}
