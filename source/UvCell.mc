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
// 90 m model). The cell is worked out from the position the forecast was
// fetched for - see cellLat(). The response's own coordinates name a
// different dataset's grid and are only logged.
//
// Terrain does not change, so a cell's height is fetched once and kept.
//
// Three scopes since v1b (2026-09-23): the app measures cells, the background
// service measures a new one itself (decision 2) and reads the cache, and the
// glance both judges freshness by cell (sameCell) and remembers a height the
// background delivered.
(:glance :background)
module UvCell {

    // Open-Meteo's cams_global grid: regular, 0.4 degrees, anchored at -90 /
    // -180, 900 columns by 451 rows. uv_index comes only from this domain -
    // cams_europe and the greenhouse-gas domain carry none.
    const SPACING = 0.4;
    const COLS = 900;
    const ROWS = 451;

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

    // The last few cells measured, newest first, flattened as
    // [lat, lon, height, lat, lon, height, ...]. v1c kept one cell under
    // "cla" / "clo" / "ch"; the first cell-height re-test showed a Calgary -
    // Sunshine - Calgary trip re-measuring Calgary. Four cells is about 100
    // bytes. The old keys are orphaned and harmless: nothing reads them.
    const KEY_CELLS = "cells";
    const MAX_CELLS = 4;

    const ELEVATION_URL = "https://api.open-meteo.com/v1/elevation";

    function pointCount() as Number {
        return SIDE * SIDE;
    }

    // The centre of the cams_global cell a position is served from, worked
    // out here rather than read from the response.
    //
    // Why (found 2026-09-23, from the first cell-height test and then from
    // Open-Meteo's source): the air-quality request mixes several CAMS
    // datasets, and the response's latitude/longitude come from the LAST one
    // that covers you - outside Europe that is the 0.1 degree greenhouse-gas
    // grid, inside Europe the 0.1 degree European grid. Neither carries UV.
    // At Sunshine the response named 51.10,-115.80 while the UV came from the
    // 0.4 degree cell at 51.20,-115.60, so the first build averaged the
    // height of the wrong box.
    //
    // CAMS has no terrain file, so Open-Meteo picks the plain nearest grid
    // point: roundf((coordinate - origin) / 0.4). The same rounding here gives
    // the same cell. The shifted coordinates are never negative, so adding
    // 0.5 and truncating is rounding to nearest.
    function row(lat as Float) as Number {
        var y = ((lat + 90.0) / SPACING + 0.5).toNumber();
        if (y < 0) {
            y = 0;
        }
        if (y > ROWS - 1) {
            y = ROWS - 1;
        }
        return y;
    }

    // Column 900 is longitude +180, which is the same meridian as column 0.
    function col(lon as Float) as Number {
        var x = ((lon + 180.0) / SPACING + 0.5).toNumber();
        if (x >= COLS) {
            x = x - COLS;
        }
        if (x < 0) {
            x = 0;
        }
        return x;
    }

    function cellLat(lat as Float) as Float {
        return -90.0 + row(lat) * SPACING;
    }

    function cellLon(lon as Float) as Float {
        return -180.0 + col(lon) * SPACING;
    }

    // Whether two positions are served the same forecast. Compared as whole
    // grid indices, so there is no float equality to go wrong.
    //
    // This replaced a 25 km "near" test in UvForecast (v1b, 2026-09-23). A
    // cell is about 44 x 28 km at 51 degrees north, so 25 km could cross
    // into a neighbouring cell - a different forecast - while the cache
    // still called itself current.
    function sameCell(lat1 as Float, lon1 as Float, lat2 as Float, lon2 as Float) as Boolean {
        if (row(lat1) != row(lat2)) {
            return false;
        }
        return col(lon1) == col(lon2);
    }

    // The stored height, if one of the remembered cells is this one. Null
    // otherwise. Checking is off because a stored array hands back Any; each
    // element is narrowed before use.
    (:typecheck(false))
    function cached(cellLat as Lang.Float, cellLon as Lang.Float) as Lang.Float or Null {
        var cells = Application.Storage.getValue(KEY_CELLS);
        if (!(cells instanceof Lang.Array)) {
            return null;
        }
        for (var i = 0; i + 2 < cells.size(); i += 3) {
            var la = UvNum.asFloat(cells[i]);
            var lo = UvNum.asFloat(cells[i + 1]);
            if (la != null && lo != null) {
                if (near(la, cellLat) && near(lo, cellLon)) {
                    return UvNum.asFloat(cells[i + 2]);
                }
            }
        }
        return null;
    }

    // Puts this cell first and keeps up to three others behind it. Never
    // called from the background process, which hands its heights back
    // through Background.exit() instead (decision 3, 2026-09-23).
    (:typecheck(false))
    function remember(cellLat as Lang.Float, cellLon as Lang.Float, height as Lang.Float) as Void {
        var out = [cellLat, cellLon, height];
        var old = Application.Storage.getValue(KEY_CELLS);
        if (old instanceof Lang.Array) {
            for (var i = 0; i + 2 < old.size(); i += 3) {
                if (out.size() < MAX_CELLS * 3) {
                    var la = UvNum.asFloat(old[i]);
                    var lo = UvNum.asFloat(old[i + 1]);
                    var h = UvNum.asFloat(old[i + 2]);
                    if (la != null && lo != null && h != null) {
                        if (!(near(la, cellLat) && near(lo, cellLon))) {
                            out.add(la);
                            out.add(lo);
                            out.add(h);
                        }
                    }
                }
            }
        }
        Application.Storage.setValue(KEY_CELLS, out);
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
