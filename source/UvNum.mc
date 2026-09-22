import Toybox.Lang;

// Runtime narrowing, in one place.
//
// Four separate APIs in this project hand back values whose type is only known
// when the program runs: JSON payloads from Open-Meteo, Application.Storage
// reads, Application.Properties reads, and menu item identifiers. All four
// yield Any, Monkey C's top type.
//
// (:typecheck(false)) is the honest resolution to a genuine dead end, not a
// shortcut. Any sits above Object, so an Any cannot be passed to a parameter
// declared Object. Any has no writable name either - spelling it draws
// "Cannot resolve type 'Any'" - while strict mode insists every parameter
// carry a type. No annotation satisfies both. These functions exist precisely
// to inspect a value whose type is unknown until runtime, which is the one job
// a static checker cannot do. Every one returns a fully typed value, so
// nothing downstream loses checking.
//
// (:glance) only, for now. This module belongs in the background scope too -
// the service will parse JSON with it - but v1b adds that annotation at the
// same time as the service and the manifest permission. Annotating early is
// not free: ANY (:background) in the project makes it a background
// application, and the compiler then rejects the build until the manifest
// declares the Background permission. An annotation is a declaration that a
// scope exists, not a note about a scope that might.
(:glance)
module UvNum {

    // Open-Meteo returns an integer where a value happens to be whole and a
    // float otherwise, so both branches are genuinely taken. Confirmed live on
    // 2026-09-22: Olathe returned 0, Bangkok returned 9.5.
    (:typecheck(false))
    function asFloat(value) as Lang.Float or Null {
        if (value instanceof Lang.Float)  { return value; }
        if (value instanceof Lang.Double) { return value.toFloat(); }
        if (value instanceof Lang.Number) { return value.toFloat(); }
        if (value instanceof Lang.Long)   { return value.toFloat(); }
        return null;
    }

    (:typecheck(false))
    function asNumber(value) as Lang.Number or Null {
        if (value instanceof Lang.Number) { return value; }
        if (value instanceof Lang.Long)   { return value.toNumber(); }
        if (value instanceof Lang.Float)  { return value.toNumber(); }
        if (value instanceof Lang.Double) { return value.toNumber(); }
        return null;
    }

    // Storage hands back an Array as Any. The elements inside it are still
    // Any, so a caller reading them goes back through asFloat.
    (:typecheck(false))
    function asArray(value) as Lang.Array or Null {
        if (value instanceof Lang.Array) { return value; }
        return null;
    }
}
