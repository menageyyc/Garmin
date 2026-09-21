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
