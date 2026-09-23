import Toybox.Lang;
import Toybox.Application;
import Toybox.Background;
import Toybox.Time;
import Toybox.WatchUi;

// (:background :glance) since v1b. The app class is loaded in all three
// processes - app, glance and background service - because
// getServiceDelegate() and onBackgroundData() live here, and the glance must
// have onBackgroundData() to take delivery. Both scopes are named on the class
// rather than left to a (:glance) on one method, so nothing depends on how the
// compiler extends a method's scope to the rest of its class. The
// annotation, the service and the manifest's Background permission arrived
// in one change, the only order that builds at every step (see CLAUDE.md).
//
// Several methods below reference classes that do not exist in one or more of
// those processes. Each such method carries (:typecheck(false)) for that
// reason alone, and each is only ever called in a process where its classes
// do exist.
(:background :glance)
class UvGuardApp extends Application.AppBase {

    // Every three hours (decision 1, 2026-09-23). CAMS runs twice a day and
    // Open-Meteo's source puts each run's arrival about 8 hours after it -
    // roughly 02:00 and 14:00 in Calgary in summer, unverified live. Three
    // hours catches a new run within three hours whenever it actually lands,
    // for 8 small fetches a day. The build plan's "every 30 min" was 48 fetches
    // a day for data that changes twice.
    private const REFRESH_SECONDS = 10800;

    function initialize() {
        AppBase.initialize();
    }

    // Deliberately empty. onStart() runs in every process the app has,
    // including the background service, where it fires before
    // getServiceDelegate() and there is nothing yet to tell which process
    // this is. So the storage migration lives in the two entry points that
    // are foreground by definition (2026-09-23 review).
    function onStart(state as Dictionary or Null) as Void {
    }

    function onStop(state as Dictionary or Null) as Void {
    }

    // Fires when the phone-side editor writes a setting. The views read
    // Application.Properties fresh on every draw, so there is nothing to
    // invalidate - a redraw is the whole job.
    //
    // Checking off: WatchUi is not a background module, and this class is.
    (:typecheck(false))
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // (:typecheck(false)) is load-bearing, not laziness. UvMainView exists in
    // the app process only, and this class is also compiled into the glance
    // and background scopes, where the checker sees the reference as missing.
    // It never runs there.
    (:typecheck(false))
    function getInitialView() {
        UvState.migrate();
        registerRefresh();
        var view = new UvMainView();
        return [view, new UvMainDelegate(view)];
    }

    // Returning the glance view is what puts the app in the glance carousel on
    // this generation of hardware. Widgets no longer exist on epix Pro.
    //
    // Checking off for the same reason as getInitialView: UvGlanceView is not
    // in the background scope.
    (:typecheck(false))
    function getGlanceView() {
        UvState.migrate();
        return [new UvGlanceView()];
    }

    // An array, not a bare delegate. With a bare one the simulator's manual
    // temporal-event trigger does not call onTemporalEvent at all
    // (established 2026-09-22).
    (:typecheck(false))
    function getServiceDelegate() {
        return [new UvBackground()];
    }

    // Fires in the app or the glance, whichever is running when the service
    // exits (forum-reported for the glance; question 16, not yet seen here).
    // What happens when neither is running is also unverified: the expected
    // behaviour is that the result waits for the next one to start. The
    // receiving process saves it (decision 3, 2026-09-23). Never fires in the
    // background process itself.
    (:typecheck(false))
    function onBackgroundData(data) as Void {
        UvState.migrate();
        UvState.get().receiveBackground(data);
        WatchUi.requestUpdate();
    }

    // The three-hourly wake-up. Only one temporal event can be registered at
    // a time, and registering again restarts the clock, so this leaves an
    // existing three-hour registration alone. Called on every app launch, so
    // the service is registered again after anything that clears it, such as
    // a reinstall.
    function registerRefresh() as Void {
        var registered = Background.getTemporalEventRegisteredTime();
        if (registered instanceof Time.Duration) {
            if (registered.value() == REFRESH_SECONDS) {
                return;
            }
        }
        Background.registerForTemporalEvent(new Time.Duration(REFRESH_SECONDS));
    }
}
