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
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

class SettingsView extends WatchUi.Menu2
{
    private var _settingsViewInputDelegate as SettingsViewInputDelegate = new SettingsViewInputDelegate(self);
    private var _app as App?;
    private var _showing as Lang.Boolean = false;

    public function initialize()
    {
        WatchUi.Menu2.initialize({:title => "Smart.Shift Settings"});

        addItem(new WatchUi.ToggleMenuItem("Trigger Dir", {:enabled => "Reverse", :disabled => "Normal"},
            "trigger.mapping", false, {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_RIGHT}));
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

        WatchUi.pushView(self, _settingsViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
    }

    public function hide() as Void
    {
        if(!showing())
        {
            Debug.error("SettingsView.hide called when not showing");
        }

        _showing = false;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    public function onShow() as Void
    {
        _showing = true;
    }

    public function onHide() as Void
    {
        _showing = false;
    }

    public function showing() as Lang.Boolean
    {
        return _showing;
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        if(parameter.equals("REVERSE_TRIGGER_MAPPING"))
        {
            var index = findItemById("trigger.mapping");
            var item = getItem(index) as WatchUi.ToggleMenuItem;
            item.setEnabled(value == 1);
        }
    }

    public function onSelect(item as WatchUi.MenuItem) as Void
    {
        var id = item.getId() as Lang.String;

        if(id.equals("trigger.mapping"))
        {
            var toggleMenuItem = item as WatchUi.ToggleMenuItem;
            (_app as App).writeParameter(Pinion.REVERSE_TRIGGER_MAPPING, toggleMenuItem.isEnabled() ? 1 : 0);
        }
        else if(id.equals("disconnect"))
        {
            (_app as App).unstore();
            (_app as App).disconnect();
        }
    }
}