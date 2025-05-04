using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;
using Toybox.Timer;

module Pinion
{
    class DeviceHandle
    {
        private var _serialNumber as Lang.Number;
        private var _scanResult as Ble.ScanResult?;
        private var _timeoutTimer as Timer.Timer = new Timer.Timer();
        private var _stale as Lang.Boolean = false;

        public function _markAsStale() as Void
        {
            _stale = true;
        }

        public function _resetScanResult() as Void
        {
            _scanResult = null;
            _timeoutTimer.start(method(:_markAsStale), 20000, false);
        }

        private function timeoutScanResult() as Void
        {
            _timeoutTimer.start(method(:_resetScanResult), 10000, false);
        }

        public function initialize(serialNumber as Lang.Number, scanResult as Ble.ScanResult?)
        {
            _serialNumber = serialNumber;
            updateScanResult(scanResult);
        }

        public function serialNumber() as Lang.Number { return _serialNumber; }

        public function scanResult() as Ble.ScanResult? { return _scanResult; }
        public function hasScanResult() as Lang.Boolean { return _scanResult != null; }

        public function rssi() as Lang.Number
        {
            if(!hasScanResult())
            {
                return -100;
            }

            return (_scanResult as Ble.ScanResult).getRssi();
        }

        public function isStale() as Lang.Boolean { return _stale; }

        public function updateScanResult(scanResult as Ble.ScanResult?) as Void
        {
            _scanResult = scanResult;

            if(scanResult != null)
            {
                timeoutScanResult();
            }
        }
    }
}