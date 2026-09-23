import Toybox.Lang;
import Toybox.WatchUi;

// The surface picker, on the watch and not only on the phone.
//
// The surface is situational: you change it when you arrive at the ski hill,
// not when you install the app. Making that a trip into Garmin Connect would
// mean nobody ever does it, and an uncorrected number is the thing this app
// exists to avoid.
//
// It lives in Application.Properties, the same store the phone-side editor
// writes, so the two routes agree rather than shadowing each other. Last write
// wins, which is the right rule for a single wearer.
//
// v1a opened a two-row menu (Surface, Surroundings) first. Surroundings was
// removed on 2026-09-23, and a menu with one row is a wasted press, so this
// now opens the surface list directly.
//
// Not (:glance) annotated. It belongs to the app scope alongside UvMainView,
// and both are excluded from the glance build together, so there is no
// dangling reference. A glance cannot be tapped anyway - input delegate
// methods are not invoked while a glance view is running.
module UvSettingsMenu {

    function show() as Void {
        var menu = new WatchUi.Menu2({:title => "Surface"});
        for (var i = 0; i < UvSettings.SURFACE_COUNT; i += 1) {
            menu.addItem(new WatchUi.MenuItem(
                UvSettings.surfaceName(i),
                UvSettings.surfaceDetail(i),
                i,
                {}));
        }
        WatchUi.pushView(menu, new UvSurfaceDelegate(), WatchUi.SLIDE_UP);
    }

    // MenuItem.getId() is declared as returning Object or Null, and Object has
    // no conversion methods - the same dead end that produced "Cannot find
    // symbol ':toFloat' on type '$.Toybox.Lang.Object'" in v0. Narrow it the
    // way everything else in this project narrows a runtime value.
    (:typecheck(false))
    function idOf(item) as Lang.Number {
        var n = UvNum.asNumber(item.getId());
        if (n == null) {
            return -1;
        }
        return n;
    }
}

// Choosing a surface also starts its midnight clock - see UvSettings.
class UvSurfaceDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = UvSettingsMenu.idOf(item);
        if (id >= 0) {
            UvSettings.setSurface(id);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
