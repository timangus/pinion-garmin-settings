using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.BluetoothLowEnergy as Ble;

class MainViewInputDelegate extends WatchUi.BehaviorDelegate
{
    private var _app as App;

    public function initialize(app as App)
    {
        WatchUi.BehaviorDelegate.initialize();
        _app = app;
    }

    public function onSelect() as Lang.Boolean
    {
        _app.onSelect();
        return true;
    }
}

var IS_SIMULATOR as Lang.Boolean = false;

class App extends Application.AppBase
{
    const RECONNECTION_DELAY = 1000;

    enum State
    {
        STARTING,
        SCANNING,
        CONNECTING,
        CONNECTED,
        STOPPING,
    }

    private var _state as State = STARTING;

    private var _pinionInterface as Pinion.AbstractInterface?;

    private var _deviceHandle as Pinion.DeviceHandle? = null;

    private var _mainView as MainView = new MainView(self);
    private var _mainViewInputDelegate as MainViewInputDelegate = new MainViewInputDelegate(self);

    private var _retryTimer as Timer.Timer = new Timer.Timer();
    private var _numTimeouts as Lang.Number = 0;

    private function pinionInterface() as Pinion.AbstractInterface
    {
        Debug.assert(_pinionInterface != null, "_pinionInterface not set");
        return _pinionInterface as Pinion.AbstractInterface;
    }

    public function initialize()
    {
        AppBase.initialize();
    }

    public function state() as State
    {
        return _state;
    }

    private function setState(state as State) as Void
    {
        if(_state == state)
        {
            return;
        }

        _state = state;
        onStateChanged();
    }

    private function onStateChanged() as Void
    {
        switch(_state)
        {
        case STARTING:      Debug.log("onStateChanged STARTING");   break;
        case SCANNING:      Debug.log("onStateChanged SCANNING");   break;
        case CONNECTING:    Debug.log("onStateChanged CONNECTING"); break;
        case CONNECTED:     Debug.log("onStateChanged CONNECTED");  break;
        case STOPPING:      Debug.log("onStateChanged STOPPING");   break;
        }

        _mainView.onAppStateChanged(_state);
    }

    public function updateState() as Void
    {
        if(_deviceHandle == null)
        {
            setState(SCANNING);
        }
        else if(_state != CONNECTED)
        {
            setState(CONNECTING);
        }

        switch(_state)
        {
        case SCANNING:
            pinionInterface().startScan();
            break;

        case CONNECTING:
            pinionInterface().stopScan();

            if(_deviceHandle == null)
            {
                Debug.error("In CONNECTING state with no device handle");
            }

            _mainView.onConnecting(_deviceHandle as Pinion.DeviceHandle);
            var connectResult = pinionInterface().connect(_deviceHandle as Pinion.DeviceHandle);
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

    function onStart(state as Lang.Dictionary?) as Void
    {
        Debug.log("----- Application Start -----");

        restore();
        _pinionInterface = IS_SIMULATOR ? new Pinion.TestInterface() : new Pinion.Interface();

        if(_pinionInterface instanceof Pinion.Interface && _deviceHandle != null && _deviceHandle.scanResult() == null)
        {
            // On a real device, the scanResult should never be null, forget it
            unstore();
        }

        pinionInterface().setDelegate(self);
        updateState();
    }

    function onStop(state as Lang.Dictionary?) as Void
    {
        exit();

        Debug.log("----- Application Stop -----");
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates]
    {
        return [_mainView, _mainViewInputDelegate];
    }

    public function onScanStateChanged(scanState as Pinion.ScanState) as Void
    {
        Debug.log("onScanStateChanged(" + scanState + ")");
    }

    public function onConnected(device as Ble.Device) as Void
    {
        Debug.log("PinionDelegate.onConnected");
        _numTimeouts = 0;
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

        if(_state != STOPPING)
        {
            _retryTimer.start(method(:_attemptReconnection), RECONNECTION_DELAY, false);
        }
    }

    public function onConnectionTimeout() as Void
    {
        Debug.log("PinionDelegate.onConnectionTimeout");
        _numTimeouts++;

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
        _mainView.onCurrentGearChanged(currentGear);
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        Debug.log("onParameterRead(" + parameter + ", " + value + ")");
        _mainView.onParameterRead(parameter, value);
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
        _numTimeouts = 0;
        updateState();
        store();
    }

    public function readParameter(parameter as Pinion.ParameterType) as Void
    {
        pinionInterface().read(parameter);
    }

    public function writeParameter(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        pinionInterface().write(parameter, value);
    }

    public function onSelect() as Void
    {
        if(_numTimeouts > 0)
        {
            unstore();
            disconnect();
            updateState();
        }
    }

    public function disconnect() as Void
    {
        pinionInterface().disconnect();
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
        var isSimulatorNullable = Storage.getValue(activityKey("isSimulator"));
        IS_SIMULATOR = isSimulatorNullable != null ? isSimulatorNullable as Lang.Boolean : false;
        Storage.setValue(activityKey("isSimulator"), IS_SIMULATOR);

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
        pinionInterface().disconnect();
        store();
    }
}

function getApp() as App
{
    return Application.getApp() as App;
}