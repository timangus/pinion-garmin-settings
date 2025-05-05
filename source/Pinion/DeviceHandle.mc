using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Lang;
using Toybox.Time;

module Pinion
{
    class DeviceHandle
    {
        const TIMEOUT_SECONDS = 20;

        private var _serialNumber as Lang.Long;
        private var _scanResult as Ble.ScanResult?;
        private var _lastScannedTime as Time.Moment = Time.now();

        public function initialize(serialNumber as Lang.Long, scanResult as Ble.ScanResult?)
        {
            _serialNumber = serialNumber;
            updateScanResult(scanResult);
        }

        public function serialNumber() as Lang.Long { return _serialNumber; }

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

        public function isStale() as Lang.Boolean
        {
            var timeSinceUpdate = Time.now().compare(_lastScannedTime);
            return timeSinceUpdate > TIMEOUT_SECONDS;
        }

        public function updateScanResult(scanResult as Ble.ScanResult?) as Void
        {
            _scanResult = scanResult;

            if(scanResult != null)
            {
                _lastScannedTime = Time.now();
            }
        }
    }
}