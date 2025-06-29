using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.Time;

class ScanMenuDelegate extends WatchUi.Menu2InputDelegate
{
    private var _mainView as MainView;

    public function initialize(mainView as MainView)
    {
        WatchUi.Menu2InputDelegate.initialize();
        _mainView = mainView;
    }

    function onSelect(item as WatchUi.MenuItem) as Void
    {
        _mainView.selectDevice(item.getId() as Lang.Long);
    }

    function onBack() as Void
    {
        _mainView.exit();
    }
}

class MainView extends WatchUi.View
{
    const MAX_CONSECUTIVE_TIMEOUTS = 3;

    private var _app as App;

    private var _scanMenu as WatchUi.Menu2 = new WatchUi.Menu2({:title => "Smart.Shift Devices"});
    private var _scanMenuDelegate as ScanMenuDelegate = new ScanMenuDelegate(self);
    private var _scanMenuVisible as Lang.Boolean = false;
    private var _deviceHandlesInScanMenu as Lang.Array<Pinion.DeviceHandle> = new Lang.Array<Pinion.DeviceHandle>[0];
    private var _deviceSerialNumber as Lang.Long = 0l;

    private var _settingsView as SettingsView = new SettingsView();

    private var _lastUpdateTime as Time.Moment = Time.now();

    private var _numTimeouts as Lang.Number = 0;

    public function initialize(app as App)
    {
        View.initialize();

        _app = app;
        _settingsView.setApp(app);
    }

    function onUpdate(dc as Toybox.Graphics.Dc) as Void
    {
        switch(_app.state())
        {
        case App.SCANNING:
            setLayout(Rez.Layouts.ScanningLayout(dc));
            break;

        case App.CONNECTING:
        case App.CONNECTED:
            if(!_settingsView.showing() || _settingsView.syncing())
            {
                setLayout(Rez.Layouts.ConnectingLayout(dc));
            }

            var connectingSerialNumber = findDrawableById("id_connecting_serial_number") as WatchUi.Text;
            connectingSerialNumber.setText("Serial No. " + _deviceSerialNumber.toString());

            var connectingDrawable = findDrawableById("id_connecting_drawable") as WatchUi.Drawable;
            var triggerDrawable = findDrawableById("id_trigger_drawable") as WatchUi.Drawable;

            connectingDrawable.setVisible(_numTimeouts == 0);
            triggerDrawable.setVisible(_numTimeouts > 0);

            var connectionStatusText = findDrawableById("id_connection_status") as WatchUi.Text;
            if(_numTimeouts > MAX_CONSECUTIVE_TIMEOUTS)
            {
                connectionStatusText.setText("Scan");
            }
            else if(_numTimeouts > 0)
            {
                connectionStatusText.setText("Time Out");
            }
            else if(_settingsView.showing())
            {
                connectionStatusText.setText("Syncing...");
            }
            else
            {
                connectionStatusText.setText("Connecting...");
            }

            break;

        case App.STOPPING:
            setLayout(Rez.Layouts.StoppingLayout(dc));
            break;
        }

        View.onUpdate(dc);
    }

    public function selectDevice(serialNumber as Lang.Long) as Void
    {
        for(var i = 0; i < _deviceHandlesInScanMenu.size(); i++)
        {
            var deviceHandle = _deviceHandlesInScanMenu[i];

            if(serialNumber == deviceHandle.serialNumber())
            {
                _app.selectDevice(deviceHandle);
                if(_scanMenuVisible)
                {
                    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                    _scanMenuVisible = false;
                }

                return;
            }
        }

        Debug.log("Can't find handle for serial " + serialNumber);
    }

    public function exit() as Void
    {
        _app.exit();
    }

    private function forceUpdateHack() as Void
    {
        if(_scanMenuVisible)
        {
            // Calling WatchUi.requestUpdate() on the simulator does exactly what you'd expect, scheduling
            // a UI update with Menu2. On a real device however, it doesn't seem to work; apparently the
            // only thing that evokes an update is physically pressing a button, which is not ideal when
            // you just want to change some text. Hackily switching view to the current view seems to work
            // around the problem though, the only slight downside being that sometimes you get a partial
            // redraw for a few frames, but this will only manifest if you have multiple gearboxes in
            // pairing mode; a scenario unlikely enough that I can live with this. It's not like there's an
            // option anyway.
            WatchUi.switchToView(_scanMenu, _scanMenuDelegate, WatchUi.SLIDE_IMMEDIATE);
        }
    }

