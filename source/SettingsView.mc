using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Time;

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
        _view.exit();
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

    public function initialize()
    {
        WatchUi.Menu2.initialize(null);

        addItem(new WatchUi.ToggleMenuItem("Pre.Select", {:enabled => "Enabled", :disabled => "Disabled"},
            "pre.select", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
        addItem(new WatchUi.ToggleMenuItem("Start.Select", {:enabled => "Enabled", :disabled => "Disabled"},
            "start.select", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
        addItem(new WatchUi.MenuItem("Disconnect", null, "disconnect", null));
    }

    public function setApp(app as App) as Void
    {
        _app = app;
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
    }

    public function hide() as Void
    {
        if(!showing())
        {
            Debug.error("SettingsView.hide called when not showing");
        }

        _showing = false;
        _synced = false;

        if(_viewPushed)
        {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _viewPushed = false;
        }
    }

    public function showing() as Lang.Boolean
    {
        return _showing;
    }

    public function setToggleById(id as Lang.String, value as Lang.Boolean) as Void
    {
        var index = findItemById(id);
        if(index < 0)
        {
            Debug.error("setToggleById couldn't find item");
        }

        var item = getItem(index) as WatchUi.ToggleMenuItem;
        item.setEnabled(value);

        WatchUi.requestUpdate();
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        if(parameter.equals("PRE_SELECT"))
        {
            setToggleById("pre.select", value == 1);
        }
        else if(parameter.equals("START_SELECT"))
        {
            setToggleById("start.select", value == 1);
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
                setToggleById("start.select", false);
            }
        }
        else if(id.equals("start.select"))
        {
            var toggleMenuItem = item as WatchUi.ToggleMenuItem;
            (_app as App).writeParameter(Pinion.START_SELECT, toggleMenuItem.isEnabled() ? 1 : 0);
            if(toggleMenuItem.isEnabled())
            {
                (_app as App).writeParameter(Pinion.PRE_SELECT, 0);
                setToggleById("pre.select", false);
            }
        }
        else if(id.equals("disconnect"))
        {
            (_app as App).unstore();
            (_app as App).disconnect();
        }
    }

    public function exit() as Void
    {
        (_app as App).exit();
    }
}