using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class WriteRequest extends Request
    {
        private var _value as Lang.Number = 0;

        private var _parameter as ParameterType;
        private var _parameterData as Lang.Dictionary = new Lang.Dictionary();
        private var _characteristic as Ble.Characteristic?;

        public function initialize(parameter as ParameterType, value as Lang.Number, characteristic as Ble.Characteristic, delegate as Interface)
        {
            Request.initialize(delegate);

            if(!PARAMETERS.hasKey(parameter))
            {
                throw new UnknownParameterException(parameter);
            }

            _parameter = parameter;
            _parameterData = PARAMETERS[parameter] as Lang.Dictionary;

            if(!_parameterData.hasKey(:minmax) && !_parameterData.hasKey(:values))
            {
                throw new ParameterNotWritableException(parameter);
            }

            if(_parameterData.hasKey(:values))
            {
                var values = _parameterData[:values] as Lang.Array;
                var found = false;

                for(var i = 0; i < values.size(); i++)
                {
                    if(values[i] == value)
                    {
                        found = true;
                        break;
                    }
                }

                if(!found)
                {
                    System.println("WriteRequest created with invalid value " + value + ", replaced with " + values[0] as Lang.Number);
                    value = values[0] as Lang.Number;
                }
            }
            else if(_parameterData.hasKey(:minmax))
            {
                var minmax = _parameterData[:minmax] as Lang.Array;
                var min = minmax[0] as Lang.Number;
                var max = minmax[1] as Lang.Number;

                if(value < min)
                {
                    System.println("WriteRequest value " + value + " clamped to minimum " + min);
                    value = min;
                }
                else if(value > max)
                {
                    System.println("WriteRequest value " + value + " clamped to maximum " + max);
                    value = max;
                }
            }

            _value = value;
            _characteristic = characteristic;
        }

        public function execute()
        {
            var length = _parameterData[:length] as Lang.Number;
            var payload = new [0]b;
            payload.add(PINION_WRITE);
            payload.add(length);
            payload.addAll(_parameterData[:address] as Lang.ByteArray);

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

            var valueArray = new [length]b;
            valueArray.encodeNumber(_value, numberFormat, {:endianness => Lang.ENDIAN_LITTLE});
            payload.addAll(valueArray);

            (_characteristic as Ble.Characteristic).requestWrite(payload, {:writeType => Ble.WRITE_TYPE_DEFAULT});

            return true;
        }

        public function decodeResponse(bytes as Lang.ByteArray) as Request.ResponseResult
        {
            if(bytes[0] == PINION_ERR)
            {
                System.println("WriteRequest response error " + bytesToHex(bytes));
                return RESPONSE_FAILURE;
            }

            if(bytes[0] != PINION_ACK)
            {
                System.println("WriteRequest response is not a acknowledgement");
                return RESPONSE_FAILURE;
            }

            if(bytes[1] != 0xFF)
            {
                System.println("WriteRequest response is malformed");
                return RESPONSE_FAILURE;
            }

            var address = bytes.slice(2, 5);

            if(!address.equals(_parameterData[:address] as Lang.ByteArray))
            {
                System.println("WriteRequest response is for the wrong address");
                return RESPONSE_FAILURE;
            }

            (_delegate as Interface).onParameterWrite(_parameter);

            return RESPONSE_SUCCESS;
        }
    }
}