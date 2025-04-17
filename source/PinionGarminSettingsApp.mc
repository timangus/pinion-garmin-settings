import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PinionGarminDelegate extends PinionDelegate
{
    public function initialize() { PinionDelegate.initialize(); }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        System.println("onCurrentGearChanged(" + currentGear + ")");
    }

    public function onParameterRead(parameter as PinionParameterType, value as Lang.Number) as Void
    {
        System.println("onParameterRead(" + parameter + ", " + value + ")");
    }

    public function onParameterWrite(parameter as PinionParameterType) as Void
    {
        System.println("onParameterWrite(" + parameter + ")");
    }
}

class PinionGarminSettingsApp extends Application.AppBase
{
    private var _bluetooth as Bluetooth;
    private var _delegate as PinionGarminDelegate = new PinionGarminDelegate();

    public function initialize()
    {
        AppBase.initialize();

        _bluetooth = new Bluetooth();
        _bluetooth.setPinionDelegate(_delegate);
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