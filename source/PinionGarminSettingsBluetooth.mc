using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;

class Bluetooth extends Ble.BleDelegate
{
    const PINION_SERVICE                = Ble.longToUuid(0x0000000033d24f94L, 0x9ee49312b3660005L);
    const PINION_CURRENT_GEAR           = Ble.longToUuid(0x0000000133d24f94L, 0x9ee49312b3660005L);
    const PINION_CHAR_REQUEST           = Ble.longToUuid(0x0000000d33d24f94L, 0x9ee49312b3660005L);
    const PINION_CHAR_RESPONSE          = Ble.longToUuid(0x0000000e33d24f94L, 0x9ee49312b3660005L);

    private var _connectedDevice as Ble.Device?;
    private var _currentGearCharacteristic as Ble.Characteristic?;
    private var _requestCharacteristic as Ble.Characteristic?;
    private var _responseCharacteristic as Ble.Characteristic?;

    private var _requestQueue as RequestQueue = new RequestQueue();
    private var _currentRequest as Request?;

    function initialize()
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

    function disconnect() as Void
    {
        if(_connectedDevice != null)
        {
            System.println("Disconnecting");
            Ble.unpairDevice(_connectedDevice as Ble.Device);
            _connectedDevice = null;
        }
    }

    function onConnectedStateChanged(device as Ble.Device, state as Ble.ConnectionState)
    {
        var connected = false;

        if(state == Ble.CONNECTION_STATE_CONNECTED)
        {
            System.println("Connected");
            var service = device.getService(PINION_SERVICE);

            if(service != null)
            {
                _currentGearCharacteristic = service.getCharacteristic(PINION_CURRENT_GEAR);
                _requestCharacteristic = service.getCharacteristic(PINION_CHAR_REQUEST);
                _responseCharacteristic = service.getCharacteristic(PINION_CHAR_RESPONSE);

                if(_requestCharacteristic != null && _responseCharacteristic != null)
                {
                    _connectedDevice = device;
                    connected = true;

                    _requestQueue.push(new SubscribeRequest(_currentGearCharacteristic as Ble.Characteristic, NOTIFY));
                    _requestQueue.push(new SubscribeRequest(_responseCharacteristic as Ble.Characteristic, INDICATE));
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
        else
        {
            System.println("Disconnected");
            _connectedDevice = null;
        }

        if(!connected)
        {
            _requestCharacteristic = null;
            _responseCharacteristic = null;

            scan();
        }
    }

    function scan() as Void
    {
        disconnect();
        Ble.setScanState(Ble.SCAN_STATE_SCANNING);
    }

    function scanResultIsPinion(scanResult as Ble.ScanResult) as Lang.Boolean
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

    function onScanResults(scanResults as Ble.Iterator)
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

    function registerProfiles() as Void
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

    function read(parameter as PinionParameterType) as Void
    {
        _requestQueue.push(new ReadRequest(parameter, _requestCharacteristic as Ble.Characteristic));
        processQueue();
    }

    function write(parameter as PinionParameterType, value as Lang.Number) as Void
    {
        var hiddenSetting = PINION_PARAMETERS.hasKey(parameter) && (PINION_PARAMETERS[parameter] as Lang.Dictionary).hasKey(:hidden);

        if(hiddenSetting) { _requestQueue.push(new WriteRequest(HIDDEN_SETTINGS_ENABLE, 0x56a93c03, _requestCharacteristic as Ble.Characteristic)); }
        _requestQueue.push(new WriteRequest(parameter, value, _requestCharacteristic as Ble.Characteristic));
        if(hiddenSetting) { _requestQueue.push(new WriteRequest(HIDDEN_SETTINGS_ENABLE, 0x0, _requestCharacteristic as Ble.Characteristic)); }

        processQueue();
    }

    function onCharacteristicWrite(characteristic as Ble.Characteristic, status as Ble.Status)
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

    function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status)
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

    function onCharacteristicChanged(characteristic as Ble.Characteristic, value as Lang.ByteArray)
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
            System.println("Current gear changed: " + currentGear);
            break;
        }
        }
    }

    function busy() as Lang.Boolean
    {
        return _currentRequest != null;
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
}