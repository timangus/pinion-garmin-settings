using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;

module Pinion
{
    class BlockReadContinueRequest extends Request
    {
        private var _cumulativeRead as Lang.Number;
        private var _totalPayloadSize as Lang.Number;
        private var _expectedSequence as Lang.Number;
        private var _characteristic as Ble.Characteristic?;

        public function initialize(cumulativeRead as Lang.Number, totalPayloadSize as Lang.Number, expectedSequence as Lang.Number,
            characteristic as Ble.Characteristic, delegate as Interface)
        {
            Request.initialize(delegate);

            _cumulativeRead = cumulativeRead;
            _totalPayloadSize = totalPayloadSize;
            _expectedSequence = expectedSequence;
            _characteristic = characteristic;
        }

        public function execute()
        {
            var payload = new [0]b;
            payload.add(PINION_BLOCK_READ);

            if(_cumulativeRead == 0)
            {
                payload.add(0x01);
            }
            else
            {
                payload.add(0x02);
                payload.addAll([0x00, 0x00, 0x00]b);
                payload.add(_expectedSequence);
                _expectedSequence = 1;
            }

            (_characteristic as Ble.Characteristic).requestWrite(payload, {:writeType => Ble.WRITE_TYPE_DEFAULT});

            return true;
        }

        public function decodeResponse(bytes as Lang.ByteArray) as Request.ResponseResult
        {
            if(bytes[0] == PINION_ERR)
            {
                System.println("BlockReadContinueRequest response error " + bytesToHex(bytes));
                return RESPONSE_FAILURE;
            }

            if(bytes[0] != PINION_BLOCK_REPLY)
            {
                System.println("BlockReadContinueRequest response is not a reply");
                return RESPONSE_FAILURE;
            }

            var length = bytes[1];

            if(length == 0xff)
            {
                (_delegate as Interface)._blockReadEnd();
                return RESPONSE_SUCCESS;
            }

            if(length < 2 || length > 8)
            {
                System.println("BlockReadContinueRequest unexpected length " + length);
                return RESPONSE_FAILURE;
            }

            var sequence = bytes[5] & 0x7f;
            var lastPacket = (bytes[5] & 0x80) != 0;

            if(sequence != _expectedSequence)
            {
                System.println("BlockReadContinueRequest sequence mismatch " + sequence + " != " + _expectedSequence);
                return RESPONSE_FAILURE;
            }

            var reply = bytes.slice(6, 6 + (length - 1));

            _cumulativeRead += reply.size();

            (_delegate as Interface).onBlockRead(reply, _cumulativeRead, _totalPayloadSize);

            if(sequence < 64 && !lastPacket)
            {
                _expectedSequence++;
                return RESPONSE_DEFER;
            }

            (_delegate as Interface)._blockReadContinue(_cumulativeRead, _totalPayloadSize, _expectedSequence);

            return RESPONSE_SUCCESS;
        }
    }
}