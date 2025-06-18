using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Time;

class SettingsViewInputDelegate extends WatchUi.Menu2InputDelegate
{
    private var _app as App?;

    public function initialize()
    {
        WatchUi.Menu2InputDelegate.initialize();
    }

    public function setApp(app as App) as Void
    {
        _app = app;
    }

    function onSelect(item as WatchUi.MenuItem) as Void
    {
        var id = item.getId() as Lang.String;

        if(id.equals("pre.select"))
        {
            var toggleMenuItem = item as WatchUi.ToggleMenuItem;
            (_app as App).writeParameter(Pinion.PRE_SELECT, toggleMenuItem.isEnabled() ? 1 : 0);
        }
        else if(id.equals("disconnect"))
        {
            (_app as App).unstore();
            (_app as App).disconnect();
        }
    }

    function onBack() as Void
    {
        (_app as App).exit();
    }
}

class SettingsView extends WatchUi.Menu2
{
    public function initialize()
    {
        WatchUi.Menu2.initialize({:title => "Smart.Shift Settings"});

        addItem(new WatchUi.ToggleMenuItem("Pre.Select", {:enabled => "Enabled", :disabled => "Disabled"},
            "pre.select", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
        addItem(new WatchUi.MenuItem("Disconnect", null, "disconnect", null));
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        if(parameter.equals("PRE_SELECT"))
        {
            var index = findItemById("pre.select");
            var item = getItem(index) as WatchUi.ToggleMenuItem;
            item.setEnabled(value == 1);
        }
    }

    public function onCurrentGearChanged(currentGear as Lang.Number) as Void
    {
    }
}