import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Timer;
using Toybox.BluetoothLowEnergy as Ble;

class App extends Application.AppBase
{
    const RECONNECTION_DELAY = 1000;

    enum AppState
    {
        STARTING,
        SCANNING,
        CONNECTING,
        CONNECTED,
        STOPPING,
    }

    private var _appState as AppState = STARTING;

    private var _pinionInterface as Pinion.AbstractInterface = new Pinion.Interface();
    private var _deviceHandle as Pinion.DeviceHandle? = null;

    private var _mainView as MainView = new MainView(self);

    private var _retryTimer as Timer.Timer = new Timer.Timer();

    public function initialize()
    {
        AppBase.initialize();
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
                Debug.error("In CONNECTING state with no device handle");
            }

            var connectResult = _pinionInterface.connect(_deviceHandle as Pinion.DeviceHandle);
            if(!connectResult)
            {
                // If the connection failed, call updateState again in the near future
                _retryTimer.start(method(:updateState), RECONNECTION_DELAY, false);
            }

            break;

        default:
        case STARTING:
        case CONNECTED:
        case STOPPING:
            // NO-OP
            break;
        }
    }

    function onStart(state as Dictionary?) as Void
    {
        Debug.log("----- Application Start -----");

        restore();
        _pinionInterface.setDelegate(self);
        updateState();
    }

    function onStop(state as Dictionary?) as Void
    {
        exit();

        Debug.log("----- Application Stop -----");
    }

    function getInitialView() as [Views] or [Views, InputDelegates]
    {
        return [_mainView];
    }

    public function onScanStateChanged(scanState as Pinion.ScanState) as Void
    {
        Debug.log("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        Debug.log("PinionDelegate.onConnected");
        setState(CONNECTED);
    }

    public function _attemptReconnection() as Void
    {
        setState(CONNECTING);
        updateState();
    }

    public function onDisconnected() as Void
    {
        Debug.log("PinionDelegate.onDisconnected");

        if(_appState != STOPPING)
        {
            _retryTimer.start(method(:_attemptReconnection), RECONNECTION_DELAY, false);
        }
    }

    public function onConnectionTimeout() as Void
    {
        Debug.log("PinionDelegate.onConnectionTimeout");

        _attemptReconnection();
        _mainView.onConnectionTimeout();
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void
    {
        _mainView.onFoundDevicesChanged(foundDevices);
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        Debug.log("onCurrentGearChanged(" + currentGear + ")");
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        Debug.log("onParameterRead(" + parameter + ", " + value + ")");
        _mainView.setParameter(parameter, value);
    }

    public function onParameterWrite(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        Debug.log("onParameterWrite(" + parameter + ", " + value + ")");
    }

    public function onBlockRead(bytes as Lang.ByteArray, cumulative as Lang.Number, total as Lang.Number) as Void
    {
        Debug.log("onBlockRead(" + bytes + ", " + cumulative + ", " + total + ")");
    }

    public function onActiveErrorsRetrieved(activeErrors as Lang.Array<Lang.Number>) as Void
    {
        Debug.log("onActiveErrorsRetrieved(" + activeErrors + ")");
    }

    public function selectDevice(deviceHandle as Pinion.DeviceHandle) as Void
    {
        _deviceHandle = deviceHandle;
        updateState();
        store();
    }

    public function readParameter(parameter as Pinion.ParameterType) as Void
    {
        _pinionInterface.read(parameter);
    }

    public function writeParameter(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        _pinionInterface.write(parameter, value);
    }

    public function disconnect() as Void
    {
        _pinionInterface.disconnect();
    }

    private function activityKey(key as Application.PropertyKeyType) as Application.PropertyKeyType
    {
        var profileName = Activity.getProfileInfo().name;
        return profileName + "." + key;
    }

    public function store() as Void
    {
        if(_deviceHandle != null)
        {
            var deviceHandle = _deviceHandle as Pinion.DeviceHandle;
            Storage.setValue(activityKey("deviceSerialNumber"), deviceHandle.serialNumber());
            Storage.setValue(activityKey("deviceScanResult"), deviceHandle.scanResult() as Application.PropertyValueType);
        }
    }

    public function restore() as Void
    {
        var deviceSerialNumber = Storage.getValue(activityKey("deviceSerialNumber"));

        if(deviceSerialNumber != null)
        {
            var scanResult = Storage.getValue(activityKey("deviceScanResult"));
            _deviceHandle = new Pinion.DeviceHandle(deviceSerialNumber as Lang.Long, scanResult as Ble.ScanResult);
        }
    }

    public function unstore() as Void
    {
        Storage.deleteValue(activityKey("deviceSerialNumber"));
        Storage.deleteValue(activityKey("deviceScanResult"));
        _deviceHandle = null;
    }

    public function exit() as Void
    {
        setState(STOPPING);
        _pinionInterface.disconnect();
        store();
    }
}

function getApp() as App
{
    return Application.getApp() as App;
}