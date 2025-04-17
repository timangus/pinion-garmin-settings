using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;

class Bluetooth extends Ble.BleDelegate
{
    const PINION_SERVICE                = Ble.longToUuid(0x0000000033d24f94L, 0x9ee49312b3660005L);
    const PINION_CURRENT_GEAR           = Ble.longToUuid(0x0000000133d24f94L, 0x9ee49312b3660005L);
    const PINION_CHAR_REQUEST           = Ble.longToUuid(0x0000000d33d24f94L, 0x9ee49312b3660005L);
    const PINION_CHAR_RESPONSE          = Ble.longToUuid(0x0000000e33d24f94L, 0x9ee49312b3660005L);

    private var connectedDevice as Ble.Device?;
    private var currentGearCharacteristic as Ble.Characteristic?;
    private var requestCharacteristic as Ble.Characteristic?;
    private var responseCharacteristic as Ble.Characteristic?;

    private var requestQueue as Queue?;
    private var currentRequest as Request?;

    function initialize()
    {
        try
        {
            BleDelegate.initialize();
            Ble.setDelegate(self);
            registerProfiles();

            requestQueue = new Queue();
        }
        catch(e)
        {
            System.println("Bluetooth::initialize failed " + e);
        }
    }

    function disconnect()
    {
        if(connectedDevice != null)
        {
            System.println("Disconnecting");
            Ble.unpairDevice(connectedDevice);
            connectedDevice = null;
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
                currentGearCharacteristic = service.getCharacteristic(PINION_CURRENT_GEAR);
                requestCharacteristic = service.getCharacteristic(PINION_CHAR_REQUEST);
                responseCharacteristic = service.getCharacteristic(PINION_CHAR_RESPONSE);

                if(requestCharacteristic != null && responseCharacteristic != null)
                {
                    connectedDevice = device;
                    connected = true;

                    requestQueue.push(new SubscribeRequest(currentGearCharacteristic, NOTIFY));
                    requestQueue.push(new SubscribeRequest(responseCharacteristic, INDICATE));
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
            connectedDevice = null;
        }

        if(!connected)
        {
            requestCharacteristic = null;
            responseCharacteristic = null;

            scan();
        }
    }

    function scan()
    {
        disconnect();
        Ble.setScanState(Ble.SCAN_STATE_SCANNING);
    }

    function scanResultIsPinion(scanResult as Ble.ScanResult)
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

    function registerProfiles()
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

    function read(parameter as PinionParameterType)
    {
        requestQueue.push(new ReadRequest(parameter, requestCharacteristic));
        processQueue();
    }

    function write(parameter as PinionParameterType, value as Lang.Number)
    {
        var hiddenSetting = PINION_PARAMETERS.hasKey(parameter) && PINION_PARAMETERS[parameter].hasKey(:hidden);

        if(hiddenSetting) { requestQueue.push(new WriteRequest(HIDDEN_SETTINGS_ENABLE, 0x56a93c03, requestCharacteristic)); }
        requestQueue.push(new WriteRequest(parameter, value, requestCharacteristic));
        if(hiddenSetting) { requestQueue.push(new WriteRequest(HIDDEN_SETTINGS_ENABLE, 0x0, requestCharacteristic)); }

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

        if(currentRequest == null)
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

        if(currentRequest == null)
        {
            System.println("onDescriptorWrite with no active request");
            disconnect();
            return;
        }

        var success = currentRequest.onDescriptorWrite(descriptor, status);
        currentRequest = null;

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
            if(currentRequest == null)
            {
                System.println("Response characteristic changed with no active request");
                disconnect();
                return;
            }

            var success = currentRequest.decodeResponse(value);
            currentRequest = null;

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
        return currentRequest != null;
    }

    private function processQueue()
    {
        if(connectedDevice == null)
        {
            requestQueue.clear();
            return;
        }

        if(requestQueue.empty())
        {
            return;
        }

        if(busy())
        {
            return;
        }

        currentRequest = requestQueue.pop() as Request;

        var success = currentRequest.execute();
        if(!success)
        {
            System.println("Request execution failed");
            disconnect();
        }
    }
}