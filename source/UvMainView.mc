import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;

// v0's job is not to look good. It is to prove every external dependency works
// and to say precisely which one failed when something does. Layout is
// deliberately drawn in code and sized as a fraction of the screen, so the
// other two epix Pro sizes cost nothing later.
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

        // Big number, then a stack of diagnostics under it.
        drawReading(dc, w, h, state);
        drawDiagnostics(dc, w, h, state);
    }

    private function drawReading(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Void {
        var label;
        var colour;

        if (state.hasReading()) {
            label = state.uvIndex.format("%.1f");
            colour = UvScale.colour(state.uvIndex);
        } else if (state.requestInFlight) {
            label = "...";
            colour = Graphics.COLOR_LT_GRAY;
        } else {
            label = "--";
            colour = Graphics.COLOR_DK_GRAY;
        }

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.20, Graphics.FONT_NUMBER_HOT,
                    label, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.42, Graphics.FONT_XTINY,
                    state.hasReading() ? UvScale.riskBand(state.uvIndex) : "UV INDEX",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The diagnostic stack. Each line answers one question: did GPS work, did
    // the barometer work, did the request work, what did the API assume.
    private function drawDiagnostics(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Void {
        var lines = [];

        if (state.hasPosition()) {
            lines.add(state.latitude.format("%.2f") + ", " + state.longitude.format("%.2f")
                      + (state.fixSource == FIX_CACHED ? " (cached)" : ""));
        } else {
            lines.add("No position");
        }

        if (state.watchAltitude != null) {
            var alt = state.watchAltitude.format("%.0f") + " m";
            var delta = state.altitudeDelta();
            if (delta != null) {
                alt += (delta >= 0 ? "  +" : "  ") + delta.format("%.0f") + " vs grid";
            }
            lines.add(alt);
        } else {
            lines.add("No altitude");
        }

        if (state.errorText != null) {
            lines.add(state.errorText);
        } else if (state.httpCode != null) {
            lines.add("HTTP " + state.httpCode.toString() + " OK");
        } else {
            lines.add("No request yet");
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var y = h * 0.56;
        var step = h * 0.09;
        for (var i = 0; i < lines.size(); i += 1) {
            // The error line reads red; the rest stay white.
            if (i == 2 && state.errorText != null) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, y + (i * step), Graphics.FONT_XTINY,
                        lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
