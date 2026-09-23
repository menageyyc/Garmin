import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;

class UvGuardApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Deliberately empty. The storage migration used to run here, but
    // onStart() runs in every process the app has - including the background
    // service v1b adds, where it fires before getServiceDelegate() and there
    // is nothing yet to tell which process this is. A background process
    // cannot be relied on to write storage, so the migration moved to the two
    // entry points that are foreground by definition (2026-09-23 review).
    function onStart(state as Dictionary or Null) as Void {
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
        UvState.migrate();
        var view = new UvMainView();
        return [view, new UvMainDelegate(view)];
    }

    // Returning the glance view is what puts the app in the glance carousel on
    // this generation of hardware. Widgets no longer exist on epix Pro.
    (:glance)
    function getGlanceView() {
        UvState.migrate();
        return [new UvGlanceView()];
    }
}
