import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;

// v0's job is not to look good. It is to prove every external dependency works
// and to say precisely which one failed when something does. Layout is
// deliberately drawn in code and sized as a fraction of the screen, so the
// other two epix Pro sizes cost nothing later.
//
// Every nullable field is read into a local before use. The type checker cannot
// see that a helper like hasReading() guarantees uvIndex is non-null, and it is
// right not to - another thread of control could clear it between the two calls.
class UvMainView extends WatchUi.View {

    private var _client as UvClient or Null = null;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        var state = UvState.get();
        if (!state.requestInFlight && !state.hasReading()) {
            _client = new UvClient(method(:onFetchDone));
            _client.start();
        }
    }

    public function onFetchDone(success as Boolean) as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var state = UvState.get();
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        drawReading(dc, w, h, state);
        drawDiagnostics(dc, w, h, state);
    }

    private function drawReading(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Void {
        var uv = state.uvIndex;

        var label as String;
        var colour as Number;
        var band as String;

        if (uv != null) {
            label = uv.format("%.1f");
            colour = UvScale.colour(uv);
            band = UvScale.riskBand(uv);
        } else if (state.requestInFlight) {
            label = "...";
            colour = Graphics.COLOR_LT_GRAY;
            band = "UV INDEX";
        } else {
            label = "--";
            colour = Graphics.COLOR_DK_GRAY;
            band = "UV INDEX";
        }

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.20).toNumber(), Graphics.FONT_NUMBER_HOT,
                    label, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.42).toNumber(), Graphics.FONT_XTINY,
                    band, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The diagnostic stack. Each line answers one question: did GPS work, did
    // the barometer work, did the request work, what did the API assume.
    private function drawDiagnostics(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Void {
        var lines = [] as Array<String>;

        var lat = state.latitude;
        var lon = state.longitude;
        if (lat != null && lon != null) {
            lines.add(lat.format("%.2f") + ", " + lon.format("%.2f")
                      + (state.fixSource == FIX_CACHED ? " (cached)" : ""));
        } else {
            lines.add("No position");
        }

        var alt = state.watchAltitude;
        if (alt != null) {
            var text = alt.format("%.0f") + " m";
            var delta = state.altitudeDelta();
            if (delta != null) {
                text += (delta >= 0 ? "  +" : "  ") + delta.format("%.0f") + " vs grid";
            }
            lines.add(text);
        } else {
            lines.add("No altitude");
        }

        var error = state.errorText;
        var code = state.httpCode;
        if (error != null) {
            lines.add(error);
        } else if (code != null) {
            lines.add("HTTP " + code.toString() + " OK");
        } else {
            lines.add("No request yet");
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var y = h * 0.56;
        var step = h * 0.09;
        for (var i = 0; i < lines.size(); i += 1) {
            // The error line reads red; the rest stay white.
            if (i == 2 && error != null) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, (y + (i * step)).toNumber(), Graphics.FONT_XTINY,
                        lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
