import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.Application;

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

    private const PAGE_READING = 0;
    private const PAGE_DIAGNOSTICS = 1;
    private const PAGE_SETTINGS = 2;
    private const PAGE_COUNT = 3;

    // Below this, a correction term is not worth a line. k_alt is a plus or
    // minus 30% assumption and the surface figures are upper-limit estimates,
    // so anything under 2% is well inside the model's own error bars. Printing
    // "+1%" claims a precision this does not have. Since question 25 (2026-09-23)
    // water's +1% and grass's 0% never show a percentage; sand and concrete
    // just clear it. Percentages are rounded, not truncated - see UvCorrection.
    private const MIN_SHOWN_PERCENT = 2;

    // The clear-sky line shows only when a clear sky would read at least this
    // much higher than the forecast (v1b, decision 4). Below it the two
    // numbers are the same to one decimal and inside the model's own spread,
    // so the line would be noise - on a clear day, and at night, it is hidden.
    private const CLEAR_MARGIN = 0.5;

    private var _client as UvClient or Null = null;
    private var _page as Number = 0;

    function initialize() {
        View.initialize();
    }

    // The cache is the whole point of v1, so the network is a fallback rather
    // than a reflex: fetch only when what is stored cannot answer for this
    // hour, is older than one CAMS run, or was fetched for somewhere else.
    // START forces a fetch regardless, which is also the test loop.
    //
    // Position and altitude are read first, from what the system already
    // holds. In v1a they were read only when a fetch started, so "have you
    // moved?" compared the fetch position with itself and never fired.
    //
    // Since v1b they are also persisted here, not only by a fetch: the
    // background service fetches for the position in storage, and that
    // should be where the watch last was, not where it last fetched.
    function onShow() as Void {
        UvSense.sampleAltitude();
        UvSense.sampleCachedFix();
        UvSettings.expireSurface();

        var state = UvState.get();
        state.savePosition();
        if (state.cacheState() != CACHE_CURRENT) {
            refetch();
        }
    }

    public function nextPage() as Void {
        _page = (_page + 1) % PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    public function prevPage() as Void {
        _page = (_page + PAGE_COUNT - 1) % PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    // BACK returns to the reading page from a sub-page, and only leaves the app
    // from the reading page itself. The platform default is that BACK quits
    // from anywhere, which on a three-page app reads as the app falling over:
    // you press BACK expecting to undo a page turn and end up outside the app
    // entirely. Returning false hands the press back to the framework, which is
    // what makes the reading page still exit normally.
    public function backPressed() as Boolean {
        if (_page == PAGE_READING) {
            return false;
        }
        _page = PAGE_READING;
        WatchUi.requestUpdate();
        return true;
    }

    // START means refresh everywhere except the settings page, where it opens
    // the surface picker. The settings menu also hangs off MENU, but MENU is a long
    // press of UP on this hardware and Garmin's own forums carry reports of
    // onMenu() never firing on some fenix and epix models. A feature reachable
    // only through a button behaviour with that track record is a feature that
    // is sometimes missing, so it gets a second route that cannot fail.
    public function onSelectPressed() as Void {
        if (_page == PAGE_SETTINGS) {
            UvSettingsMenu.show();
            return;
        }
        refetch();
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

        if (_page == PAGE_DIAGNOSTICS) {
            drawDiagnostics(dc, w, h, state);
        } else if (_page == PAGE_SETTINGS) {
            drawSettings(dc, w, h);
        } else {
            drawReading(dc, w, h, state);
        }

        drawHint(dc, w, h);
        drawPageDots(dc, w, h);
    }

    // The old hint read "START refresh  MENU set" and the final character fell
    // off the edge of the screen. At 86% of the way down a round 416 px face
    // the chord is about 288 px, not the full width - roughly 0.69 w. Measure
    // the string and fall back to a shorter one rather than assuming, so the
    // 390 and 454 px siblings stay free.
    private function drawHint(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var text = "START refresh";
        var brief = "START";
        if (_page == PAGE_DIAGNOSTICS) {
            text = "DOWN for settings";
            brief = "DOWN = set";
        } else if (_page == PAGE_SETTINGS) {
            text = "START to change";
            brief = "START";
        }

        var available = (w * 0.68).toNumber();
        if (dc.getTextWidthInPixels(text, Graphics.FONT_XTINY) > available) {
            text = brief;
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.86).toNumber(), Graphics.FONT_XTINY,
                    text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Nothing on the reading page said other pages existed, and the first live
    // test found exactly that - the settings page was unreachable because it
    // was invisible. Three dots is the platform idiom and the space is free:
    // the app peaks at 23.3 kB of a 763.6 kB budget, measured on 2026-09-22.
    private function drawPageDots(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var r = (w * 0.009).toNumber();
        if (r < 2) {
            r = 2;
        }
        var gap = (w * 0.042).toNumber();
        var y = (h * 0.93).toNumber();
        var first = w / 2 - gap;

        for (var i = 0; i < PAGE_COUNT; i += 1) {
            if (i == _page) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(first + (i * gap), y, r);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(first + (i * gap), y, r);
            }
        }
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

            // Expired means a different sky or more than 12 hours old. Drawn
            // big and banded in colour, "a number for somewhere else" looked
            // exactly like "a number for here"; grey is the difference.
            if (state.cacheState() == CACHE_EXPIRED) {
                colour = Graphics.COLOR_LT_GRAY;
            }
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

        // The ceiling if the forecast cloud does not turn up, corrected the
        // same way as the big number. CAMS's cloud at 40 km over mountains is
        // the largest error in the whole chain, and it fails in the dangerous
        // direction: forecast overcast, actual bluebird (review finding 11).
        // Tinted by the band it would reach, so "could be HIGH" reads at a
        // glance.
        // Nested single tests: both values are used in arithmetic, and a
        // combined null test does not narrow the second one.
        var clear = state.effectiveClearNow();
        if (uv != null) {
            if (clear != null) {
                if (clear - uv >= CLEAR_MARGIN) {
                    lines.add("up to " + clear.format("%.1f") + " if sky clears");
                    tints.add(state.cacheState() == CACHE_EXPIRED
                              ? Graphics.COLOR_LT_GRAY : UvScale.colour(clear));
                }
            }
        }

        // A percentage under 2% is not printed - it is inside the model's own
        // error bars. But the surface NAME is always printed: on the hill with
        // the surface never set, "the app thinks you are on grass" is the one
        // thing the wearer needs to see, and v1a hid the word along with the
        // number (2026-09-23 review, finding 8).
        var surface = UvSettings.surface();
        var surfaceWord = UvSettings.surfaceName(surface).toLower();
        var altPct = UvCorrection.altitudePercent(state.watchAltitude, state.forecast.gridElevation);
        var surfPct = UvCorrection.surfacePercent(UvSettings.surfaceIncrement(surface));

        var showAlt = (altPct >= MIN_SHOWN_PERCENT) || (altPct <= -MIN_SHOWN_PERCENT);
        var showSurf = (surfPct >= MIN_SHOWN_PERCENT) || (surfPct <= -MIN_SHOWN_PERCENT);

        if (showAlt) {
            lines.add(signed(altPct) + "% altitude");
            tints.add(Graphics.COLOR_LT_GRAY);
        }
        if (showSurf) {
            // "about": the surface figures are estimates, and the snow ones
            // are only the residual over what CAMS already modelled.
            lines.add("about " + signed(surfPct) + "% " + surfaceWord);
            tints.add(Graphics.COLOR_LT_GRAY);
        } else if (!showAlt && raw != null) {
            lines.add(surfaceWord + ", no correction");
            tints.add(Graphics.COLOR_DK_GRAY);
        } else {
            lines.add(surfaceWord);
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
            lines.add(lat.format("%.2f") + ", " + lon.format("%.2f"));
            tints.add(Graphics.COLOR_WHITE);
            lines.add(fixText(state));
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

        var bgError = backgroundError();
        lines.add(backgroundText(bgError));
        tints.add(bgError == null ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_ORANGE);

        lines.add(statusText(state));
        tints.add(statusTint(state));

        drawStack(dc, w, h, top + dc.getFontHeight(Graphics.FONT_XTINY), lines, tints);
    }

    // The background service's last result. Nothing else on the watch shows
    // whether it is running at all, and on a real watch that is the first
    // question (v1b). "bg" rather than "background" to fit the chord.
    private function backgroundText(error as String or Null) as String {
        var at = UvNum.asNumber(Application.Storage.getValue(UvFetch.KEY_BG_AT));
        if (at == null) {
            return "bg: not run yet";
        }
        var ago = UvSense.ageText(nowEpoch() - at);
        if (error != null) {
            return "bg " + ago + ": " + error;
        }
        return "bg OK " + ago + " ago";
    }

    (:typecheck(false))
    private function backgroundError() as Lang.String or Null {
        var e = Application.Storage.getValue(UvFetch.KEY_BG_ERROR);
        if (e instanceof Lang.String) {
            return e;
        }
        return null;
    }

    // The settings page exists so the picker is reachable without MENU. It
    // also shows what the current surface is worth, which is the honest
    // answer to "why is this app's number different from the others".
    private function drawSettings(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var top = (h * 0.16).toNumber();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, top, Graphics.FONT_XTINY, "SETTINGS", Graphics.TEXT_JUSTIFY_CENTER);

        var surface = UvSettings.surface();
        var pct = UvCorrection.surfacePercent(UvSettings.surfaceIncrement(surface));

        var lines = ["Surface", UvSettings.surfaceName(surface),
                     pct == 0 ? "no change to UV" : "about " + signed(pct) + "% UV",
                     surface == UvSettings.SURFACE_DEFAULT ? "default" : "until midnight",
                     "open sky; shade not modelled"];
        var tints = [Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE,
                     Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY,
                     Graphics.COLOR_DK_GRAY];

        drawStack(dc, w, h, top + dc.getFontHeight(Graphics.FONT_XTINY), lines, tints);
    }

    // Where the fix came from and how old it was when read. "(cached, 2 d)" is
    // a very different claim from "(cached, 3 min)", and v1a printed both as
    // "(cached)".
    private function fixText(state as UvState) as String {
        if (state.fixSource == FIX_LIVE) {
            return "live GPS fix";
        }
        var age = state.fixAgeSeconds;
        if (state.fixSource == FIX_CACHED) {
            if (age == null) {
                return "cached fix, age ?";
            }
            return "cached fix, " + UvSense.ageText(age);
        }
        // The position shown is restored from the last fetch. On a real watch
        // this is also what you see when the cached fix was refused as too
        // old - the console says which.
        return "from last fetch";
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
