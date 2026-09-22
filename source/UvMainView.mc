import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;

// Two pages. The first is the answer; the second is why you should believe it.
//
// v0's screen was a diagnostic that happened to show a UV number. v1 inverts
// that: the reading and what corrected it come first, and position, grid
// elevation and HTTP status move to a second page reached with DOWN. The
// diagnostics stay because they earned their place - every problem in this
// project so far was found by reading them - but they are no longer what the
// app is for.
//
// Layout is drawn in code and flows from measured font heights rather than
// screen fractions, because FONT_NUMBER_HOT is tall enough on a 416 px screen
// that a guessed fraction drew the number straight through the band label.
// Measuring also means the 390 and 454 px siblings cost nothing later.
//
// Every nullable field is read into a local before use. The type checker cannot
// see that a helper guarantees non-null, and it is right not to - another
// thread of control could clear it between the two calls.
class UvMainView extends WatchUi.View {

    private var _client as UvClient or Null = null;
    private var _page as Number = 0;

    function initialize() {
        View.initialize();
    }

    // The cache is the whole point of v1, so the network is a fallback rather
    // than a reflex: fetch only when what is stored cannot answer for this
    // hour, or is old enough that the cloud state it described has moved on.
    // START forces a fetch regardless, which is also the test loop.
    function onShow() as Void {
        var state = UvState.get();
        if (state.cacheState() != CACHE_CURRENT) {
            refetch();
        }
    }

    public function nextPage() as Void {
        _page = (_page + 1) % 2;
        WatchUi.requestUpdate();
    }

    // Also reached from the START button, via UvMainDelegate.
    public function refetch() as Void {
        var state = UvState.get();
        if (state.requestInFlight) {
            return;
        }

        // Let the previous client go cleanly. Reading the field here is also
        // what the compiler wanted: calling start() on a local left _client
        // write-only, which it correctly flagged as unused.
        var previous = _client;
        if (previous != null) {
            previous.cancel();
        }

        // The cached series is deliberately left alone. A fetch that fails
        // should degrade the reading to "an hour old", not blank it.
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

        if (_page == 1) {
            drawDiagnostics(dc, w, h, state);
        } else {
            drawReading(dc, w, h, state);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.86).toNumber(), Graphics.FONT_XTINY,
                    "START refresh  MENU set", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawReading(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Void {
        var uv = state.effectiveNow();

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

        var numberTop = (h * 0.13).toNumber();
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, numberTop, Graphics.FONT_NUMBER_HOT,
                    label, Graphics.TEXT_JUSTIFY_CENTER);

        var bandTop = numberTop + dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, bandTop, Graphics.FONT_XTINY,
                    band, Graphics.TEXT_JUSTIFY_CENTER);

        var lines = [];
        var tints = [];

        // What the server said, before the watch touched it. Shown whenever
        // there is a raw value, including when the correction is nil, because
        // "the app disagrees with every other UV app" needs an answer on the
        // first screen rather than a page away.
        var raw = state.rawNow();
        if (raw != null) {
            lines.add("API " + raw.format("%.1f"));
            tints.add(Graphics.COLOR_WHITE);
        }

        // A term that rounds to nothing is not worth a line. In a city both do,
        // and saying so once is more honest than two rows of "+0%".
        var altPct = UvCorrection.altitudePercent(state.watchAltitude, state.forecast.gridElevation);
        var albPct = UvCorrection.albedoPercent(UvSettings.albedo(), UvSettings.fraction());

        if (altPct != 0) {
            lines.add(signed(altPct) + "% altitude");
            tints.add(Graphics.COLOR_LT_GRAY);
        }
        if (albPct != 0) {
            lines.add(signed(albPct) + "% " + UvSettings.surfaceName(UvSettings.surface()).toLower());
            tints.add(Graphics.COLOR_LT_GRAY);
        }
        if (altPct == 0 && albPct == 0 && raw != null) {
            lines.add("no correction");
            tints.add(Graphics.COLOR_DK_GRAY);
        }

        lines.add(statusText(state));
        tints.add(statusTint(state));

        drawStack(dc, w, h, bandTop + dc.getFontHeight(Graphics.FONT_XTINY), lines, tints);
    }

