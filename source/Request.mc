using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class Request
    {
        protected var _delegate as Bluetooth?;

        public function initialize(delegate as Bluetooth)
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