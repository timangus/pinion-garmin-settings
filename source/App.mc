import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;

class App extends Application.AppBase
{
    enum AppState
    {
        STARTING,
        SCANNING,
        CONNECTING,
        CONNECTED,
        STOPPING,
    }

    private var _appState as AppState = STARTING;

    private var _pinionInterface as Pinion.AbstractInterface = new Pinion.TestInterface();
    private var _deviceHandle as Pinion.DeviceHandle? = null;

    private var _mainView as MainView = new MainView(self);

    public function initialize()
    {
        AppBase.initialize();

        _pinionInterface.setDelegate(self);
        updateState();
    }

    public function state() as AppState
    {
        return _appState;
    }

    private function setState(state as AppState) as Void
    {
        if(_appState == state)
        {
            return;
        }

        _appState = state;
        onStateChanged();
    }

    private function onStateChanged() as Void
    {
        _mainView.onAppStateChanged(_appState);
    }

    public function updateState() as Void
    {
        if(_deviceHandle == null)
        {
            setState(SCANNING);
        }
        else if(_appState != CONNECTED)
        {
            setState(CONNECTING);
        }

        switch(_appState)
        {
        case SCANNING:
            _pinionInterface.startScan();
            break;

        case CONNECTING:
            _pinionInterface.stopScan();

            if(_deviceHandle == null)
            {
                System.error("ERROR: in CONNECTING state with no device handle");
            }

            _pinionInterface.connect(_deviceHandle as Pinion.DeviceHandle);
            break;

        default:
        case STARTING:
        case CONNECTED:
        case STOPPING:
            // NO-OP
            break;
        }
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void
    {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void
    {
        setState(STOPPING);
        _pinionInterface.disconnect();
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates]
    {
        return [_mainView];
    }

    public function onScanStateChanged(scanState as Pinion.ScanState) as Void
    {
        System.println("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        System.println("PinionDelegate.onConnected");
        setState(CONNECTED);
    }

    public function onDisconnected() as Void
    {
        if(_appState != STOPPING)
        {
            // Attempt reconnection
            setState(CONNECTING);
        }

        System.println("PinionDelegate.onDisconnected");
    }

    public function onConnectionTimeout() as Void
    {
        System.println("PinionDelegate.onConnectionTimeout");
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void
    {
        _mainView.onFoundDevicesChanged(foundDevices);
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

    public function selectDevice(deviceHandle as Pinion.DeviceHandle) as Void
    {
        _deviceHandle = deviceHandle;
        updateState();
    }

    public function writeParameter(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        _pinionInterface.write(parameter, value);
    }
}

function getApp() as App
{
    return Application.getApp() as App;
}