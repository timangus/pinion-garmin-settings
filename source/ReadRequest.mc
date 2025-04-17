import Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

class ReadRequest extends Request
{
    private var _parameterData as Dictionary?;
    private var _characteristic as Ble.Characteristic?;

    function initialize(parameter as PinionParameterType, characteristic as Ble.Characteristic)
    {
        Request.initialize();

        if(!PINION_PARAMETERS.hasKey(parameter))
        {
            throw new UnknownParameterException(parameter);
        }

        _parameterData = PINION_PARAMETERS[parameter];
        _characteristic = characteristic;
    }

    function execute()
    {
        var payload = new [0]b;
        payload.add(PINION_READ);
        payload.add(_parameterData[:length]);
        payload.addAll(_parameterData[:address]);

        _characteristic.requestWrite(payload, {:writeType => Ble.WRITE_TYPE_DEFAULT});

        return true;
    }

    function decodeResponse(bytes as Lang.ByteArray) as Lang.Boolean
    {
        if(bytes[0] != PINION_REPLY)
        {
            System.println("ReadRequest response is not a reply");
            return false;
        }

        var length = bytes[1];
        var address = bytes.slice(2, 5);

        if(!address.equals(_parameterData[:address]))
        {
            System.println("ReadRequest response is for the wrong address");
            return false;
        }

        var reply = bytes.slice(5, 5 + length);

        var numberFormat = -1;
        switch(_parameterData[:length])
        {
        case 1: numberFormat = Lang.NUMBER_FORMAT_UINT8;  break;
        case 2: numberFormat = Lang.NUMBER_FORMAT_UINT16; break;
        case 4: numberFormat = Lang.NUMBER_FORMAT_UINT32; break;

        default:
            System.println("Unexpected parameter length " + _parameterData[:length]);
            return false;
        }

        var value = reply.decodeNumber(numberFormat, {:endianness => Lang.ENDIAN_LITTLE});

        System.println("ReadRequest reply " + reply + " " + value);

        return true;
    }
}