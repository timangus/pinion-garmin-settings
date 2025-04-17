import Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

enum BluetoothSubscribeType
{
    DISABLE     = 0x00,
    NOTIFY      = 0x01,
    INDICATE    = 0x02
}

class SubscribeRequest extends Request
{
    private var _cccd as Ble.Descriptor?;
    private var _type as BluetoothSubscribeType;

    function initialize(characteristic as Ble.Characteristic, type as BluetoothSubscribeType)
    {
        Request.initialize();

        _cccd = characteristic.getDescriptor(Ble.cccdUuid());
        _type = type;
    }

    function execute()
    {
        _cccd.requestWrite([_type as Lang.Number, 0x00]b);
        return true;
    }

    function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Lang.Boolean
    {
        return descriptor.getUuid().equals(_cccd.getUuid());
    }
}