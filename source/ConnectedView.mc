using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;

class ConnectedViewInputDelegate extends WatchUi.BehaviorDelegate
{
    private var _view as ConnectedView;

    public function initialize(view as ConnectedView)
    {
        WatchUi.BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Lang.Boolean
    {
        _view.exit();
        return true;
    }

    public function onSelectable(selectableEvent as WatchUi.SelectableEvent) as Lang.Boolean
    {
        var instance = selectableEvent.getInstance() as WatchUi.Selectable;

        switch(instance.getState())
        {
        case :stateSelected:
            if(instance.identifier != null)
            {
                _view.onSelect(instance.identifier as Lang.String);
            }

            instance.setState(:stateHighlighted);
            break;
        }

        return false;
    }

    public function onSettings() as Void
    {
        _view.onSettings();
    }
}

class ConnectedView extends WatchUi.View
{
    const PARAMETER_MAP =
    {
        Pinion.PRE_SELECT =>    "pre_select",
        Pinion.START_SELECT =>  "start_select",
    };

    private function parameterForId(id as Lang.String) as Pinion.ParameterType?
    {
        var parameters = PARAMETER_MAP.keys();

        for(var i = 0; i < PARAMETER_MAP.size(); i++)
        {
            var parameter = parameters[i];
            var parameterId = PARAMETER_MAP[parameter] as Lang.String;

            if(parameterId.equals(id))
            {
                return parameter as Pinion.ParameterType;
            }
        }
        return null;
    }

    private var _connectedViewInputDelegate as ConnectedViewInputDelegate = new ConnectedViewInputDelegate(self);
    private var _app as App?;
    private var _showing as Lang.Boolean = false;

    private var _settingsView as SettingsView = new SettingsView();

    private var _remainingReads as Lang.Array<Pinion.ParameterType> = new Lang.Array<Pinion.ParameterType>[0];


    public function initialize()
    {
        View.initialize();
    }

    public function setApp(app as App) as Void
    {
        _app = app;
        _settingsView.setApp(app);
    }

    public function show() as Void
    {
        if(showing())
        {
            Debug.error("ConnectedView.show called when already showing");
        }

        WatchUi.pushView(self, _connectedViewInputDelegate, WatchUi.SLIDE_IMMEDIATE);
    }

    public function hide() as Void
    {
        if(!showing())
        {
            Debug.error("ConnectedView.hide called when not showing");
        }

        if(_settingsView.showing())
        {
            _settingsView.hide();
        }

        _showing = false;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    public function showing() as Lang.Boolean
    {
        return _showing || _settingsView.showing();
    }

    public function onShow() as Void
    {
        _showing = true;

        //FIXME: set this based on device capabilities
        setKeyToSelectableInteraction(true);

        _remainingReads = [Pinion.PRE_SELECT, Pinion.START_SELECT];

        var i = _remainingReads.size() - 1;
        while(i >= 0)
        {
            (_app as App).readParameter(_remainingReads[i]);
            i--;
        }
    }

    public function onHide() as Void
    {
        _showing = false;
    }

    public function onLayout(dc as Graphics.Dc) as Void
    {
        setLayout(Rez.Layouts.ConnectedLayout(dc));
    }

    public function exit() as Void
    {
        (_app as App).exit();
    }

    public function onSelect(id as Lang.String) as Void
    {
        var item = findDrawableById(id + "_item");
        if(item != null)
        {
            switch(item)
            {
            case instanceof ToggleSwitch:
                var toggleSwitch = item as ToggleSwitch;
                toggleSwitch.setState(!toggleSwitch.state());
                var parameter = parameterForId(id) as Pinion.ParameterType;
                (_app as App).writeParameter(parameter, toggleSwitch.state() ? 1 : 0);
                break;
            }
        }

        WatchUi.requestUpdate();
    }

    public function onSettings() as Void
    {
        _settingsView.show();
    }

    public function onParameterRead(parameter as Pinion.ParameterType, value as Lang.Number) as Void
    {
        _remainingReads.remove(parameter);

        var itemName = PARAMETER_MAP[parameter] as Lang.String;
        if(itemName != null)
        {
            var item = findDrawableById(itemName + "_item");
            if(item != null)
            {
                switch(item)
                {
                case instanceof ToggleSwitch:
                    var toggleSwitch = item as ToggleSwitch;
                    toggleSwitch.setState(value == 1);
                    WatchUi.requestUpdate();
                    break;
                }
            }
        }

        _settingsView.onParameterRead(parameter, value);
    }
}