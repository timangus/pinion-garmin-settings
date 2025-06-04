using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    typedef Delegate as interface
    {
        function onScanStateChanged(scanState as ScanState) as Void;
        function onConnected(device as Ble.Device) as Void;
        function onDisconnected() as Void;
        function onConnectionTimeout() as Void;
        function onFoundDevicesChanged(foundDevices as Lang.Array<DeviceHandle>) as Void;
        function onCurrentGearChanged(currentGear as Lang.Number) as Void;
        function onParameterRead(parameter as ParameterType, value as Lang.Number) as Void;
        function onParameterWrite(parameter as ParameterType, value as Lang.Number) as Void;
        function onBlockRead(bytes as Lang.ByteArray, cumulative as Lang.Number, total as Lang.Number) as Void;
        function onActiveErrorsRetrieved(activeErrors as Lang.Array<Lang.Number>) as Void;
    };
}