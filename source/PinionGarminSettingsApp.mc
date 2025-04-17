import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PinionGarminSettingsApp extends Application.AppBase
{
    private var _bluetooth as Bluetooth;

    public function initialize()
    {
        AppBase.initialize();

        _bluetooth = new Bluetooth();
        _bluetooth.scan();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void
    {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void
    {
        _bluetooth.disconnect();
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates]
    {
        return [new PinionGarminSettingsView()];
    }

}

function getApp() as PinionGarminSettingsApp
{
    return Application.getApp() as PinionGarminSettingsApp;
}