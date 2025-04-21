using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;
using Toybox.Timer;

class Bluetooth extends Ble.BleDelegate
{
    const PINION_SERVICE                = Ble.longToUuid(0x0000000033d24f94L, 0x9ee49312b3660005L);
    const PINION_CURRENT_GEAR           = Ble.longToUuid(0x0000000133d24f94L, 0x9ee49312b3660005L);
    const PINION_CHAR_REQUEST           = Ble.longToUuid(0x0000000d33d24f94L, 0x9ee49312b3660005L);
    const PINION_CHAR_RESPONSE          = Ble.longToUuid(0x0000000e33d24f94L, 0x9ee49312b3660005L);

    private var _disconnectionTimer as Timer.Timer = new Timer.Timer();
    private var _disconnectWhenIdle as Lang.Boolean = false;

    private var _connectedDevice as Ble.Device?;
    private var _currentGearCharacteristic as Ble.Characteristic?;
    private var _requestCharacteristic as Ble.Characteristic?;
    private var _responseCharacteristic as Ble.Characteristic?;

    private var _requestQueue as RequestQueue = new RequestQueue();
    private var _currentRequest as Request?;

    private var _pinionDelegate as PinionDelegate = new PinionDelegate();

    public function initialize()
    {
        try
        {
            BleDelegate.initialize();
            Ble.setDelegate(self);
            registerProfiles();
        }
        catch(e)
        {
            System.println("Bluetooth::initialize failed " + e);
        }
    }

    public function testForDisconnection() as Void
    {
        if(_connectedDevice == null)
        {
            // Already disconnected
            _disconnectionTimer.stop();
        }
        else if(!(_connectedDevice as Ble.Device).isConnected())
        {
            _disconnectionTimer.stop();
            onDisconnected();
        }

        // Still connected -- we'll keep polling
    }

    public function disconnect() as Void
    {
        if(workPending())
        {
            _disconnectWhenIdle = true;
            return;
        }

        if(_connectedDevice != null)
        {
            Ble.unpairDevice(_connectedDevice as Ble.Device);

            // For some reason, presumably a bug, onConnectedStateChanged is not called when you deliberately
            // unpair a device, meaning there is no way of reacting to a disconnect, so instead we resort to
            // polling the connection state until it drops. Ugh.
            _disconnectionTimer.start(method(:testForDisconnection), 50, true);
        }
    }

    public function onConnectedStateChanged(device as Ble.Device, state as Ble.ConnectionState) as Void
    {
        var connected = false;

        if(state == Ble.CONNECTION_STATE_CONNECTED)
        {
            var service = device.getService(PINION_SERVICE);

            if(service != null)
            {
                _currentGearCharacteristic = service.getCharacteristic(PINION_CURRENT_GEAR);
                _requestCharacteristic = service.getCharacteristic(PINION_CHAR_REQUEST);
                _responseCharacteristic = service.getCharacteristic(PINION_CHAR_RESPONSE);

                if(_currentGearCharacteristic != null && _requestCharacteristic != null && _responseCharacteristic != null)
                {
                    // The scan state should already be off at this point, but I've witnessed a dropped connection spontaneously
                    // reconnect after the device wakes up; in this case scanning may have already restarted so we need to turn it off again
                    Ble.setScanState(Ble.SCAN_STATE_OFF);

                    _connectedDevice = device;
                    connected = true;
                    System.println("Connected");

                    _requestQueue.push(new SubscribeRequest(_currentGearCharacteristic as Ble.Characteristic, NOTIFY, self));
                    _requestQueue.push(new SubscribeRequest(_responseCharacteristic as Ble.Characteristic, INDICATE, self));
                    processQueue();

                    read(HARDWARE_VERSION);
                    read(SERIAL_NUMBER);
                    read(BATTERY_LEVEL);
                    read(CURRENT_GEAR);
                    read(WHEEL_CIRCUMFERENCE);
                    write(WHEEL_CIRCUMFERENCE, 2232);
                    read(WHEEL_CIRCUMFERENCE);
                    write(WHEEL_CIRCUMFERENCE, 2231);
                    read(WHEEL_CIRCUMFERENCE);
                }
            }
        }

        if(!connected)
        {
            onDisconnected();

            System.println("Restarting scanning");
            scan();
        }
    }

    public function scan() as Void
    {
        disconnect();
        Ble.setScanState(Ble.SCAN_STATE_SCANNING);
    }

    private function scanResultIsPinion(scanResult as Ble.ScanResult) as Lang.Boolean
    {
        var uuids = scanResult.getServiceUuids();
        for(var uuid = uuids.next(); uuid != null; uuid = uuids.next())
        {
            if(uuid.equals(PINION_SERVICE))
            {
                return true;
            }
        }

        return false;
    }

