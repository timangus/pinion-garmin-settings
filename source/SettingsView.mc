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

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        _view.onSelect(item);
    }

    public function onBack() as Void
    {
        _view.onBack();
    }
}

class SettingsViewPickerDelegate extends WatchUi.PickerDelegate
{
    private var _view as SettingsView;
    private var _item as WatchUi.MenuItem? = null;

    public function initialize(view as SettingsView)
    {
        WatchUi.PickerDelegate.initialize();
        _view = view;
    }

    public function setItem(item as WatchUi.MenuItem) as Void { _item = item; }

    public function onAccept(values as Lang.Array) as Lang.Boolean
    {
        if(_item != null) { return _view.onPickerAccept(_item, values[0] as Lang.Number); }
        return false;
    }

    public function onCancel() as Lang.Boolean
    {
        if(_item != null) { return _view.onPickerCancel(_item); }
        return false;
    }
}

class SettingsView extends WatchUi.Menu2
{
    private var _settingsViewInputDelegate as SettingsViewInputDelegate = new SettingsViewInputDelegate(self);
    private var _settingsViewPickerDelegate as SettingsViewPickerDelegate = new SettingsViewPickerDelegate(self);
    private var _app as App?;
    private var _showing as Lang.Boolean = false;
    private var _viewPushed as Lang.Boolean = false;
    private var _synced as Lang.Boolean = false;

    private var _remainingReads as Lang.Array<Pinion.ParameterType> = new Lang.Array<Pinion.ParameterType>[0];

    private var _batteryLevelTimer as Timer.Timer = new Timer.Timer();

    private var _subMenuDepth as Lang.Number = 0;

    private var _infoMenu as WatchUi.Menu2 = new Rez.Menus.InfoMenu();
    private var _setupMenu as WatchUi.Menu2 = new Rez.Menus.SetupMenu();

    private var _parameterData as Lang.Dictionary<Pinion.ParameterType, Lang.Dictionary> =
    {
        Pinion.CURRENT_GEAR =>              { :value => -1 },
        Pinion.BATTERY_LEVEL =>             { :value => -1 },
        Pinion.NUMBER_OF_GEARS =>           { :value => -1 },

        Pinion.PRE_SELECT =>                { :menu => self,        :id => "pre.select",              :value => -1, :post => method(:_disableStartSelect) },
        Pinion.PRE_SELECT_CADENCE =>        { :menu => self,        :id => "pre.select.cadence",      :value => -1, :increment => 5 },
        Pinion.START_SELECT =>              { :menu => self,        :id => "start.select",            :value => -1, :post => method(:_disablePreSelect) },
        Pinion.START_SELECT_GEAR =>         { :menu => self,        :id => "start.select.gear",       :value => -1, :minmax => [1, 12] },
        Pinion.REVERSE_TRIGGER_MAPPING =>   { :menu => self,        :id => "reverse.trigger",         :value => -1 },

        Pinion.MOUNTING_ANGLE =>            { :menu => _setupMenu,  :id => :id_mounting_angle,        :value => -1 },
        Pinion.REAR_TEETH =>                { :menu => _setupMenu,  :id => :id_rear_teeth,            :value => -1 },
        Pinion.FRONT_TEETH =>               { :menu => _setupMenu,  :id => :id_front_teeth,           :value => -1 },
        Pinion.WHEEL_CIRCUMFERENCE =>       { :menu => _setupMenu,  :id => :id_wheel_circ,            :value => -1 },
        Pinion.SPEED_SENSOR_TYPE =>         { :menu => _setupMenu,  :id => :id_speed_sensor,          :value => -1 },

        Pinion.HARDWARE_VERSION =>          { :menu => _infoMenu,   :id => :id_hardware_version,      :value => -1, :format => method(:_dottedQuad) },
        Pinion.SERIAL_NUMBER =>             { :menu => _infoMenu,   :id => :id_serial_number,         :value => -1 },
        Pinion.BOOTLOADER_VERSION =>        { :menu => _infoMenu,   :id => :id_bootloader_version,    :value => -1, :format => method(:_dottedQuad) },
        Pinion.FIRMWARE_VERSION =>          { :menu => _infoMenu,   :id => :id_firmware_version,      :value => -1, :format => method(:_dottedQuad) },
    } as Lang.Dictionary<Pinion.ParameterType, Lang.Dictionary>;

