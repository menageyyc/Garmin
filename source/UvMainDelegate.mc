import Toybox.Lang;
import Toybox.WatchUi;

// v0's test loop is "change something, run it, read three lines". Without a
// retry the only way to fetch again is to restart the app, which is slow and
// reloads persisted state on the way through. START refetches in place.
//
// Deliberately not (:glance) annotated. It belongs to the app scope alongside
// UvMainView, and both are excluded from the glance build together, so there is
// no dangling reference. A glance cannot be tapped anyway - input delegate
// methods are not invoked while a glance view is running.
class UvMainDelegate extends WatchUi.BehaviorDelegate {

    private var _view as UvMainView;

    function initialize(view as UvMainView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.refetch();
        return true;
    }
}
