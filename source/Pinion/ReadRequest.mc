using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class ReadRequest extends Request
    {
        private var _parameter as ParameterType;
        private var _parameterData as Lang.Dictionary = new Lang.Dictionary();
        private var _characteristic as Ble.Characteristic?;

        public function initialize(parameter as ParameterType, characteristic as Ble.Characteristic, delegate as Interface)
        {
            Request.initialize(delegate);

            if(!PARAMETERS.hasKey(parameter))
            {
                throw new UnknownParameterException(parameter);
            }

            _parameter = parameter;
            _parameterData = PARAMETERS[parameter] as Lang.Dictionary;
            _characteristic = characteristic;
        }

        public function execute()
        {
            var payload = new [0]b;
            payload.add(PINION_READ);
            payload.add(_parameterData[:length] as Lang.Number);
            payload.addAll(_parameterData[:address] as Lang.ByteArray);

            (_characteristic as Ble.Characteristic).requestWrite(payload, {:writeType => Ble.WRITE_TYPE_DEFAULT});

            return true;
        }

        public function decodeResponse(bytes as Lang.ByteArray) as Lang.Boolean
        {
            if(bytes[0] == PINION_ERR)
            {
                System.println("ReadRequest response error " + bytesToHex(bytes));
                return false;
            }

            if(bytes[0] != PINION_REPLY)
            {
                System.println("ReadRequest response is not a reply");
                return false;
            }

            var length = bytes[1];
            var address = bytes.slice(2, 5);

            if(!address.equals(_parameterData[:address] as Lang.ByteArray))
            {
                System.println("ReadRequest response is for the wrong address");
                return false;
            }

            var reply = bytes.slice(5, 5 + length);

            var numberFormat = -1;
            switch(length)
            {
            case 1: numberFormat = Lang.NUMBER_FORMAT_UINT8;  break;
            case 2: numberFormat = Lang.NUMBER_FORMAT_UINT16; break;
            case 4: numberFormat = Lang.NUMBER_FORMAT_UINT32; break;

            default:
                System.println("Unexpected parameter length " + length);
                return false;
            }

            var value = reply.decodeNumber(numberFormat, {:endianness => Lang.ENDIAN_LITTLE}) as Lang.Number;
            (_delegate as Interface).onParameterRead(_parameter, value);

            return true;
        }
    }
}