using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class BlockReadEndRequest extends Request
    {
        private var _characteristic as Ble.Characteristic?;

        public function initialize(characteristic as Ble.Characteristic, delegate as Interface)
        {
            Request.initialize(delegate);

            _characteristic = characteristic;
        }

        public function execute()
        {
            var payload = [PINION_BLOCK_READ, 0xff]b;
            (_characteristic as Ble.Characteristic).requestWrite(payload, {:writeType => Ble.WRITE_TYPE_DEFAULT});

            return true;
        }

        public function acknowledgeWrite() as Lang.Boolean
        {
            // Signals to get rid of the current request
            return true;
        }
    }
}