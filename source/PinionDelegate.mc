using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class Delegate
    {
        public function onScanStateChanged(scanState as Bluetooth.ScanState) as Void {}
        public function onConnected(device as Ble.Device) as Void {}
        public function onDisconnected() as Void {}
        public function onConnectionTimeout() as Void {}
        public function onFoundDevicesChanged(foundDevices as Lang.Array<PinionDeviceHandle>) as Void {}
        public function onCurrentGearChanged(currentGear as Lang.Number) as Void {}
        public function onParameterRead(parameter as PinionParameterType, value as Lang.Number) as Void {}
        public function onParameterWrite(parameter as PinionParameterType) as Void {}
    }
}