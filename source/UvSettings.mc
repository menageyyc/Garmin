import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;

// The one setting that changes the number on screen: what you are standing on.
//
// The server cannot know you are on a snowfield rather than in a car park, so
// the surface is the wearer's half of the correction. It is stored as a small
// index in Application.Properties, which means it can be set from the on-watch
// menu or from Garmin Connect on the phone, and neither overwrites the other's
// store.
//
// v1a also had a "Surroundings" setting (open / partly open / enclosed). It was
// removed on 2026-09-23 after the cold review: it only scaled the reflected
// term, so "Enclosed: forest" left the direct and sky light - which is nearly
// all the UV in a forest - untouched, and read as the API's number while the
// wearer believed shade was accounted for. Shade belongs in v2 as a dose pause.
// The number on screen is for open sky and says nothing about shade.
//
// The surface resets to grass at local midnight. It is situational - you set
// fresh snow on arriving at the hill - and a setting with no way to leave it
// was a standing over-report every weekday after a ski Saturday.
//
// Deliberately NOT annotated (:background). A background process cannot write
// Application Properties at all, and it has no business reading them either -
// it caches the raw API series and the correction happens on the watch.
//
// The labels below are duplicated in resources/settings/settings.xml, which is
// what the phone-side editor reads. Loading them through Rez instead would cost
// a loadResource call per draw in the glance and hand back a Resource the
// strict checker will not pass to a String parameter. If you change one,
// change both.
(:glance)
module UvSettings {

    const KEY_SURFACE = "surface";

    // Application.Storage, not Properties: these never need to appear in the
    // phone editor, and Storage needs no key declaration.
    const KEY_SET_DAY = "sday";     // local midnight (epoch) of the day it was set
    const KEY_SET_VALUE = "sval";   // the index that was set then

    const SURFACE_COUNT = 6;
    const SURFACE_DEFAULT = 0;

    // What each surface adds to the UV index, as a fraction.
    //
    // Snow (settled 2026-09-23): CAMS already models snow albedo whenever its
    // own snow depth exceeds 2 cm, so the snow figures are only the LOCAL
    // increment of a piste over a 40 km cell that is mostly forest and rock.
    // Fresh snow is the middle of +15-20%, old snow the middle of +5-10%. They
    // replace v1a's 0.85 and 0.50 albedo times 0.5 openness (+42% / +25%),
    // which counted the same effect CAMS had already counted. Measured
    // clear-sky snow enhancement of the whole index is only 15-25%.
    //
    // The other four are v1a's figures with openness fixed at "open" (0.5 x
    // albedo), unchanged by the review. Sand therefore sits above old snow.
    // That is not a typo: CAMS does not model sand, so sand carries its whole
    // effect while old snow carries only the residual. Open question 25.
    function surfaceIncrement(index as Number) as Float {
        if (index == 1) { return 0.05; }    // concrete, 0.10 albedo
        if (index == 2) { return 0.035; }   // water, 0.07 albedo
        if (index == 3) { return 0.09; }    // dry sand, 0.18 albedo
        if (index == 4) { return 0.075; }   // old snow, residual over CAMS
        if (index == 5) { return 0.175; }   // fresh snow, residual over CAMS
        return 0.015;                       // grass, 0.03 albedo
    }

    function surfaceName(index as Number) as String {
        if (index == 1) { return "Concrete"; }
        if (index == 2) { return "Water"; }
        if (index == 3) { return "Sand"; }
        if (index == 4) { return "Old snow"; }
        if (index == 5) { return "Fresh snow"; }
        return "Grass";
    }

    // toNumber() before toString(). Handing "%d" to a Float's format() is not
    // a conversion the runtime promises anything about.
    function surfaceDetail(index as Number) as String {
        return "about +" + (surfaceIncrement(index) * 100.0).toNumber().toString() + "%";
    }

