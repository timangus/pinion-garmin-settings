using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class BlockReadInitRequest extends Request
    {
        private var _parameterData as Lang.Dictionary = new Lang.Dictionary();
        private var _characteristic as Ble.Characteristic?;

        public function initialize(parameter as ParameterType, characteristic as Ble.Characteristic, delegate as Interface)
        {
            Request.initialize(delegate);

            if(!PARAMETERS.hasKey(parameter))
            {
                throw new UnknownParameterException(parameter);
            }

            _parameterData = PARAMETERS[parameter] as Lang.Dictionary;
            _characteristic = characteristic;
        }

        public function execute()
        {
            var payload = new [0]b;
            payload.add(PINION_BLOCK_READ);
            payload.add(0x00);
            payload.addAll(_parameterData[:address] as Lang.ByteArray);

            (_characteristic as Ble.Characteristic).requestWrite(payload, {:writeType => Ble.WRITE_TYPE_DEFAULT});

            return true;
        }

        public function decodeResponse(bytes as Lang.ByteArray) as Request.ResponseResult
        {
            if(bytes[0] == PINION_ERR)
            {
                System.println("BlockReadInitRequest response error " + bytesToHex(bytes));
                return RESPONSE_FAILURE;
            }

            if(bytes[0] != PINION_BLOCK_REPLY)
            {
                System.println("BlockReadInitRequest response is not a reply");
                return RESPONSE_FAILURE;
            }

            if(bytes[1] != 0)
            {
                System.println("BlockReadInitRequest response is not an init");
                return RESPONSE_FAILURE;
            }

            var address = bytes.slice(2, 5);

            if(!address.equals(_parameterData[:address] as Lang.ByteArray))
            {
                System.println("BlockReadInitRequest response is for the wrong address");
                return RESPONSE_FAILURE;
            }

            var reply = bytes.slice(5, 9);
            var value = reply.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {:endianness => Lang.ENDIAN_LITTLE}) as Lang.Number;

            (_delegate as Interface)._blockReadContinue(0, value, 1);

            return RESPONSE_SUCCESS;
        }
    }
}