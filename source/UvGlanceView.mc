import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

// The glance reads the last reading the app persisted to storage. It never
// fetches: glances run under a tight memory budget and are drawn often, so
// network work belongs in the background service, which arrives in v1.
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

        var uv = state.uvIndex;
        if (uv != null) {
            dc.setColor(UvScale.colour(uv), Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, (h * 0.42).toNumber(), Graphics.FONT_TINY,
                        uv.format("%.1f") + "  " + UvScale.riskBand(uv),
                        Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, (h * 0.42).toNumber(), Graphics.FONT_TINY, "--", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
