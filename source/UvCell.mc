import Toybox.Lang;
import Toybox.Application;

// The height of the CAMS grid cell the forecast was computed for - the
// baseline the altitude correction measures from.
//
// Why this exists (settled 2026-09-23, after the v1c elevation test):
//
// The air-quality endpoint cannot supply this number. Open-Meteo stores no
// terrain heights for its CAMS domains at all - CamsDomain.swift defines the
// grid and nothing else - which is why elevation=nan came back empty. The
// endpoint's default "elevation" is a 90 m terrain height at your exact
// coordinates. On a hill that matches the barometer and the correction
// vanishes.
//
// So the app works the number out itself. ECMWF builds its model terrain as
// the mean surface height over each model grid box, so the mean of a grid of
// points across the cell is the same quantity, computed the same way. The
// points come from Open-Meteo's Elevation API (Copernicus GLO-90, the same
// 90 m model). The cell is identified from the air-quality response itself,
// which reports the centre of the grid cell it answered for.
//
// Terrain does not change, so a cell's height is fetched once and kept.
//
// App scope only. The glance reads the result through UvForecast and never
// needs this module.
module UvCell {

    // Open-Meteo's cams_global grid: regular, 0.4 degrees, anchored at -90 /
    // -180. uv_index comes only from this domain, never from cams_europe.
    const SPACING = 0.4;

    // 7 x 7 = 49 points, each at the middle of its own sub-box. The Elevation
    // API takes up to 100. 49 keeps the request URL near 1 kB, and in rugged
    // terrain it pins the mean to within a few tens of metres - under 1% on
    // the UV index, far inside k_alt's own uncertainty.
    const SIDE = 7;

    // Fewer usable heights than this and the mean is not trusted. A point with
    // no height is left out rather than counted as sea level, which would drag
    // the mean down and push the correction up - the unsafe direction.
    const MIN_VALID = 40;

    // Cell centres sit 0.4 degrees apart, so anything within 0.05 is the same
    // cell, whatever rounding the JSON carried.
    const MATCH_DEGREES = 0.05;

    const KEY_LAT = "cla";
    const KEY_LON = "clo";
    const KEY_HEIGHT = "ch";

    function pointCount() as Number {
        return SIDE * SIDE;
    }

    // The stored height, if it belongs to this cell. Null otherwise.
    function cached(cellLat as Float, cellLon as Float) as Float or Null {
        var lat = UvNum.asFloat(Application.Storage.getValue(KEY_LAT));
        if (lat == null) {
            return null;
        }
        var lon = UvNum.asFloat(Application.Storage.getValue(KEY_LON));
        if (lon == null) {
            return null;
        }
        if (!near(lat, cellLat)) {
            return null;
        }
        if (!near(lon, cellLon)) {
            return null;
        }
        return UvNum.asFloat(Application.Storage.getValue(KEY_HEIGHT));
    }

    function remember(cellLat as Float, cellLon as Float, height as Float) as Void {
        Application.Storage.setValue(KEY_LAT, cellLat);
        Application.Storage.setValue(KEY_LON, cellLon);
        Application.Storage.setValue(KEY_HEIGHT, height);
    }

    // The two comma-separated lists the Elevation API takes. Built by the same
    // loop in the same order, so the n-th latitude and the n-th longitude are
    // always the same point.
    function latitudes(cellLat as Float, cellLon as Float) as String {
        return sampleList(cellLat, cellLon, true);
    }

    function longitudes(cellLat as Float, cellLon as Float) as String {
        return sampleList(cellLat, cellLon, false);
    }

    function sampleList(cellLat as Float, cellLon as Float, wantLat as Boolean) as String {
        var step = SPACING / SIDE;
        var half = (SIDE - 1) / 2;
        var out = "";
        for (var i = 0; i < SIDE; i += 1) {
            for (var j = 0; j < SIDE; j += 1) {
                var v = wantLat
                        ? clampLat(cellLat + (i - half) * step)
                        : wrapLon(cellLon + (j - half) * step);
                if (out.length() > 0) {
                    out = out + ",";
                }
                out = out + v.format("%.3f");
            }
        }
        return out;
    }

    // The mean of the heights that came back, or null if too few did.
    //
    // Checking is off for the reason UvNum gives: the array arrives as Any
    // out of the JSON parser. Every value is narrowed before it is used, and
    // the result leaves fully typed.
    (:typecheck(false))
    function meanOf(heights) as Lang.Float or Null {
        if (!(heights instanceof Lang.Array)) {
            return null;
        }
        var sum = 0.0;
        var n = 0;
        for (var i = 0; i < heights.size(); i += 1) {
            var h = UvNum.asFloat(heights[i]);
            if (h != null) {
                sum += h;
                n += 1;
            }
        }
        if (n < MIN_VALID) {
            return null;
        }
        return (sum / n).toFloat();
    }

    // How many heights came back usable, for the console.
    (:typecheck(false))
    function validCount(heights) as Lang.Number {
        if (!(heights instanceof Lang.Array)) {
            return 0;
        }
        var n = 0;
        for (var i = 0; i < heights.size(); i += 1) {
            if (UvNum.asFloat(heights[i]) != null) {
                n += 1;
            }
        }
        return n;
    }

    function near(a as Float, b as Float) as Boolean {
        var d = a - b;
        if (d < 0.0) {
            d = -d;
        }
        return d < MATCH_DEGREES;
    }

    // A polar cell's sample points would otherwise run past the pole. Clamped
    // duplicates are harmless in a mean.
    function clampLat(lat as Float) as Float {
        if (lat > 90.0) {
            return 90.0;
        }
        if (lat < -90.0) {
            return -90.0;
        }
        return lat;
    }

    // A cell on the date line has points on both sides of it.
    function wrapLon(lon as Float) as Float {
        if (lon > 180.0) {
            return lon - 360.0;
        }
        if (lon < -180.0) {
            return lon + 360.0;
        }
        return lon;
    }
}
