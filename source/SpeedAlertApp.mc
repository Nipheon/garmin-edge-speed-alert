using Toybox.Application;
using Toybox.WatchUi;

class SpeedAlertApp extends Application.AppBase {

    private var _field;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        _field = new SpeedAlertField();
        return [_field];
    }

    function onSettingsChanged() {
        if (_field != null) {
            _field.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