    private function findParameterTypeFor(id as Lang.String or Lang.Symbol) as Pinion.ParameterType?
    {
        var keys = _parameterData.keys();

        for(var i = 0; i < keys.size(); i++)
        {
            var key = keys[i];
            var parameterDatum = _parameterData[key] as Lang.Dictionary;

            if(!parameterDatum.hasKey(:id))
            {
                continue;
            }

            var parameterItemId = parameterDatum[:id] as Lang.String or Lang.Symbol;
            if(parameterItemId.equals(id))
            {
                return key;
            }
        }

        return null;
    }

    private function updateTitle() as Void
    {
        var currentGear = (_parameterData[Pinion.CURRENT_GEAR] as Lang.Dictionary)[:value] as Lang.Number;
        currentGear = currentGear > 0 ? currentGear : "-";

        var batteryLevel = (_parameterData[Pinion.BATTERY_LEVEL] as Lang.Dictionary)[:value] as Lang.Number;
        batteryLevel = batteryLevel > 0 ? (batteryLevel / 100.0).format("%.1f") : "-";

        var title = Lang.format("Gear: $1$ Battery: $2$%", [currentGear, batteryLevel]);

        setTitle(title);

        if(_viewPushed && _subMenuDepth == 0)
        {
            // See comment in MainView.forceUpdateHack
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
        addItem(new WatchUi.MenuItem("Target Cadence", "-", "pre.select.cadence", null));
        addItem(new WatchUi.MenuItem("Start Gear", "-", "start.select.gear", null));
        addItem(new WatchUi.ToggleMenuItem("Trigger Buttons", {:enabled => "Reversed", :disabled => "Normal"},
            "reverse.trigger", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
        addItem(new WatchUi.MenuItem("Setup", null, "setup", null));
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

        _synced = false;
        _remainingReads = _parameterData.keys();
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

    public function syncing() as Lang.Boolean
    {
        return showing() && !_synced;
    }

    public function _dottedQuad(value as Lang.Number) as Lang.String
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

    private function syncUiToParameterData(parameter as Pinion.ParameterType) as Void
    {
        var pinionParameterDatum = Pinion.PARAMETERS[parameter] as Lang.Dictionary;
        var parameterDatum = _parameterData[parameter] as Lang.Dictionary;

        if(!parameterDatum.hasKey(:menu) || !parameterDatum.hasKey(:id))
        {
            Debug.log("syncUiToParameterData returned on parameter with no UI");
            return;
        }

        var menu = parameterDatum[:menu] as WatchUi.Menu2;
        var id = parameterDatum[:id] as Lang.String or Lang.Symbol;
        var index = menu.findItemById(id);

        if(index < 0)
        {
            Debug.error("syncUiToParameterData couldn't find menu item");
        }

        var item = menu.getItem(index);
        var value = parameterDatum[:value] as Lang.Number;
        switch(item)
        {
        case instanceof WatchUi.ToggleMenuItem:
            var toggleMenuItem = menu.getItem(index) as WatchUi.ToggleMenuItem;
            var validValues = (pinionParameterDatum.hasKey(:values) ?
                pinionParameterDatum[:values] : [0, 1]) as Lang.Array<Lang.Number>;
            var trueValue = validValues[1] as Lang.Number;
            toggleMenuItem.setEnabled(value == trueValue);
            break;

        case instanceof WatchUi.MenuItem:
            var baseItem = menu.getItem(index) as WatchUi.MenuItem;

            if(parameterDatum.hasKey(:format))
            {
                var m = parameterDatum[:format] as Lang.Method;
                var result = m.invoke(value) as Lang.String;
                baseItem.setSubLabel(result);
            }
            else
            {
                baseItem.setSubLabel(value.toString());
            }
            break;
        }

        WatchUi.requestUpdate();
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        var parameterDatum = _parameterData[parameter] as Lang.Dictionary;
        parameterDatum[:value] = value;

        if(parameter.equals("CURRENT_GEAR") || parameter.equals("BATTERY_LEVEL"))
        {
            updateTitle();
        }
        else if(parameter.equals("NUMBER_OF_GEARS") && _parameterData.hasKey(Pinion.START_SELECT_GEAR))
        {
            // We need to manually set the minmax of the start gear parameter as it
            // depends on the actual number of gears the gearbox has
            var startSelectGearParameterDatum = _parameterData[Pinion.START_SELECT_GEAR] as Lang.Dictionary;
            var minmax = startSelectGearParameterDatum[:minmax] as Lang.Array<Lang.Number>;
            minmax[1] = value;
        }
        else if(parameterDatum.hasKey(:menu) && parameterDatum.hasKey(:id))
        {
            syncUiToParameterData(parameter);
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
        var parameterDatum = _parameterData[Pinion.CURRENT_GEAR] as Lang.Dictionary;
        parameterDatum[:value] = currentGear;
        updateTitle();
    }

    private function writeParameter(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        (_app as App).writeParameter(parameter, value);
        var parameterDatum = _parameterData[parameter] as Lang.Dictionary;
        parameterDatum[:value] = value;
        syncUiToParameterData(parameter);
    }

    public function _disableStartSelect(item as WatchUi.MenuItem) as Void
    {
        var toggleMenuItem = item as WatchUi.ToggleMenuItem;
        if(toggleMenuItem.isEnabled()) { writeParameter(Pinion.START_SELECT, 0); }
    }

    public function _disablePreSelect(item as WatchUi.MenuItem) as Void
    {
        var toggleMenuItem = item as WatchUi.ToggleMenuItem;
        if(toggleMenuItem.isEnabled()) { writeParameter(Pinion.PRE_SELECT, 0); }
    }

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        var id = item.getId() as Lang.String or Lang.Symbol;
        var parameter = findParameterTypeFor(id);

        if(parameter != null)
        {
            var pinionParameterDatum = Pinion.PARAMETERS[parameter] as Lang.Dictionary;
            var parameterDatum = _parameterData[parameter] as Lang.Dictionary;

            switch(item)
            {
            case instanceof WatchUi.ToggleMenuItem:
                var toggleMenuItem = item as WatchUi.ToggleMenuItem;
                var validValues = (pinionParameterDatum.hasKey(:values) ?
                    pinionParameterDatum[:values] : [0, 1]) as Lang.Array<Lang.Number>;
                var value = validValues[toggleMenuItem.isEnabled() ? 1 : 0] as Lang.Number;
                writeParameter(parameter, value);
                break;

            case instanceof WatchUi.MenuItem:
                var menuItem = item as WatchUi.MenuItem;
                if(pinionParameterDatum.hasKey(:minmax))
                {
                    var minmax = (parameterDatum.hasKey(:minmax) ?
                        parameterDatum[:minmax] : pinionParameterDatum[:minmax]) as Lang.Array<Lang.Number>;
                    var increment = (parameterDatum.hasKey(:increment) ?
                        parameterDatum[:increment] : 1) as Lang.Number;
                    var numberPickerView = new NumberPickerView(menuItem.getLabel(),
                        minmax[0], minmax[1], increment, parameterDatum[:value] as Lang.Number);
                    _settingsViewPickerDelegate.setItem(item);
                    WatchUi.pushView(numberPickerView, _settingsViewPickerDelegate, WatchUi.SLIDE_IMMEDIATE);
                    _subMenuDepth++;
                }
                break;
            }

            if(parameterDatum.hasKey(:post))
            {
                var m = parameterDatum[:post] as Lang.Method;
                m.invoke(item);
            }
        }
        else if(id.equals("setup"))
        {
            WatchUi.pushView(_setupMenu, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
            _subMenuDepth++;
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

    public function onPickerAccept(item as WatchUi.MenuItem, value as Lang.Number) as Lang.Boolean
    {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _subMenuDepth--;

        var id = item.getId() as Lang.String or Lang.Symbol;
        var parameter = findParameterTypeFor(id);

        if(parameter != null)
        {
            switch(item)
            {
            case instanceof WatchUi.MenuItem:
                writeParameter(parameter, value);
                break;
            }
        }

        return true;
    }

    public function onPickerCancel(item as WatchUi.MenuItem) as Lang.Boolean
    {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _subMenuDepth--;

        return true;
    }
}