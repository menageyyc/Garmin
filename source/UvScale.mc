import Toybox.Lang;
import Toybox.Graphics;

// Shared by the app and the glance, so it carries the (:glance) annotation.
// Anything a glance view touches must be in the glance build scope or it is
// stripped out and the build fails.
(:glance)
module UvScale {

    // WHO/ICNIRP published bands, not a house scale.
    function riskBand(uv as Float) as String {
        if (uv < 3.0)  { return "LOW"; }
        if (uv < 6.0)  { return "MODERATE"; }
        if (uv < 8.0)  { return "HIGH"; }
        if (uv < 11.0) { return "VERY HIGH"; }
        return "EXTREME";
    }

    function colour(uv as Float) as Number {
        if (uv < 3.0)  { return Graphics.COLOR_GREEN; }
        if (uv < 6.0)  { return Graphics.COLOR_YELLOW; }
        if (uv < 8.0)  { return Graphics.COLOR_ORANGE; }
        if (uv < 11.0) { return Graphics.COLOR_RED; }
        return Graphics.COLOR_PURPLE;
    }
}
