import Toybox.Lang;
import Toybox.Application;
import Toybox.WatchUi;

class UvGuardApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
    }

    function onStop(state as Dictionary or Null) as Void {
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
        return [new UvMainView()];
    }

    // Returning the glance view is what puts the app in the glance carousel on
    // this generation of hardware. Widgets no longer exist on epix Pro.
    (:glance)
    function getGlanceView() {
        return [new UvGlanceView()];
    }
}
