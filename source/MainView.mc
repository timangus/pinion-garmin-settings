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
        (_mainView as MainView).selectDevice(item.getId() as Pinion.DeviceHandle);
    }
}

class MainView extends WatchUi.View
{
    private var _app as App;

    private var _scanMenu as WatchUi.Menu2 = new WatchUi.Menu2({:title => "Smart.Shift Devices"});
    private var _scanMenuDelegate as MainViewInputDelegate = new MainViewInputDelegate(self);
    private var _scanMenuVisible as Lang.Boolean = false;
    private var _pinionsInScanMenu as Lang.Array<Pinion.DeviceHandle> = new Lang.Array<Pinion.DeviceHandle>[0];

    private var _settingsView as SettingsView = new SettingsView();
    private var _settingsViewInputDelegate as SettingsViewInputDelegate = new SettingsViewInputDelegate();

    private var _lastUpdateTime as Time.Moment = Time.now();

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

    public function selectDevice(deviceHandle as Pinion.DeviceHandle) as Void
    {
        _app.selectDevice(deviceHandle);
        if(_scanMenuVisible)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _scanMenuVisible = false;
        }
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
        var connectingLayout = findDrawableById("id_connecting") as WatchUi.Text;
        connectingLayout.setText("Connecting... (Timeout)");
        WatchUi.requestUpdate();
    }

    public function onFoundDevicesChanged(foundDevices as Lang.Array<Pinion.DeviceHandle>) as Void
    {
        var j = _pinionsInScanMenu.size() - 1;
        while(j >= 0)
        {
            var pinionInMenu = _pinionsInScanMenu[j];
            var stillExists = false;

            for(var k = 0; k < foundDevices.size(); k++)
            {
                if(foundDevices[k].serialNumber() == pinionInMenu.serialNumber())
                {
                    stillExists = true;
                    break;
                }
            }

            if(!stillExists)
            {
                var menuItemIndex = _scanMenu.findItemById(pinionInMenu);
                _scanMenu.deleteItem(menuItemIndex);
                _pinionsInScanMenu.remove(pinionInMenu);
                forceUpdateHack();
            }

            j--;
        }

        for(var i = 0; i < foundDevices.size(); i++)
        {
            var foundDevice = foundDevices[i];
            var index = _scanMenu.findItemById(foundDevice);
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
                _scanMenu.addItem(new WatchUi.MenuItem(label, subLabel, foundDevice, null));
                _pinionsInScanMenu.add(foundDevice);
                forceUpdateHack();
            }
        }

        if(!_scanMenuVisible && _pinionsInScanMenu.size() > 0)
        {
            WatchUi.pushView(_scanMenu, _scanMenuDelegate, WatchUi.SLIDE_IMMEDIATE);
            _scanMenuVisible = true;
        }
        else if(_scanMenuVisible && _pinionsInScanMenu.size() == 0)
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
        WatchUi.requestUpdate();

        if(appState == App.CONNECTED)
        {
            WatchUi.pushView(_settingsView, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
        }
    }
}