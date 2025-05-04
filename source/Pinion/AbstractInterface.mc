
using Toybox.Lang;

module Pinion
{
    typedef AbstractInterface as interface
    {
        function startScan() as Void;
        function stopScan() as Void;
        function foundDevices() as Lang.Array<DeviceHandle>;

        function connect(deviceHandle as DeviceHandle) as Lang.Boolean;
        function disconnect() as Void;

        function read(parameter as ParameterType) as Void;
        function write(parameter as ParameterType, value as Lang.Number) as Void;

        function setDelegate(delegate as Delegate) as Void;
    };
}
