import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PinionGarminSettingsApp extends Application.AppBase
{
    private var bluetooth as Bluetooth;

    function initialize()
    {
        AppBase.initialize();

        bluetooth = new Bluetooth();
        bluetooth.scan();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void
    {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void
    {
        bluetooth.disconnect();
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