using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class Delegate
    {
        private var _pinionInterface as Interface?;

        public function pinionInterface() as Interface { return _pinionInterface as Interface; }
        public function setPinionInterface(pinionInterface as Interface) as Void
        {
            _pinionInterface = pinionInterface;
        }

        public function onScanStateChanged(scanState as Pinion.ScanState) as Void {}
        public function onConnected(device as Ble.Device) as Void {}
        public function onDisconnected() as Void {}
        public function onConnectionTimeout() as Void {}
        public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void {}
        public function onCurrentGearChanged(currentGear as Lang.Number) as Void {}
        public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void {}
        public function onParameterWrite(parameter as Pinion.ParameterType) as Void {}
    }
}