    public function onConnectionTimeout() as Void
    {
        _numTimeouts++;
        WatchUi.requestUpdate();
    }

    const MIN_RSSI = -100.0;
    const MAX_RSSI = -50.0;

    private function rssiToQualityPercent(rssi as Lang.Number) as Lang.String
    {
        var p = ((rssi - MIN_RSSI) / (MAX_RSSI - MIN_RSSI)) * 100.0;
        p = p > 100.0 ? 100.0 : p < 0.0 ? 0.0 : p;
        p = Math.round(p);
        return Lang.format("Connection $1$%", [p.format("%d")]);
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void
    {
        if(_app.state() == App.STOPPING)
        {
            return;
        }

        var j = _deviceHandlesInScanMenu.size() - 1;
        while(j >= 0)
        {
            var deviceHandle = _deviceHandlesInScanMenu[j];
            var stillExists = false;

            for(var k = 0; k < foundDevices.size(); k++)
            {
                if(foundDevices[k].serialNumber() == deviceHandle.serialNumber())
                {
                    stillExists = true;
                    break;
                }
            }

            if(!stillExists)
            {
                var menuItemIndex = _scanMenu.findItemById(deviceHandle.serialNumber());
                _scanMenu.deleteItem(menuItemIndex);
                _deviceHandlesInScanMenu.remove(deviceHandle);
                forceUpdateHack();
            }

            j--;
        }

        for(var i = 0; i < foundDevices.size(); i++)
        {
            var foundDevice = foundDevices[i];
            var index = _scanMenu.findItemById(foundDevice.serialNumber());
            var subLabel = rssiToQualityPercent(foundDevice.rssi());
            if(index >= 0)
            {
                // Already in the menu
                var menuItem = _scanMenu.getItem(index) as WatchUi.MenuItem;
                menuItem.setSubLabel(subLabel);
            }
            else
            {
                var label = "S/N " + foundDevice.serialNumber();
                var icon = new WatchUi.Bitmap({:rezId => Rez.Drawables.ScanIcon});
                _scanMenu.addItem(new WatchUi.IconMenuItem(label, subLabel, foundDevice.serialNumber(), icon, null));
                _deviceHandlesInScanMenu.add(foundDevice);
                forceUpdateHack();
            }
        }

        if(!_scanMenuVisible && _deviceHandlesInScanMenu.size() > 0)
        {
            WatchUi.pushView(_scanMenu, _scanMenuDelegate, WatchUi.SLIDE_IMMEDIATE);
            _scanMenuVisible = true;
        }
        else if(_scanMenuVisible && _deviceHandlesInScanMenu.size() == 0)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _scanMenuVisible = false;
        }
        else
        {
            // Avoid updating more frequently than necessary
            var timeSinceUpdate = Time.now().compare(_lastUpdateTime);
            if(timeSinceUpdate >= 3)
            {
                forceUpdateHack();
                _lastUpdateTime = Time.now();
            }
        }
    }

    public function onAppStateChanged(appState as App.State) as Void
    {
        _numTimeouts = 0;

        if(!_settingsView.showing() && appState == App.CONNECTED)
        {
            _settingsView.show();
        }
        else if(_settingsView.showing() && appState != App.CONNECTED)
        {
            _settingsView.hide();
        }
        else if(_scanMenuVisible && appState == App.STOPPING)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _scanMenuVisible = false;
        }

        WatchUi.requestUpdate();
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        _settingsView.onParameterRead(parameter, value);
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        _settingsView.onCurrentGearChanged(currentGear);
    }

    public function onConnecting(deviceHandle as Pinion.DeviceHandle) as Void
    {
        _deviceSerialNumber = deviceHandle.serialNumber();
    }
}