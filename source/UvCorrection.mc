import Toybox.Lang;

// The whole reason this app exists rather than buying a $3 one.
//
// The server knows the sky: cloud, ozone, aerosol. It does not know that you
// are 900 m above the mean elevation of its 40 km grid cell, standing on
// snow. Those two facts are the watch's, and they are multiplicative:
//
//   UVI_eff = UVI_api * (1 + k_alt * (h_watch - h_grid) / 1000) * (1 + s)
//
// s is the surface increment from UvSettings. v1a had s = f * albedo, with f an
// invented "fraction of the surface in view". The 2026-09-23 review showed f
// does not correspond to anything measurable for the UV index (horizontal
// irradiance, raised by snow through ground-atmosphere multiple scattering,
// not by how much ground you can see), so the surface now carries its own
// increment directly.
//
// Pure arithmetic, no I/O, no state. (:glance) only for now - v1b adds
// (:background) here together with the service and the manifest permission,
// because any (:background) in the project makes it a background application
// and the build then fails until the permission is declared.
(:glance)
module UvCorrection {

    // 10% per 1000 m, logged in the build plan as an assumption to refine
    // against measurement rather than a measured constant. Published figures
    // for erythemal UV run roughly 6-12% per 1000 m depending on site, season,
    // and how much of the light path sits above the aerosol layer. 10% is
    // mid-range and errs slightly high, which is the safe direction.
    const K_ALT = 0.10;

    // The delta is the difference between two imprecise numbers: a barometer
    // whose sea-level reference can be hundreds of metres stale, and a cell
    // mean over 40 km. These bounds cover every real case - a glacier 4500 m
    // above its valley cell, a shoreline 1500 m below a mountainous cell mean -
    // and stop a bad altitude reading producing a confident wrong answer.
    const DELTA_MIN = -1500.0;
    const DELTA_MAX = 4500.0;

    // The surface increment, capped. Fresh snow is now +17.5%, so 0.60 is far
    // above anything the settings produce; it exists so a future mis-set value
    // cannot reach absurdity.
    const REFLECT_MAX = 0.60;

    // Returns 1.0 - no correction - when either input is missing. A watch with
    // no barometer reading and an API response with no elevation field both
    // land here, and the caller shows "no altitude" rather than a silent
    // pretend-correct number.
    //
    // Each null test reads its parameter into a local and tests that local on
    // its own. A combined test does not narrow reliably in this checker.
    function altitudeFactor(watchAltitude as Float or Null, gridElevation as Float or Null) as Float {
        var wa = watchAltitude;
        if (wa == null) {
            return 1.0;
        }
        var ge = gridElevation;
        if (ge == null) {
            return 1.0;
        }

        var delta = wa - ge;
        if (delta < DELTA_MIN) { delta = DELTA_MIN; }
        if (delta > DELTA_MAX) { delta = DELTA_MAX; }

        return 1.0 + K_ALT * delta / 1000.0;
    }

    // increment is the surface's own addition to the index, from settings - a
    // figure the wearer chose, not anything measured.
    function surfaceFactor(increment as Float) as Float {
        return 1.0 + clampIncrement(increment);
    }

    function effective(raw as Float,
                       watchAltitude as Float or Null,
                       gridElevation as Float or Null,
                       increment as Float) as Float {
        // Nothing to amplify. Guards against a negative sentinel leaking in
        // from a stored series as well as the honest zero of a night hour.
        if (raw <= 0.0) {
            return 0.0;
        }
        return raw
               * altitudeFactor(watchAltitude, gridElevation)
               * surfaceFactor(increment);
    }

    // For the screen: each term as a signed whole percentage, so the wearer can
    // see which correction is doing the work rather than being handed a number
    // that differs from every other UV app with no explanation.
    function altitudePercent(watchAltitude as Float or Null, gridElevation as Float or Null) as Number {
        return roundPercent((altitudeFactor(watchAltitude, gridElevation) - 1.0) * 100.0);
    }

    // From the increment directly, not from (factor - 1): 1.0 + 0.02 - 1.0 is
    // not exactly 0.02 in a 32-bit float, and every step adds a little error.
    function surfacePercent(increment as Float) as Number {
        return roundPercent(clampIncrement(increment) * 100.0);
    }

    function clampIncrement(increment as Float) as Float {
        var s = increment;
        if (s < 0.0) { s = 0.0; }
        if (s > REFLECT_MAX) { s = REFLECT_MAX; }
        return s;
    }

    // Nearest whole number, halves away from zero. toNumber() truncates, and
    // floats sit just below the value they are meant to be: 0.02 * 100 comes
    // out as 1.9999999, which truncated to "+1%" and then fell under the 2%
    // display threshold, so a +2% surface was never shown at all.
    function roundPercent(value as Float) as Number {
        if (value < 0.0) {
            return (value - 0.5).toNumber();
        }
        return (value + 0.5).toNumber();
    }
}
