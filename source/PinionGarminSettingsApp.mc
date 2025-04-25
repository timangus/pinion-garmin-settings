import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;

class PinionGarminTestDelegate extends Pinion.Delegate
{
    public function initialize()
    {
        Delegate.initialize();
    }

    public function onScanStateChanged(scanState as Pinion.ScanState) as Void
    {
        System.println("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        System.println("PinionDelegate.onConnected");
        pinionInterface().read(Pinion.SERIAL_NUMBER);
        pinionInterface().read(Pinion.HARDWARE_VERSION);
        pinionInterface().read(Pinion.CURRENT_GEAR);
        pinionInterface().read(Pinion.BATTERY_LEVEL);
        pinionInterface().read(Pinion.AUTO_START_GEAR);
        pinionInterface().read(Pinion.PRE_SELECT);
        pinionInterface().read(Pinion.WHEEL_CIRCUMFERENCE);
        pinionInterface().disconnect();
    }

    public function onDisconnected() as Void
    {
        System.println("PinionDelegate.onDisconnected");
    }

    public function onConnectionTimeout() as Void
    {
        System.println("PinionDelegate.onConnectionTimeout");
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void
    {
        for(var i = 0; i < foundDevices.size(); i++)
        {
            System.println("onFoundDevicesChanged(" + i + ": " + foundDevices[i].serialNumber() + ")");
        }

        pinionInterface().connect(foundDevices[0]);
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        System.println("onCurrentGearChanged(" + currentGear + ")");
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        System.println("onParameterRead(" + parameter + ", " + value + ")");
    }

    public function onParameterWrite(parameter as Pinion.ParameterType) as Void
    {
        System.println("onParameterWrite(" + parameter + ")");
    }
}

class PinionGarminSettingsApp extends Application.AppBase
{
    private var _pinionInterface as Pinion.Interface;
    private var _delegate as PinionGarminTestDelegate = new PinionGarminTestDelegate();

    public function initialize()
    {
        AppBase.initialize();

        _pinionInterface = new Pinion.Interface();
        _pinionInterface.setDelegate(_delegate);
        _pinionInterface.startScan();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void
    {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void
    {
        _pinionInterface.disconnect();
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