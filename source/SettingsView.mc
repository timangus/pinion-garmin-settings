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
        System.println(item.getId());
        if((item.getId() as Lang.String).equals("pre.select"))
        {
            var toggleMenuItem = item as WatchUi.ToggleMenuItem;
            (_app as App).writeParameter(Pinion.PRE_SELECT, toggleMenuItem.isEnabled() ? 1 : 0);
        }
    }
}

class SettingsView extends WatchUi.Menu2
{
    public function initialize()
    {
        WatchUi.Menu2.initialize({:title => "Smart.Shift Settings"});

        addItem(new WatchUi.ToggleMenuItem("Pre.Select", {:enabled => "Enabled", :disabled => "Disabled"},
            "pre.select", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
    }
}