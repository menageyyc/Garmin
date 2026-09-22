import Toybox.Lang;
import Toybox.WatchUi;

// START refetches in place, DOWN turns the page, MENU opens settings.
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
        _view.refetch();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.nextPage();
        return true;
    }

    function onMenu() as Boolean {
        UvSettingsMenu.show();
        return true;
    }
}
