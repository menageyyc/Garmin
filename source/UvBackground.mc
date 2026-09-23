import Toybox.Lang;
import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.System;
import Toybox.Time;

// The background service: wakes every three hours, fetches the forecast for
// where the watch last was, and hands it back. v1b, 2026-09-23.
//
// What it may and may not do, and why this is shaped the way it is:
//
// - It runs for at most 30 seconds, or until Background.exit(). Everything
//   ends in exactly one exit() - including every failure - so a run never
//   just times out silently.
// - It does not call Position. Position from a background process is
//   reported to fail with permission errors, and a 40 km cell does not need
//   a fresh fix. It reads the position the foreground last wrote.
// - It does not write Storage, though since API 3.2 it could. Decision 3:
//   the series and the cell height go back through Background.exit(), and
//   the app or glance - whichever is running, or the next to start - saves
//   them in onBackgroundData(). One writer per key.
// - For a cell it has not measured, it asks for the height itself (decision
//   2), so the glance is never left uncorrected until the app is opened.
//   That is a second request inside the same 30 seconds; UvCell remembers
//   four cells, so it is rare.
// - Memory is the tightest budget in the project and not yet measured for
//   this device. The response is parsed and dropped inside onUv; only the
//   two 48-value arrays are held across the height request.
(:background)
class UvBackground extends System.ServiceDelegate {

    private var _lat as Float = 0.0;
    private var _lon as Float = 0.0;
    private var _cellLat as Float = 0.0;
    private var _cellLon as Float = 0.0;

    // The finished forecast, held while the cell height is fetched.
    private var _payload as Dictionary or Null = null;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var lat = UvNum.asFloat(Application.Storage.getValue(UvFetch.KEY_LAT));
        if (lat == null) {
            finish(UvFetch.failure("no position yet", null));
            return;
        }
        var lon = UvNum.asFloat(Application.Storage.getValue(UvFetch.KEY_LON));
        if (lon == null) {
            finish(UvFetch.failure("no position yet", null));
            return;
        }
        _lat = lat;
        _lon = lon;

        System.println("BG GET " + UvFetch.UV_URL + " lat=" + lat.format("%.4f")
                       + " lon=" + lon.format("%.4f"));
        Communications.makeWebRequest(UvFetch.UV_URL, UvFetch.uvParams(lat, lon),
                                      UvFetch.jsonOptions(), method(:onUv));
    }

    function onUv(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200) {
            finish(UvFetch.failure("HTTP " + code.toString(), null));
            return;
        }
        // The series, or a String saying why not - see UvClient.onResponse.
        var parsed = UvFetch.parse(data);
        if (parsed instanceof String) {
            finish(UvFetch.failure(parsed.toString(), null));
            return;
        }

        _cellLat = UvCell.cellLat(_lat);
        _cellLon = UvCell.cellLon(_lon);
        var known = UvCell.cached(_cellLat, _cellLon);
        var payload = UvFetch.payload(parsed, _lat, _lon, Time.now().value(),
                                      _cellLat, _cellLon, known);

        System.println("BG UV OK cell=" + _cellLat.format("%.2f") + "," + _cellLon.format("%.2f")
                       + " height=" + (known == null ? "pending" : known.format("%.0f") + " m")
                       + " " + memoryText());

        if (known != null) {
            finish(payload);
            return;
        }

        _payload = payload;
        System.println("BG GET " + UvCell.ELEVATION_URL + " cell=" + _cellLat.format("%.2f")
                       + "," + _cellLon.format("%.2f"));
        Communications.makeWebRequest(UvCell.ELEVATION_URL,
                                      UvCell.heightParams(_cellLat, _cellLon),
                                      UvFetch.jsonOptions(), method(:onHeight));
    }

    // A failed height request still delivers the forecast, without a height:
    // the correction is off until a later run or the app measures the cell.
    // That is the foreground's behaviour too.
    function onHeight(code as Number, data as Dictionary or String or Null) as Void {
        var payload = _payload;
        if (payload == null) {
            finish(UvFetch.failure("lost state", null));
            return;
        }
        if (code == 200) {
            if (data instanceof Dictionary) {
                var mean = UvCell.meanOf(data.get("elevation"));
                if (mean != null) {
                    payload.put(UvFetch.P_HEIGHT, mean);
                    System.println("BG cell height " + mean.format("%.0f") + " m");
                } else {
                    System.println("BG cell height failed: too few points");
                }
            }
        } else {
            System.println("BG cell height failed: HTTP " + code.toString());
        }
        finish(payload);
    }

    // The background budget is the one memory figure this project has never
    // measured, and the tightest (commonly quoted near 32 kB). Logged at the
    // point where the parsed series is held alongside the response, which is
    // about as full as this process gets.
    private function memoryText() as String {
        var stats = System.getSystemStats();
        return "mem=" + (stats.usedMemory / 1024).toString() + "/"
               + (stats.totalMemory / 1024).toString() + " kB";
    }

    // Background.exit() throws if the payload is over its size limit (about
    // 8 kB). This one is under 1 kB, but a refused exit would lose the run
    // without a word, so the error is reported in its place.
    //
    // Checking is off: exit() takes Application.PersistableType, and the
    // payload is a dictionary built from Any values.
    (:typecheck(false))
    private function finish(payload) as Void {
        _payload = null;
        try {
            Background.exit(payload);
        } catch (e) {
            Background.exit(UvFetch.failure("payload too large", null));
        }
    }
}
