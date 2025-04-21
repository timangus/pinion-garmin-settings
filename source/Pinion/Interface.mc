using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;
using Toybox.Timer;

module Pinion
{
    class DeviceHandle
    {
        private var _serialNumber as Lang.Number;
        private var _scanResult as Ble.ScanResult;

        public function initialize(serialNumber as Lang.Number, scanResult as Ble.ScanResult)
        {
            _serialNumber = serialNumber;
            _scanResult = scanResult;
        }

        public function serialNumber() as Lang.Number { return _serialNumber; }
        public function scanResult() as Ble.ScanResult { return _scanResult; }
    }

    enum ScanState
    {
        NOT_SCANNING,
        SCANNING
    }

    class Interface extends Ble.BleDelegate
    {
        const CONNECTION_TIMEOUT = 5000;

        const PINION_SERVICE_UUID       = Ble.longToUuid(0x0000000033d24f94L, 0x9ee49312b3660005L);
        const PINION_CURRENT_GEAR_UUID  = Ble.longToUuid(0x0000000133d24f94L, 0x9ee49312b3660005L);
        const PINION_CHAR_REQUEST_UUID  = Ble.longToUuid(0x0000000d33d24f94L, 0x9ee49312b3660005L);
        const PINION_CHAR_RESPONSE_UUID = Ble.longToUuid(0x0000000e33d24f94L, 0x9ee49312b3660005L);

        private var _scanState as ScanState = Interface.NOT_SCANNING;
        private var _connectionTimeoutTimer as Timer.Timer = new Timer.Timer();
        private var _disconnectionTimer as Timer.Timer = new Timer.Timer();
        private var _disconnectWhenIdle as Lang.Boolean = false;

        private var _lastScanResult as Ble.ScanResult?;
        private var _foundDevices as Lang.Array<DeviceHandle> = new Lang.Array<DeviceHandle>[0];

        private var _connectedDevice as Ble.Device?;
        private var _currentGearCharacteristic as Ble.Characteristic?;
        private var _requestCharacteristic as Ble.Characteristic?;
        private var _responseCharacteristic as Ble.Characteristic?;

        private var _requestQueue as Pinion.RequestQueue = new Pinion.RequestQueue();
        private var _currentRequest as Pinion.Request?;

