import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;

class PinionGarminSettingsApp extends Application.AppBase
{
    private var _pinionInterface as Pinion.AbstractInterface;

    public function initialize()
    {
        AppBase.initialize();

        _pinionInterface = new Pinion.Interface();
        _pinionInterface.setDelegate(self);
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

    public function onScanStateChanged(scanState as Pinion.ScanState) as Void
    {
        System.println("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        System.println("PinionDelegate.onConnected");

        _pinionInterface.read(Pinion.HARDWARE_VERSION);
        _pinionInterface.read(Pinion.FIRMWARE_VERSION);
        _pinionInterface.read(Pinion.BOOTLOADER_VERSION);
        _pinionInterface.read(Pinion.SERIAL_NUMBER);

        _pinionInterface.read(Pinion.MOUNTING_ANGLE);
        _pinionInterface.read(Pinion.REAR_TEETH);
        _pinionInterface.read(Pinion.FRONT_TEETH);
        _pinionInterface.read(Pinion.WHEEL_CIRCUMFERENCE);
        _pinionInterface.read(Pinion.POWER_SUPPLY);
        _pinionInterface.read(Pinion.CAN_BUS);
        _pinionInterface.read(Pinion.DISPLAY);
        _pinionInterface.read(Pinion.SPEED_SENSOR_TYPE);
        _pinionInterface.read(Pinion.NUMBER_OF_MAGNETS);

        _pinionInterface.read(Pinion.REVERSE_TRIGGER_MAPPING);

        _pinionInterface.read(Pinion.CURRENT_GEAR);
        _pinionInterface.read(Pinion.BATTERY_LEVEL);

        _pinionInterface.read(Pinion.AUTO_START_GEAR);
        _pinionInterface.read(Pinion.PRE_SELECT_CADENCE);

        _pinionInterface.read(Pinion.START_SELECT);
        _pinionInterface.read(Pinion.PRE_SELECT);

        _pinionInterface.read(Pinion.NUMBER_OF_GEARS);

        _pinionInterface.disconnect();
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

        _pinionInterface.connect(foundDevices[0]);
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

    public function onBlockRead(bytes as Lang.ByteArray, cumulative as Lang.Number, total as Lang.Number) as Void
    {
        System.println("onBlockRead(" + bytes + ", " + cumulative + ", " + total + ")");
    }

    public function onActiveErrorsRetrieved(activeErrors as Lang.Array<Lang.Number>) as Void
    {
        System.println("onActiveErrorsRetrieved(" + activeErrors + ")");
    }
}

function getApp() as PinionGarminSettingsApp
{
    return Application.getApp() as PinionGarminSettingsApp;
}