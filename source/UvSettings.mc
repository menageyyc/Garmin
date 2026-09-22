import Toybox.Lang;
import Toybox.Application;

// The two settings that change the number on screen.
//
// Surface albedo and openness are the wearer's half of the correction: the
// server cannot know you are standing on a snowfield rather than in a car
// park. Both are stored as small indices in Application.Properties, which
// means the same value can be set from the on-watch menu or from Garmin
// Connect on the phone, and neither overwrites the other's store.
//
// Deliberately NOT annotated (:background). A background process cannot write
// Application Properties at all, and it has no business reading them either -
// it caches the raw API series and the correction happens on the watch, where
// the barometer is.
//
// The labels below are duplicated in resources/settings/settings.xml, which is
// what the phone-side editor reads. Loading them through Rez instead would cost
// a loadResource call per draw in the glance and hand back a Resource the
// strict checker will not pass to a String parameter. Nine short English
// strings are cheaper. If you change one, change both.
(:glance)
module UvSettings {

    const KEY_SURFACE = "surface";
    const KEY_OPENNESS = "openness";

    const SURFACE_COUNT = 6;
    const OPENNESS_COUNT = 3;

    // Albedo ranges are from the build plan's factor table. The stored figure
    // is the middle of each range rather than its worst case, because the
    // openness fraction is already generous.
    //   fresh snow 0.80-0.90 | old snow 0.40-0.60 | dry sand 0.15-0.20
    //   concrete 0.10-0.12   | water 0.05-0.10    | grass 0.02-0.05
    //
    // Water is the one to treat with suspicion: 0.07 is the midday figure, and
    // reflectance off water climbs steeply at low sun angles and with glint.
    function surfaceAlbedo(index as Number) as Float {
        if (index == 1) { return 0.10; }
        if (index == 2) { return 0.07; }
        if (index == 3) { return 0.18; }
        if (index == 4) { return 0.50; }
        if (index == 5) { return 0.85; }
        return 0.03;
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
        return "reflects " + (surfaceAlbedo(index) * 100.0).toNumber().toString() + "%";
    }

    // f in the correction: the fraction of the reflecting surface in view.
    // 0.5 is an open snowfield or a wide beach - half your sky is ground.
    function opennessFraction(index as Number) as Float {
        if (index == 1) { return 0.25; }
        if (index == 2) { return 0.10; }
        return 0.50;
    }

    function opennessName(index as Number) as String {
        if (index == 1) { return "Partly open"; }
        if (index == 2) { return "Enclosed"; }
        return "Open";
    }

    function opennessDetail(index as Number) as String {
        if (index == 1) { return "scattered trees, buildings"; }
        if (index == 2) { return "forest, narrow valley, street"; }
        return "piste, beach, open water";
    }

    function surface() as Number {
        return readIndex(KEY_SURFACE, SURFACE_COUNT);
    }

    function openness() as Number {
        return readIndex(KEY_OPENNESS, OPENNESS_COUNT);
    }

    function albedo() as Float {
        return surfaceAlbedo(surface());
    }

    function fraction() as Float {
        return opennessFraction(openness());
    }

    // One line describing both, for the screen.
    function describe() as String {
        return surfaceName(surface()) + ", " + opennessName(openness()).toLower();
    }

    function setSurface(index as Number) as Void {
        writeIndex(KEY_SURFACE, index, SURFACE_COUNT);
    }

    function setOpenness(index as Number) as Void {
        writeIndex(KEY_OPENNESS, index, OPENNESS_COUNT);
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
    // than a no-op. Both keys are declared in resources/settings/properties.xml.
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
