using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class Request
    {
        const PINION_ERR    = 0x00;
        const PINION_READ   = 0x01;
        const PINION_REPLY  = 0x02;
        const PINION_WRITE  = 0x03;
        const PINION_ACK    = 0x04;

        protected var _delegate as Interface?;

        public function initialize(delegate as Interface)
        {
            _delegate = delegate;
        }

        public function execute() as Lang.Boolean
        {
            System.println("Request::execute not implemented");
            return false;
        }

        public function decodeResponse(bytes as Lang.ByteArray) as Lang.Boolean
        {
            System.println("Request::decodeResponse not implemented");
            return false;
        }

        public function onCharacteristicWrite(characteristic as Ble.Characteristic, status as Ble.Status) as Lang.Boolean
        {
            System.println("Request::onCharacteristicWrite not implemented");
            return false;
        }

        public function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Lang.Boolean
        {
            System.println("Request::onDescriptorWrite not implemented");
            return false;
        }
    }
}