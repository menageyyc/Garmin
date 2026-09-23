import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;

// The glance reads the cached series and applies the same correction the app
// does, so the two never disagree. It never fetches: since v1b the background
// service does, every three hours, and hands the result to whichever of the
// app or the glance is running (UvGuardApp.onBackgroundData).
//
// The altitude it corrects with is read from the barometer on every draw
// (v1b). Before, it was the one stored when the app was last opened - on a
// ski day, the car park. Activity.getActivityInfo() reads what the system
// already holds and powers nothing. If Activity is not available in the
// glance on this device, the stored altitude is used as before.
//
// A glance cannot be tapped to toggle anything - input delegate methods are not
// invoked while a glance view is running - so this stays purely informational.
(:glance)
class UvGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var state = UvState.get();
        var h = dc.getHeight();
        sampleAltitude(state);

        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, (h * 0.10).toNumber(), Graphics.FONT_XTINY, "UV", Graphics.TEXT_JUSTIFY_LEFT);

        var uv = state.effectiveNow();
        if (uv == null) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, (h * 0.42).toNumber(), Graphics.FONT_TINY, "--", Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        // An old reading is marked rather than hidden. Hiding it would leave
        // the glance blank exactly when the phone has wandered off, which is
        // when a rough number is most useful.
        var cache = state.cacheState();
        var suffix = (cache == CACHE_CURRENT) ? "" : " (old)";

        // Expired - a different sky, or over 12 hours - is grey, as in the
        // app, so it cannot pass for a reading about here and now.
        var colour = UvScale.colour(uv);
        if (cache == CACHE_EXPIRED) {
            colour = Graphics.COLOR_LT_GRAY;
        }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, (h * 0.42).toNumber(), Graphics.FONT_TINY,
                    uv.format("%.1f") + "  " + UvScale.riskBand(uv) + suffix,
                    Graphics.TEXT_JUSTIFY_LEFT);
    }

    // In memory only, never written: the glance keeps its storage writes to
    // taking delivery of background data.
    private function sampleAltitude(state as UvState) as Void {
        if (!(Toybox has :Activity)) {
            return;
        }
        // No null test on info: the SDK declares getActivityInfo() as never
        // null, and the compiler flagged one as unreachable (first v1b build).
        var info = Activity.getActivityInfo();
        var altitude = info.altitude;
        if (altitude != null) {
            state.watchAltitude = altitude.toFloat();
        }
    }
}
