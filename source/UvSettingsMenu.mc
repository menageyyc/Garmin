import Toybox.Lang;
import Toybox.WatchUi;

// Settings on the watch, not only on the phone.
//
// Surface and surroundings are situational: you change them when you arrive at
// the ski hill, not when you install the app. Making that a trip into Garmin
// Connect would mean nobody ever does it, and an uncorrected number is the
// thing this app exists to avoid.
//
// Both values live in Application.Properties, the same store the phone-side
// editor writes, so the two routes agree rather than shadowing each other.
// Last write wins, which is the right rule for a single wearer.
//
// Not (:glance) annotated. It belongs to the app scope alongside UvMainView,
// and both are excluded from the glance build together, so there is no
// dangling reference. A glance cannot be tapped anyway - input delegate
// methods are not invoked while a glance view is running.
module UvSettingsMenu {

    // Identifiers for the top-level rows. Numbers rather than symbols because
    // MenuItem.getId() hands back an Object, and narrowing a Number out of one
    // is a pattern this project already has a helper for.
    const ROW_SURFACE = 0;
    const ROW_OPENNESS = 1;

    // The two rows are built here and handed to the delegate so that choosing
    // an option can update the row's sub-label in place. The alternative -
    // popping two views to get back to the reading - leaves the same menu on
    // screen showing the value you just changed away from if the second pop
    // does not land, and stacking pops inside one callback is not a contract
    // Connect IQ makes any promises about.
    function show() as Void {
        var surfaceRow = new WatchUi.MenuItem(
            "Surface",
            UvSettings.surfaceName(UvSettings.surface()),
            ROW_SURFACE,
            {});
        var opennessRow = new WatchUi.MenuItem(
            "Surroundings",
            UvSettings.opennessName(UvSettings.openness()),
            ROW_OPENNESS,
            {});

        var menu = new WatchUi.Menu2({:title => "UV settings"});
        menu.addItem(surfaceRow);
        menu.addItem(opennessRow);

        WatchUi.pushView(menu,
                         new UvSettingsMenuDelegate(surfaceRow, opennessRow),
                         WatchUi.SLIDE_UP);
    }

    function showSurface(row as WatchUi.MenuItem) as Void {
        var menu = new WatchUi.Menu2({:title => "Surface"});
        for (var i = 0; i < UvSettings.SURFACE_COUNT; i += 1) {
            menu.addItem(new WatchUi.MenuItem(
                UvSettings.surfaceName(i),
                UvSettings.surfaceDetail(i),
                i,
                {}));
        }
        WatchUi.pushView(menu, new UvSurfaceDelegate(row), WatchUi.SLIDE_LEFT);
    }

    function showOpenness(row as WatchUi.MenuItem) as Void {
        var menu = new WatchUi.Menu2({:title => "Surroundings"});
        for (var i = 0; i < UvSettings.OPENNESS_COUNT; i += 1) {
            menu.addItem(new WatchUi.MenuItem(
                UvSettings.opennessName(i),
                UvSettings.opennessDetail(i),
                i,
                {}));
        }
        WatchUi.pushView(menu, new UvOpennessDelegate(row), WatchUi.SLIDE_LEFT);
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

class UvSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _surfaceRow as WatchUi.MenuItem;
    private var _opennessRow as WatchUi.MenuItem;

    function initialize(surfaceRow as WatchUi.MenuItem, opennessRow as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _surfaceRow = surfaceRow;
        _opennessRow = opennessRow;
    }

    // Dispatch only. The two builders live in the module above so that no
    // single function declares `var menu` twice - Monkey C's scoping rules for
    // a var inside an if-block are not something worth discovering during a
    // build.
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = UvSettingsMenu.idOf(item);
        if (id == UvSettingsMenu.ROW_SURFACE) {
            UvSettingsMenu.showSurface(_surfaceRow);
        } else if (id == UvSettingsMenu.ROW_OPENNESS) {
            UvSettingsMenu.showOpenness(_opennessRow);
        }
    }
}

class UvSurfaceDelegate extends WatchUi.Menu2InputDelegate {

    private var _row as WatchUi.MenuItem;

    function initialize(row as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _row = row;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = UvSettingsMenu.idOf(item);
        if (id >= 0) {
            UvSettings.setSurface(id);
            _row.setSubLabel(UvSettings.surfaceName(id));
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class UvOpennessDelegate extends WatchUi.Menu2InputDelegate {

    private var _row as WatchUi.MenuItem;

    function initialize(row as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _row = row;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = UvSettingsMenu.idOf(item);
        if (id >= 0) {
            UvSettings.setOpenness(id);
            _row.setSubLabel(UvSettings.opennessName(id));
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
