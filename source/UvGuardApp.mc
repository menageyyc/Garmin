import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;

class UvGuardApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // The storage migration runs before anything reads storage, and only ever
    // from the foreground or the glance. A background process cannot be relied
    // on to write storage at all, so it must never be what runs a migration.
    function onStart(state as Dictionary or Null) as Void {
        UvState.migrate();
    }

    function onStop(state as Dictionary or Null) as Void {
    }

    // Fires when the phone-side editor writes a setting. The views read
    // Application.Properties fresh on every draw, so there is nothing to
    // invalidate - a redraw is the whole job.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // (:typecheck(false)) is load-bearing, not laziness. Annotating
    // getGlanceView with (:glance) pulls this whole class into the glance build
    // scope, where UvMainView - correctly - does not exist, because dragging the
    // full app UI into a glance's memory budget would be absurd. Monkey C has no
    // way to mark a single method as foreground-only, so the checker sees
    // getInitialView referencing a symbol missing from one of its scopes and
    // objects. It never runs in the glance scope, so the complaint is spurious.
    (:typecheck(false))
    function getInitialView() {
        var view = new UvMainView();
        return [view, new UvMainDelegate(view)];
    }

    // Returning the glance view is what puts the app in the glance carousel on
    // this generation of hardware. Widgets no longer exist on epix Pro.
    (:glance)
    function getGlanceView() {
        return [new UvGlanceView()];
    }
}
