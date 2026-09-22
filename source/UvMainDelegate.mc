import Toybox.Lang;
import Toybox.WatchUi;

// START acts on the current page, DOWN and UP turn pages, MENU opens settings.
//
// MENU is kept, but it is not the only way in. On this hardware MENU is a long
// press of UP, and Garmin's forums carry reports of onMenu() never firing on
// some fenix and epix models. The settings page reached by DOWN is the route
// that cannot fail.
//
// Deliberately not (:glance) annotated. It belongs to the app scope alongside
// UvMainView, and both are excluded from the glance build together, so there
// is no dangling reference. A glance cannot be tapped anyway - input delegate
// methods are not invoked while a glance view is running.
class UvMainDelegate extends WatchUi.BehaviorDelegate {

    private var _view as UvMainView;

    function initialize(view as UvMainView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.onSelectPressed();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.prevPage();
        return true;
    }

    // Handled means "stay in the app". Unhandled - false - lets the framework
    // do what BACK normally does, which is leave.
    function onBack() as Boolean {
        return _view.backPressed();
    }

    function onMenu() as Boolean {
        UvSettingsMenu.show();
        return true;
    }
}
