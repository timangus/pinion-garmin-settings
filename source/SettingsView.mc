using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Time;
using Toybox.Timer;

class SettingsViewInputDelegate extends WatchUi.Menu2InputDelegate
{
    private var _view as SettingsView;

    public function initialize(view as SettingsView)
    {
        WatchUi.Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void
    {
        _view.onSelect(item);
    }

    function onBack() as Void
    {
        _view.onBack();
    }
}

class SettingsView extends WatchUi.Menu2
{
    private var _settingsViewInputDelegate as SettingsViewInputDelegate = new SettingsViewInputDelegate(self);
    private var _app as App?;
    private var _showing as Lang.Boolean = false;
    private var _viewPushed as Lang.Boolean = false;
    private var _synced as Lang.Boolean = false;

    private var _remainingReads as Lang.Array<Pinion.ParameterType> = new Lang.Array<Pinion.ParameterType>[0];

    private var _currentGear as Lang.Number = 0;
    private var _batteryLevel as Lang.Number = 0;
    private var _batteryLevelTimer as Timer.Timer = new Timer.Timer();

    private var _subMenuDepth as Lang.Number = 0;

    private var _infoMenu as WatchUi.Menu2 = new Rez.Menus.InfoMenu();

    private function updateTitle() as Void
    {
        var currentGear = _currentGear > 0 ? _currentGear : "-";
        var batteryLevel = _batteryLevel > 0 ? (_batteryLevel / 100.0).format("%.1f") : "-";
        var title = Lang.format("Gear: $1$ Battery: $2$%", [currentGear, batteryLevel]);

        setTitle(title);

        if(_viewPushed && _subMenuDepth == 0)
        {
            // Force refresh hack
            WatchUi.switchToView(self, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
        }
    }

    public function initialize()
    {
        WatchUi.Menu2.initialize(null);

        addItem(new WatchUi.ToggleMenuItem("Pre.Select", {:enabled => "Enabled", :disabled => "Disabled"},
            "pre.select", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
        addItem(new WatchUi.ToggleMenuItem("Start.Select", {:enabled => "Enabled", :disabled => "Disabled"},
            "start.select", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
        addItem(new WatchUi.MenuItem("Information", null, "information", null));
        addItem(new WatchUi.MenuItem("Disconnect", null, "disconnect", null));

        updateTitle();
    }

    public function setApp(app as App) as Void
    {
        _app = app;
    }

    public function _readBatteryLevel() as Void
    {
        (_app as App).readParameter(Pinion.BATTERY_LEVEL);
    }

    public function show() as Void
    {
        if(showing())
        {
            Debug.error("SettingsView.show called when already showing");
        }

        _remainingReads =
        [
            Pinion.PRE_SELECT,
            Pinion.START_SELECT,
            Pinion.CURRENT_GEAR,
            Pinion.BATTERY_LEVEL,
            Pinion.HARDWARE_VERSION,
            Pinion.SERIAL_NUMBER,
            Pinion.BOOTLOADER_VERSION,
            Pinion.FIRMWARE_VERSION,
        ];

        var i = _remainingReads.size() - 1;
        while(i >= 0)
        {
            (_app as App).readParameter(_remainingReads[i]);
            i--;
        }

        _showing = true;
    }

    private function onFinishedSync() as Void
    {
        WatchUi.pushView(self, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
        _viewPushed = true;
        _batteryLevelTimer.start(method(:_readBatteryLevel), 60000, true);
    }

    public function hide() as Void
    {
        if(!showing())
        {
            Debug.error("SettingsView.hide called when not showing");
        }

        _showing = false;
        _synced = false;
        _batteryLevelTimer.stop();

        if(_viewPushed)
        {
            while(_subMenuDepth > 0)
            {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                _subMenuDepth--;
            }

            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _viewPushed = false;
        }
    }

    public function showing() as Lang.Boolean
    {
        return _showing;
    }

    private function setToggleById(menu as WatchUi.Menu2, id as Lang.String or Lang.Symbol, value as Lang.Boolean) as Void
    {
        var index = menu.findItemById(id);
        if(index < 0)
        {
            Debug.error("setToggleById couldn't find item");
        }

        var item = menu.getItem(index) as WatchUi.ToggleMenuItem;
        item.setEnabled(value);

        WatchUi.requestUpdate();
    }

    private function dottedQuadFor(value as Lang.Number) as Lang.String
    {
        var a = [];

        for(var i = 0; i < 4; i++)
        {
            a.add(value & 0xff);
            value = value >> 8;
        }

        a = a.reverse();

        var s = "";

        for(var i = 0; i < a.size(); i++)
        {
            if(s.length() != 0)
            {
                s += ".";
            }

            s += a[i];
        }

        return s as Lang.String;
    }

    private function setMenuSublabelById(menu as WatchUi.Menu2, id as Lang.String or Lang.Symbol, value as Lang.String) as Void
    {
        var index = menu.findItemById(id);
        if(index < 0)
        {
            Debug.error("setMenuSublabelById couldn't find item");
        }

        var item = menu.getItem(index) as WatchUi.MenuItem;
        item.setSubLabel(value);

        WatchUi.requestUpdate();
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        if(parameter.equals("PRE_SELECT"))
        {
            setToggleById(self, "pre.select", value == 1);
        }
        else if(parameter.equals("START_SELECT"))
        {
            setToggleById(self, "start.select", value == 1);
        }
        else if(parameter.equals("HARDWARE_VERSION"))
        {
            setMenuSublabelById(_infoMenu, :id_hardware_version, dottedQuadFor(value));
        }
        else if(parameter.equals("SERIAL_NUMBER"))
        {
            setMenuSublabelById(_infoMenu, :id_serial_number, value.toString());
        }
        else if(parameter.equals("BOOTLOADER_VERSION"))
        {
            setMenuSublabelById(_infoMenu, :id_bootloader_version, dottedQuadFor(value));
        }
        else if(parameter.equals("FIRMWARE_VERSION"))
        {
            setMenuSublabelById(_infoMenu, :id_firmware_version, dottedQuadFor(value));
        }
        else if(parameter.equals("CURRENT_GEAR"))
        {
            _currentGear = value;
            updateTitle();
        }
        else if(parameter.equals("BATTERY_LEVEL"))
        {
            _batteryLevel = value;
            updateTitle();
        }

        if(!_synced)
        {
            _remainingReads.remove(parameter);
            if(_remainingReads.size() == 0)
            {
                _synced = true;
                onFinishedSync();
            }
        }
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
        _currentGear = currentGear;
        updateTitle();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        var id = item.getId() as Lang.String;

        if(id.equals("pre.select"))
        {
            var toggleMenuItem = item as WatchUi.ToggleMenuItem;
            (_app as App).writeParameter(Pinion.PRE_SELECT, toggleMenuItem.isEnabled() ? 1 : 0);
            if(toggleMenuItem.isEnabled())
            {
                (_app as App).writeParameter(Pinion.START_SELECT, 0);
                setToggleById(self, "start.select", false);
            }
        }
        else if(id.equals("start.select"))
        {
            var toggleMenuItem = item as WatchUi.ToggleMenuItem;
            (_app as App).writeParameter(Pinion.START_SELECT, toggleMenuItem.isEnabled() ? 1 : 0);
            if(toggleMenuItem.isEnabled())
            {
                (_app as App).writeParameter(Pinion.PRE_SELECT, 0);
                setToggleById(self, "pre.select", false);
            }
        }
        else if(id.equals("information"))
        {
            WatchUi.pushView(_infoMenu, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
            _subMenuDepth++;
        }
        else if(id.equals("disconnect"))
        {
            (_app as App).unstore();
            (_app as App).disconnect();
        }
    }

    public function onBack() as Void
    {
        if(_subMenuDepth > 0)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _subMenuDepth--;
            return;
        }

        (_app as App).exit();
    }
}