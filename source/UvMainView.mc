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

    // Refetch on every show. The old gate was `!requestInFlight && !hasReading()`,
    // and since uvIndex is persisted to storage and restored by UvState.load(),
    // that meant the app stopped calling the API entirely once a single fetch
    // had succeeded: it retried forever while broken and never once it worked.
    // Exactly backwards for a build whose only job is exercising the fetch.
    function onShow() as Void {
        refetch();
    }

    // Also reached from the START button, via UvMainDelegate.
    public function refetch() as Void {
        var state = UvState.get();
        if (state.requestInFlight) {
            return;
        }

        // Drop the in-memory value so a stale reading cannot sit on screen
        // looking like a fresh one. Storage is untouched, so the glance keeps
        // showing the last good figure until a new fetch actually succeeds.
        state.uvIndex = null;
        state.clearError();

        var client = new UvClient(method(:onFetchDone));
        _client = client;
        client.start();
        WatchUi.requestUpdate();
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

        var below = drawReading(dc, w, h, state);
        drawDiagnostics(dc, w, h, below, state);
    }

    // Returns the y just below the band label, so the diagnostic stack starts
    // from a measured position instead of a guessed fraction. FONT_NUMBER_HOT
    // is tall enough on a 416 px screen that the old hardcoded 0.20 / 0.42
    // split drew the number straight through "UV INDEX". Measuring the font
    // rather than assuming its height also keeps the other epix Pro sizes free.
    private function drawReading(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Number {
        var uv = state.uvIndex;

        // Local variable types are inferred in Monkey C - an explicit "as Type"
        // on a local is a compile error, unlike on a field or a parameter.
        // Defaults here are the no-reading case, so each branch only overrides
        // what actually differs.
        var label = "--";
        var colour = Graphics.COLOR_DK_GRAY;
        var band = "UV INDEX";

        if (uv != null) {
            label = uv.format("%.1f");
            colour = UvScale.colour(uv);
            band = UvScale.riskBand(uv);
        } else if (state.requestInFlight) {
            label = "...";
            colour = Graphics.COLOR_LT_GRAY;
        }

        var numberTop = (h * 0.14).toNumber();
        var numberHeight = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        var bandHeight = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, numberTop, Graphics.FONT_NUMBER_HOT,
                    label, Graphics.TEXT_JUSTIFY_CENTER);

        var bandTop = numberTop + numberHeight;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, bandTop, Graphics.FONT_XTINY,
                    band, Graphics.TEXT_JUSTIFY_CENTER);

        return bandTop + bandHeight;
    }

    // The diagnostic stack. Each line answers one question: did GPS work, did
    // the barometer work, did the request work, what did the API assume.
    private function drawDiagnostics(dc as Graphics.Dc, w as Number, h as Number, top as Number, state as UvState) as Void {
        var lines = [];

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

        // "No request yet" used to cover both "not started" and "in flight".
        // Separating them means a hung fetch reads as a hung fetch.
        var error = state.errorText;
        var code = state.httpCode;
        if (error != null) {
            lines.add(error);
        } else if (state.requestInFlight) {
            lines.add("Fetching...");
        } else if (code != null) {
            lines.add("HTTP " + code.toString() + " OK");
        } else {
            lines.add("No request yet");
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var y = top + (h * 0.02).toNumber();
        var step = dc.getFontHeight(Graphics.FONT_XTINY) + (h * 0.015).toNumber();
        for (var i = 0; i < lines.size(); i += 1) {
            // The error line reads red; the rest stay white.
            if (i == 2 && error != null) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(w / 2, y + (i * step), Graphics.FONT_XTINY,
                        lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.84).toNumber(), Graphics.FONT_XTINY,
                    "START = retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
