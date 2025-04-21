import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;

class PinionGarminDelegate extends Pinion.Delegate
{
    private var _pinionGarminSettingsApp as PinionGarminSettingsApp?;

    public function initialize(pinionGarminSettingsApp as PinionGarminSettingsApp)
    {
        Pinion.Delegate.initialize();
        _pinionGarminSettingsApp = pinionGarminSettingsApp;
    }

    public function onScanStateChanged(scanState as Bluetooth.ScanState) as Void
    {
        System.println("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        System.println("PinionDelegate.onConnected");
        (_pinionGarminSettingsApp as PinionGarminSettingsApp).doStuff();
    }

    public function onDisconnected() as Void
    {
        System.println("PinionDelegate.onDisconnected");
    }

    public function onConnectionTimeout() as Void
    {
        System.println("PinionDelegate.onConnectionTimeout");
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<PinionDeviceHandle>) as Void
    {
        for(var i = 0; i < foundDevices.size(); i++)
        {
            System.println("onFoundDevicesChanged(" + i + ": " + foundDevices[i].serialNumber() + ")");
        }
        (_pinionGarminSettingsApp as PinionGarminSettingsApp).connect(foundDevices[0]);
    }

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
    private var _delegate as PinionGarminDelegate = new PinionGarminDelegate(self);

    public function initialize()
    {
        AppBase.initialize();

        _bluetooth = new Bluetooth();
        _bluetooth.setPinionDelegate(_delegate);
        _bluetooth.startScan();
    }

    function connect(pinionDeviceHandle as PinionDeviceHandle) as Void
    {
        _bluetooth.connect(pinionDeviceHandle);
    }

    function doStuff() as Void
    {
        _bluetooth.read(SERIAL_NUMBER);
        _bluetooth.read(HARDWARE_VERSION);
        _bluetooth.read(CURRENT_GEAR);
        _bluetooth.read(BATTERY_LEVEL);
        _bluetooth.read(AUTO_START_GEAR);
        _bluetooth.read(PRE_SELECT);
        _bluetooth.read(WHEEL_CIRCUMFERENCE);
        _bluetooth.disconnect();
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