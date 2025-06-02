using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Time;

class MainViewInputDelegate extends WatchUi.Menu2InputDelegate
{
    private var _mainView as MainView?;

    public function initialize(mainView as MainView)
    {
        WatchUi.Menu2InputDelegate.initialize();
        _mainView = mainView;
    }

    function onSelect(item as WatchUi.MenuItem) as Void
    {
        (_mainView as MainView).selectDevice(item.getId() as Lang.Long);
    }

    function onBack() as Void
    {
        (_mainView as MainView).exit();
    }
}

class MainView extends WatchUi.View
{
    private var _app as App;

    private var _scanMenu as WatchUi.Menu2 = new WatchUi.Menu2({:title => "Smart.Shift Devices"});
    private var _scanMenuDelegate as MainViewInputDelegate = new MainViewInputDelegate(self);
    private var _scanMenuVisible as Lang.Boolean = false;
    private var _deviceHandlesInScanMenu as Lang.Array<Pinion.DeviceHandle> = new Lang.Array<Pinion.DeviceHandle>[0];

    private var _settingsView as SettingsView = new SettingsView();
    private var _settingsViewInputDelegate as SettingsViewInputDelegate = new SettingsViewInputDelegate();
    private var _settingsVisible as Lang.Boolean = false;

    private var _lastUpdateTime as Time.Moment = Time.now();

    private var _timingOut as Lang.Boolean = false;

    public function initialize(app as App)
    {
        View.initialize();

        _app = app;
        _settingsViewInputDelegate.setApp(app);
    }

    function onLayout(dc as Toybox.Graphics.Dc) as Void
    {
    }

    function onUpdate(dc as Toybox.Graphics.Dc) as Void
    {
        switch(_app.state())
        {
        case App.SCANNING:
            setLayout(Rez.Layouts.ScanningLayout(dc));
            break;

        case App.CONNECTING:
            setLayout(Rez.Layouts.ConnectingLayout(dc));
            var connectionTimeoutLayoutText = findDrawableById("id_connection_timeout") as WatchUi.Text;
            connectionTimeoutLayoutText.setText(_timingOut ? "Time Out" : "");
            break;

        case App.STOPPING:
            setLayout(Rez.Layouts.StoppingLayout(dc));
            break;
        }

        View.onUpdate(dc);
    }

    function onShow() as Void
    {
    }

    function onHide() as Void
    {
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

        System.println("Can't find handle for serial " + serialNumber);
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
        _timingOut = true;
        WatchUi.requestUpdate();
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
            if(index >= 0)
            {
                // Already in the menu
                var menuItem = _scanMenu.getItem(index) as WatchUi.MenuItem;
                menuItem.setSubLabel("RSSI: " + foundDevice.rssi());
            }
            else
            {
                var label = "Pinion " + foundDevice.serialNumber();
                var subLabel = "RSSI: " + foundDevice.rssi();
                _scanMenu.addItem(new WatchUi.MenuItem(label, subLabel, foundDevice.serialNumber(), null));
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

    public function onAppStateChanged(appState as App.AppState) as Void
    {
        _timingOut = false;
        WatchUi.requestUpdate();

        if(!_settingsVisible && appState == App.CONNECTED)
        {
            WatchUi.pushView(_settingsView, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
            _settingsVisible = true;
        }
        else if(_settingsVisible && appState != App.CONNECTED)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _settingsVisible = false;
        }
        else if(_scanMenuVisible && appState == App.STOPPING)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _scanMenuVisible = false;
        }
    }
}