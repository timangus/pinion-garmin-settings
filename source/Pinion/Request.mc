using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class Request
    {
        const PINION_ERR            = 0x00;
        const PINION_READ           = 0x01;
        const PINION_REPLY          = 0x02;
        const PINION_WRITE          = 0x03;
        const PINION_ACK            = 0x04;
        const PINION_BLOCK_READ     = 0x05;
        const PINION_BLOCK_REPLY    = 0x06;

        enum ResponseResult
        {
            RESPONSE_FAILURE,
            RESPONSE_SUCCESS,
            RESPONSE_DEFER
        }

        protected var _delegate as Interface?;

        public function initialize(delegate as Interface)
        {
            _delegate = delegate;
        }

        public function execute() as Lang.Boolean
        {
            Debug.log("Request::execute not implemented");
            return false;
        }

        public function decodeResponse(bytes as Lang.ByteArray) as ResponseResult
        {
            Debug.log("Request::decodeResponse not implemented");
            return RESPONSE_FAILURE;
        }

        public function acknowledgeWrite() as Lang.Boolean
        {
            // Return true to discard request
            return false;
        }

        public function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Lang.Boolean
        {
            Debug.log("Request::onDescriptorWrite not implemented");
            return false;
        }

        function bytesToHex(bytes as Lang.ByteArray) as Lang.String
        {
            var str = "[";

            for(var i = 0; i < bytes.size(); i++)
            {
                if(i > 0)
                {
                    str += " ";
                }

                str += bytes[i].format("%02x");
            }

            str += "]";

            return str;
        }
    }
}