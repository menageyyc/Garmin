import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

// The glance reads the cached series the app persisted and applies the same
// correction the app does, so the two never disagree. It never fetches:
// glances run under a tight memory budget and are drawn often, so network work
// belongs in the background service, which arrives in v1b.
//
// The altitude it corrects with is the last one a fetch recorded rather than a
// fresh barometer reading. Altitude changes slowly next to how often a glance
// is drawn, and taking a sensor reading on every draw is not a trade a glance
// budget can afford.
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
}
