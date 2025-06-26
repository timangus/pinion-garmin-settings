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

        const MAX_RSSI_SAMPLES = 3;
        private var _rssiSamples as Lang.Array<Lang.Number> = new Lang.Array<Lang.Number>[0];
        private var _rssiSampleIndex as Lang.Number = 0;

        public function initialize(serialNumber as Lang.Long, scanResult as Ble.ScanResult?)
        {
            _serialNumber = serialNumber;
            updateScanResult(scanResult);
        }

        public function serialNumber() as Lang.Long { return _serialNumber; }

        public function scanResult() as Ble.ScanResult? { return _scanResult; }
        public function hasScanResult() as Lang.Boolean { return _scanResult != null; }

        private function getSampledRssi(sample as Lang.Number) as Lang.Number
        {
            if(_rssiSamples.size() == MAX_RSSI_SAMPLES)
            {
                _rssiSamples[_rssiSampleIndex] = sample;
                _rssiSampleIndex = (_rssiSampleIndex + 1) % MAX_RSSI_SAMPLES;
            }
            else
            {
                _rssiSamples.add(sample);
            }

            var mean = 0.0;
            for(var i = 0; i < _rssiSamples.size(); i++)
            {
                mean += _rssiSamples[i];
            }

            return (mean / _rssiSamples.size()) as Lang.Number;
        }

        public function rssi() as Lang.Number
        {
            if(!hasScanResult())
            {
                // A null ScanResult occurs when we're using TestInterface, hence the random number
                return getSampledRssi(-100 + (Math.rand() % 50));
            }

            return getSampledRssi((_scanResult as Ble.ScanResult).getRssi());
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