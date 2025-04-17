import Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

class Request
{
    function execute() as Lang.Boolean
    {
        System.println("Request::execute not implemented");
        return false;
    }

    function decodeResponse(bytes as Lang.ByteArray) as Lang.Boolean
    {
        System.println("Request::decodeResponse not implemented");
        return false;
    }

    function onCharacteristicWrite(characteristic as Ble.Characteristic, status as Ble.Status) as Lang.Boolean
    {
        System.println("Request::onCharacteristicWrite not implemented");
        return false;
    }

    function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Lang.Boolean
    {
        System.println("Request::onDescriptorWrite not implemented");
        return false;
    }
}