        private var _pinionDelegate as Pinion.Delegate = new Pinion.Delegate();

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
                System.println("Interface::initialize failed " + e);
            }
        }

        public function onConnectionTimeout() as Void
        {
            if(_scanState == Interface.SCANNING)
            {
                System.println("Timed out connecting, restarting scanning");
                Ble.setScanState(Ble.SCAN_STATE_SCANNING);
            }
            else
            {
                _pinionDelegate.onConnectionTimeout();
            }
        }

        public function connect(deviceHandle as DeviceHandle) as Lang.Boolean
        {
            stopScan();

            if(_connectedDevice != null)
            {
                System.println("Already connected to a device");
                return false;
            }

            var pairResult = Ble.pairDevice(deviceHandle.scanResult());
            if(pairResult == null)
            {
                return false;
            }

            _connectionTimeoutTimer.start(method(:onConnectionTimeout), CONNECTION_TIMEOUT, false);
            return true;
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
            _connectionTimeoutTimer.stop();

            // The scan state should already be off at this point, but I've witnessed a dropped connection spontaneously
            // reconnect after the device wakes up; in this case scanning may have been restarted so make sure it's off
            Ble.setScanState(Ble.SCAN_STATE_OFF);

            if(state == Ble.CONNECTION_STATE_CONNECTED)
            {
                var service = device.getService(PINION_SERVICE_UUID);

                if(service != null)
                {
                    _requestCharacteristic = service.getCharacteristic(PINION_CHAR_REQUEST_UUID);
                    _responseCharacteristic = service.getCharacteristic(PINION_CHAR_RESPONSE_UUID);

                    if(_requestCharacteristic != null && _responseCharacteristic != null)
                    {
                        _connectedDevice = device;
                        connected = true;

                        _requestQueue.push(new Pinion.SubscribeRequest(_responseCharacteristic as Ble.Characteristic, INDICATE, self));
                        processQueue();

                        if(_scanState == Interface.SCANNING)
                        {
                            // If we're in the scan state, the connection is only being made to retrieve the serial number of a gearbox
                            read(Pinion.SERIAL_NUMBER);
                        }
                        else
                        {
                            // For a long lived connection, subscribe to the current gear characteristic too
                            _currentGearCharacteristic = service.getCharacteristic(PINION_CURRENT_GEAR_UUID);
                            if(_currentGearCharacteristic != null)
                            {
                                _requestQueue.push(new Pinion.SubscribeRequest(_currentGearCharacteristic as Ble.Characteristic, NOTIFY, self));
                                processQueue();
                            }

                            onConnected(device);
                        }
                    }
                }
            }

            if(!connected)
            {
                onDisconnected();
            }
        }

        public function startScan() as Void
        {
            if(_scanState == Interface.SCANNING)
            {
                return;
            }

            disconnect();
            _scanState = Interface.SCANNING;
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
            onScanStateChanged();
        }

        public function stopScan() as Void
        {
            if(_scanState == Interface.NOT_SCANNING)
            {
                return;
            }

            disconnect();
            _scanState = Interface.NOT_SCANNING;
            Ble.setScanState(Ble.SCAN_STATE_OFF);
            onScanStateChanged();
        }

        private function scanResultIsPinion(scanResult as Ble.ScanResult) as Lang.Boolean
        {
            var uuids = scanResult.getServiceUuids();
            for(var uuid = uuids.next(); uuid != null; uuid = uuids.next())
            {
                if(uuid.equals(PINION_SERVICE_UUID))
                {
                    return true;
                }
            }

            return false;
        }

        private function scanResultIsAlreadyKnown(scanResult as Ble.ScanResult) as Lang.Boolean
        {
            for(var i = 0; i < _foundDevices.size(); i++)
            {
                if(scanResult.isSameDevice(_foundDevices[i].scanResult()))
                {
                    return true;
                }
            }

            return false;
        }

        public function onScanResults(scanResults as Ble.Iterator) as Void
        {
            _lastScanResult = null;
            for(var result = scanResults.next() as Ble.ScanResult; result != null; result = scanResults.next())
            {
                if(!scanResultIsAlreadyKnown(result) && scanResultIsPinion(result))
                {
                    _lastScanResult = result;
                    var pairResult = Ble.pairDevice(result);
                    if(pairResult != null)
                    {
                        Ble.setScanState(Ble.SCAN_STATE_OFF);
                        _connectionTimeoutTimer.start(method(:onConnectionTimeout), CONNECTION_TIMEOUT, false);
                        break;
                    }
                }
            }
        }

        private function registerProfiles() as Void
        {
            var pinionProfile =
            {
                :uuid => PINION_SERVICE_UUID,
                :characteristics =>
                [
                    {:uuid => PINION_CURRENT_GEAR_UUID,     :descriptors => [Ble.cccdUuid()]},
                    {:uuid => PINION_CHAR_REQUEST_UUID,     :descriptors => [Ble.cccdUuid()]},
                    {:uuid => PINION_CHAR_RESPONSE_UUID,    :descriptors => [Ble.cccdUuid()]}
                ]
            };

            Ble.registerProfile(pinionProfile);
        }

        public function read(parameter as Pinion.ParameterType) as Void
        {
            _requestQueue.push(new Pinion.ReadRequest(parameter, _requestCharacteristic as Ble.Characteristic, self));
            processQueue();
        }

        public function write(parameter as Pinion.ParameterType, value as Lang.Number) as Void
        {
            var hiddenSetting = Pinion.PARAMETERS.hasKey(parameter) && (Pinion.PARAMETERS[parameter] as Lang.Dictionary).hasKey(:hidden);

            if(hiddenSetting) { _requestQueue.push(new Pinion.WriteRequest(Pinion.HIDDEN_SETTINGS_ENABLE, 0x56a93c03, _requestCharacteristic as Ble.Characteristic, self)); }
            _requestQueue.push(new Pinion.WriteRequest(parameter, value, _requestCharacteristic as Ble.Characteristic, self));
            if(hiddenSetting) { _requestQueue.push(new Pinion.WriteRequest(Pinion.HIDDEN_SETTINGS_ENABLE, 0x0, _requestCharacteristic as Ble.Characteristic, self)); }

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

            var success = (_currentRequest as Pinion.Request).onDescriptorWrite(descriptor, status);
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
            case PINION_CHAR_RESPONSE_UUID:
            {
                if(_currentRequest == null)
                {
                    System.println("Response characteristic changed with no active request");
                    disconnect();
                    return;
                }

                var success = (_currentRequest as Pinion.Request).decodeResponse(value);
                _currentRequest = null;

                if(!success)
                {
                    disconnect();
                    return;
                }

                processQueue();

                break;
            }

            case PINION_CURRENT_GEAR_UUID:
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

            _currentRequest = _requestQueue.pop() as Pinion.Request;

            var success = _currentRequest.execute();
            if(!success)
            {
                System.println("Request execution failed");
                disconnect();
            }
        }

        public function setDelegate(pinionDelegate as Pinion.Delegate) as Void
        {
            _pinionDelegate = pinionDelegate;
        }

        public function onScanStateChanged() as Void
        {
            _pinionDelegate.onScanStateChanged(_scanState);
        }

        public function onFoundDevicesChanged() as Void
        {
            _pinionDelegate.onFoundDevicesChanged(_foundDevices);
        }

        public function onConnected(device as Ble.Device) as Void
        {
            _pinionDelegate.onConnected(device);
        }

        public function onDisconnected() as Void
        {
            _currentGearCharacteristic = null;
            _requestCharacteristic = null;
            _responseCharacteristic = null;
            _connectedDevice = null;

            if(_scanState == Interface.SCANNING)
            {
                // If we've disconnected while scanning it's because we were retrieving a
                // gearbox serial number to add to the found devices array. Now that the
                // disconnection is complete we must notify about the new device.
                onFoundDevicesChanged();
            }
            else
            {
                _pinionDelegate.onDisconnected();
            }
        }

        public function onCurrentGearChanged(currentGear as Lang.Number) as Void
        {
            _pinionDelegate.onCurrentGearChanged(currentGear);
        }

        public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
        {
            if(_scanState == Interface.SCANNING)
            {
                if(parameter != Pinion.SERIAL_NUMBER)
                {
                    System.println("Parameter returned while scanning is not SERIAL_NUMBER: " + parameter);
                    disconnect();
                    return;
                }

                if(_lastScanResult == null)
                {
                    System.println("Last scan result is null");
                    disconnect();
                    return;
                }

                _foundDevices.add(new DeviceHandle(value, _lastScanResult as Ble.ScanResult));
                _lastScanResult = null;

                // Resume scanning
                disconnect();
                Ble.setScanState(Ble.SCAN_STATE_SCANNING);

                return;
            }

            _pinionDelegate.onParameterRead(parameter, value);
        }

        public function onParameterWrite(parameter as Pinion.ParameterType) as Void
        {
            if(parameter == Pinion.HIDDEN_SETTINGS_ENABLE)
            {
                // No point in notifying this
                return;
            }

            _pinionDelegate.onParameterWrite(parameter);
        }
    }
}