    public function onScanResults(scanResults as Ble.Iterator) as Void
    {
        System.println("Scanning");
        for(var result = scanResults.next() as Ble.ScanResult; result != null; result = scanResults.next())
        {
            if(scanResultIsPinion(result))
            {
                System.println("Found");
                Ble.setScanState(Ble.SCAN_STATE_OFF);
                Ble.pairDevice(result);
            }
        }
    }

    private function registerProfiles() as Void
    {
        var pinionProfile =
        {
            :uuid => PINION_SERVICE,
            :characteristics =>
            [
                {:uuid => PINION_CURRENT_GEAR,      :descriptors => [Ble.cccdUuid()]},
                {:uuid => PINION_CHAR_REQUEST,      :descriptors => [Ble.cccdUuid()]},
                {:uuid => PINION_CHAR_RESPONSE,     :descriptors => [Ble.cccdUuid()]}
            ]
        };

        Ble.registerProfile(pinionProfile);
    }

    public function read(parameter as PinionParameterType) as Void
    {
        _requestQueue.push(new ReadRequest(parameter, _requestCharacteristic as Ble.Characteristic, self));
        processQueue();
    }

    public function write(parameter as PinionParameterType, value as Lang.Number) as Void
    {
        var hiddenSetting = PINION_PARAMETERS.hasKey(parameter) && (PINION_PARAMETERS[parameter] as Lang.Dictionary).hasKey(:hidden);

        if(hiddenSetting) { _requestQueue.push(new WriteRequest(HIDDEN_SETTINGS_ENABLE, 0x56a93c03, _requestCharacteristic as Ble.Characteristic, self)); }
        _requestQueue.push(new WriteRequest(parameter, value, _requestCharacteristic as Ble.Characteristic, self));
        if(hiddenSetting) { _requestQueue.push(new WriteRequest(HIDDEN_SETTINGS_ENABLE, 0x0, _requestCharacteristic as Ble.Characteristic, self)); }

        processQueue();
    }

    public function onCharacteristicWrite(characteristic as Ble.Characteristic, status as Ble.Status) as Void
    {
        if(status != Ble.STATUS_SUCCESS)
        {
            System.println("Error writing to characteristic");
            disconnect();
            return;
        }

        if(_currentRequest == null)
        {
            System.println("onCharacteristicWrite with no active request");
            disconnect();
            return;
        }

        processQueue();
    }

    public function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Void
    {
        if(status != Ble.STATUS_SUCCESS)
        {
            System.println("Error writing to descriptor");
            disconnect();
            return;
        }

        if(_currentRequest == null)
        {
            System.println("onDescriptorWrite with no active request");
            disconnect();
            return;
        }

        var success = (_currentRequest as Request).onDescriptorWrite(descriptor, status);
        _currentRequest = null;

        if(!success)
        {
            System.println("Request onDescriptorWrite failed");
            disconnect();
            return;
        }

        processQueue();
    }

    public function onCharacteristicChanged(characteristic as Ble.Characteristic, value as Lang.ByteArray) as Void
    {
        switch(characteristic.getUuid())
        {
        case PINION_CHAR_RESPONSE:
        {
            if(_currentRequest == null)
            {
                System.println("Response characteristic changed with no active request");
                disconnect();
                return;
            }

            var success = (_currentRequest as Request).decodeResponse(value);
            _currentRequest = null;

            if(!success)
            {
                disconnect();
                return;
            }

            processQueue();

            break;
        }

        case PINION_CURRENT_GEAR:
        {
            var currentGear = value[0];
            onCurrentGearChanged(currentGear);
            break;
        }
        }
    }

    private function busy() as Lang.Boolean
    {
        return _currentRequest != null;
    }

    private function workPending() as Lang.Boolean
    {
        return busy() || !_requestQueue.empty();
    }

    private function processQueue() as Void
    {
        if(_connectedDevice == null)
        {
            _requestQueue.clear();
            return;
        }

        if(_requestQueue.empty())
        {
            if(_disconnectWhenIdle)
            {
                _disconnectWhenIdle = false;
                disconnect();
            }

            return;
        }

        if(busy())
        {
            return;
        }

        _currentRequest = _requestQueue.pop() as Request;

        var success = _currentRequest.execute();
        if(!success)
        {
            System.println("Request execution failed");
            disconnect();
        }
    }

    public function setPinionDelegate(pinionDelegate as PinionDelegate) as Void
    {
        _pinionDelegate = pinionDelegate;
    }

    public function onDisconnected() as Void
    {
        _currentGearCharacteristic = null;
        _requestCharacteristic = null;
        _responseCharacteristic = null;
        _connectedDevice = null;
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        _pinionDelegate.onCurrentGearChanged(currentGear);
    }

    public function onParameterRead(parameter as PinionParameterType, value as Lang.Number) as Void
    {
        _pinionDelegate.onParameterRead(parameter, value);
    }

    public function onParameterWrite(parameter as PinionParameterType) as Void
    {
        if(parameter == HIDDEN_SETTINGS_ENABLE)
        {
            // No point in notifying this
            return;
        }

        _pinionDelegate.onParameterWrite(parameter);
    }
}