    private function drawDiagnostics(dc as Graphics.Dc, w as Number, h as Number, state as UvState) as Void {
        var top = (h * 0.16).toNumber();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, top, Graphics.FONT_XTINY, "DIAGNOSTICS", Graphics.TEXT_JUSTIFY_CENTER);

        var lines = [];
        var tints = [];

        var lat = state.latitude;
        var lon = state.longitude;
        if (lat != null && lon != null) {
            lines.add(lat.format("%.2f") + ", " + lon.format("%.2f")
                      + (state.fixSource == FIX_CACHED ? " (cached)" : ""));
        } else {
            lines.add("No position");
        }
        tints.add(Graphics.COLOR_WHITE);

        var alt = state.watchAltitude;
        var grid = state.forecast.gridElevation;
        if (alt != null && grid != null) {
            lines.add(alt.format("%.0f") + " m / grid " + grid.format("%.0f") + " m");
        } else if (alt != null) {
            lines.add(alt.format("%.0f") + " m / no grid");
        } else {
            lines.add("No altitude");
        }
        tints.add(Graphics.COLOR_WHITE);

        var code = state.httpCode;
        var idx = state.forecast.indexAt(nowEpoch());
        lines.add((code == null ? "no HTTP" : "HTTP " + code.toString())
                  + "  idx " + idx.toString() + "/" + state.forecast.hourCount().toString());
        tints.add(Graphics.COLOR_WHITE);

        lines.add(UvSettings.describe());
        tints.add(Graphics.COLOR_LT_GRAY);

        lines.add(statusText(state));
        tints.add(statusTint(state));

        drawStack(dc, w, h, top + dc.getFontHeight(Graphics.FONT_XTINY), lines, tints);
    }

    // One line per question, flowed down from a measured starting point.
    private function drawStack(dc as Graphics.Dc, w as Number, h as Number, top as Number,
                               lines as Array, tints as Array) as Void {
        var y = top + (h * 0.03).toNumber();
        var step = dc.getFontHeight(Graphics.FONT_XTINY) + (h * 0.012).toNumber();
        for (var i = 0; i < lines.size(); i += 1) {
            dc.setColor(tintAt(tints, i), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + (i * step), Graphics.FONT_XTINY,
                        textAt(lines, i), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Array lookups yield Any, which cannot be passed to a typed parameter.
    // Same dead end as the JSON narrowing, same resolution, same tiny blast
    // radius - these two return fully typed values.
    (:typecheck(false))
    private function textAt(items, i) as Lang.String {
        return items[i];
    }

    (:typecheck(false))
    private function tintAt(items, i) as Lang.Number {
        return items[i];
    }

    private function nowEpoch() as Number {
        return Time.now().value();
    }

    private function signed(percent as Number) as String {
        return (percent > 0 ? "+" : "") + percent.toString();
    }

    // One line answering "should I believe this number right now". An error
    // beats everything else, because a stale reading with a failing fetch
    // behind it is not the same situation as a stale reading nobody retried.
    private function statusText(state as UvState) as String {
        var error = state.errorText;
        if (error != null) {
            return error;
        }
        if (state.requestInFlight) {
            return "Fetching...";
        }

        var cache = state.cacheState();
        if (cache == CACHE_ABSENT) {
            return "No data yet";
        }
        if (cache == CACHE_EXPIRED) {
            return "Cache expired";
        }

        var mins = state.ageMinutes();
        if (mins == null) {
            return "Cached";
        }
        if (mins < 1) {
            return "Just now";
        }
        if (mins < 90) {
            return mins.toString() + " min ago";
        }
        return (mins / 60).toString() + " h old";
    }

    private function statusTint(state as UvState) as Number {
        if (state.errorText != null) {
            return Graphics.COLOR_RED;
        }
        if (state.requestInFlight) {
            return Graphics.COLOR_LT_GRAY;
        }
        var cache = state.cacheState();
        if (cache == CACHE_CURRENT) {
            return Graphics.COLOR_WHITE;
        }
        if (cache == CACHE_STALE) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_ORANGE;
    }
}