    // The surface in force now. A surface other than grass that was set on an
    // earlier day reads as grass. Reading never writes - the glance calls this
    // too, and a glance is not the place to be writing storage - so the
    // property itself is reset later, by expireSurface() from the app.
    function surface() as Number {
        var idx = readIndex(KEY_SURFACE, SURFACE_COUNT);
        if (idx == SURFACE_DEFAULT) {
            return idx;
        }
        var setIdx = UvNum.asNumber(Application.Storage.getValue(KEY_SET_VALUE));
        var setDay = UvNum.asNumber(Application.Storage.getValue(KEY_SET_DAY));

        // Not stamped, or stamped for a different value: it was set from the
        // phone, which leaves no stamp. Honour it; the app stamps it on its
        // next show, which starts the clock from then.
        if (setIdx == null || setDay == null) {
            return idx;
        }
        if (setIdx != idx) {
            return idx;
        }
        if (setDay != today()) {
            return SURFACE_DEFAULT;
        }
        return idx;
    }

    // App only, from onShow. Stamps a surface the phone set, and writes the
    // midnight reset back to the property so the phone editor shows grass too.
    function expireSurface() as Void {
        var idx = readIndex(KEY_SURFACE, SURFACE_COUNT);
        if (idx == SURFACE_DEFAULT) {
            return;
        }
        var setIdx = UvNum.asNumber(Application.Storage.getValue(KEY_SET_VALUE));
        var setDay = UvNum.asNumber(Application.Storage.getValue(KEY_SET_DAY));
        if (setIdx == null || setDay == null) {
            stamp(idx);
            return;
        }
        if (setIdx != idx) {
            stamp(idx);
            return;
        }
        if (setDay != today()) {
            writeIndex(KEY_SURFACE, SURFACE_DEFAULT, SURFACE_COUNT);
            stamp(SURFACE_DEFAULT);
        }
    }

    function stamp(index as Number) as Void {
        Application.Storage.setValue(KEY_SET_VALUE, index);
        Application.Storage.setValue(KEY_SET_DAY, today());
    }

    // Local midnight today, as epoch seconds. Time.today() is already local,
    // so a day key needs no calendar arithmetic and survives DST changes.
    function today() as Number {
        return Time.today().value();
    }

    function increment() as Float {
        return surfaceIncrement(surface());
    }

    // For the diagnostics page.
    function describe() as String {
        var idx = surface();
        if (idx == SURFACE_DEFAULT) {
            return surfaceName(idx);
        }
        return surfaceName(idx) + " until midnight";
    }

    // From the on-watch picker. Stamped at the same moment, so the midnight
    // clock starts when the wearer chose it.
    function setSurface(index as Number) as Void {
        writeIndex(KEY_SURFACE, index, SURFACE_COUNT);
        stamp(index);
    }

    // Every read is clamped as well as narrowed. A value arriving from the
    // phone-side editor is not guaranteed to be in range - a settings file
    // written by an older build, or a hand-edited .SET, can carry anything -
    // and an out-of-range index would fall through to the default silently.
    // Clamping makes it fall back to the default deliberately instead.
    // Checking is off for one reason: Properties.getValue hands back Any, and
    // a local initialised to null then reassigned from it is inferred as Null.
    // The value is narrowed and clamped before it leaves, so the caller keeps
    // full checking.
    //
    // Not `private`. A module member cannot carry an access modifier in Monkey
    // C - `private` is class-only - and the parser gives up on the whole module
    // body when it meets one, so the next function reports as a second,
    // unrelated-looking error. Helpers in a module are reachable as
    // UvSettings.readIndex(), which is harmless.
    (:typecheck(false))
    function readIndex(key as String, count as Number) as Lang.Number {
        var raw = null;
        try {
            raw = Application.Properties.getValue(key);
        } catch (e) {
            raw = null;
        }
        var v = UvNum.asNumber(raw);
        if (v == null || v < 0 || v >= count) {
            return 0;
        }
        return v;
    }

    // Properties.setValue throws InvalidKeyException if the key is not
    // declared in the settings resources, so a typo here is a crash rather
    // than a no-op. The key is declared in resources/settings/properties.xml.
    function writeIndex(key as String, index as Number, count as Number) as Void {
        if (index < 0 || index >= count) {
            return;
        }
        try {
            Application.Properties.setValue(key, index);
        } catch (e) {
        }
    }
}
