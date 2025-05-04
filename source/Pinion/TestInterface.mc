using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;
using Toybox.Timer;

module Pinion
{
    class TestInterface
    {
        private var _delegate as Delegate?;
        private var _scanState as ScanState = NOT_SCANNING;

        private var _foundDevices as Lang.Array<DeviceHandle> = new Lang.Array<DeviceHandle>[0];

        private var _connectedDevice as Ble.Device?;
        private var _testParameterData as Lang.Dictionary<ParameterType, Lang.Number> =
        {
            HARDWARE_VERSION =>         33554688,
            FIRMWARE_VERSION =>         17563904,
            BOOTLOADER_VERSION =>       33620736,
            SERIAL_NUMBER =>            2480021234l,
            MOUNTING_ANGLE =>           0,
            REAR_TEETH =>               30,
            FRONT_TEETH =>              30,
            WHEEL_CIRCUMFERENCE =>      2231,
            POWER_SUPPLY =>             1,
            CAN_BUS =>                  0,
            DISPLAY =>                  0,
            SPEED_SENSOR_TYPE =>        1,
            NUMBER_OF_MAGNETS =>        1,
            REVERSE_TRIGGER_MAPPING =>  1,
            CURRENT_GEAR =>             1,
            BATTERY_LEVEL =>            7654,
            AUTO_START_GEAR =>          5,
            PRE_SELECT_CADENCE =>       70,
            START_SELECT =>             0,
            PRE_SELECT =>               0,
            NUMBER_OF_GEARS =>          12,
        } as Lang.Dictionary<ParameterType, Lang.Number>;

        public function connect(deviceHandle as DeviceHandle) as Lang.Boolean
        {
            stopScan();

            _connectedDevice = new Ble.Device();
            onConnected(_connectedDevice);

            return true;
        }

        public function disconnect() as Void
        {
            if(_connectedDevice != null)
            {
                onDisconnected();
            }
        }


        public function startScan() as Void
        {
            if(_scanState == SCANNING)
            {
                return;
            }

            disconnect();
            _scanState = SCANNING;
            onScanStateChanged();

            if(_foundDevices.size() == 0)
            {
                _foundDevices.add(new DeviceHandle(2480021234l as Lang.Number, null));
                _foundDevices.add(new DeviceHandle(2480025678l as Lang.Number, null));
                onFoundDevicesChanged();
            }
        }

        public function stopScan() as Void
        {
            if(_scanState == NOT_SCANNING)
            {
                return;
            }

            disconnect();
            _scanState = NOT_SCANNING;
            onScanStateChanged();
        }

        public function foundDevices() as Lang.Array<DeviceHandle> { return _foundDevices; }

        public function read(parameter as ParameterType) as Void
        {
            onParameterRead(parameter, _testParameterData[parameter] as Lang.Number);
        }

        public function write(parameter as ParameterType, value as Lang.Number) as Void
        {

            _testParameterData[parameter] = value;
            onParameterWrite(parameter);
        }

        public function setDelegate(delegate as Delegate) as Void
        {
            _delegate = delegate;
        }

        public function onScanStateChanged() as Void
        {
            if(_delegate != null)
            {
                (_delegate as Delegate).onScanStateChanged(_scanState);
            }
        }

        public function onFoundDevicesChanged() as Void
        {
            if(_delegate != null)
            {
                (_delegate as Delegate).onFoundDevicesChanged(_foundDevices);
            }
        }

        public function onConnected(device as Ble.Device) as Void
        {
            if(_delegate != null)
            {
                (_delegate as Delegate).onConnected(device);
            }
        }

        public function onDisconnected() as Void
        {
            if(_connectedDevice != null)
            {
                _connectedDevice = null;
                if(_delegate != null)
                {
                    (_delegate as Delegate).onDisconnected();
                }
            }
        }

        public function onParameterRead(parameter as ParameterType, value as Lang.Number) as Void
        {
            if(_delegate != null)
            {
                (_delegate as Delegate).onParameterRead(parameter, value);
            }
        }

        public function onParameterWrite(parameter as ParameterType) as Void
        {
            if(parameter.equals(HIDDEN_SETTINGS_ENABLE))
            {
                // No point in notifying this
                return;
            }

            if(_delegate != null)
            {
                (_delegate as Delegate).onParameterWrite(parameter);
            }
        }
    }
}