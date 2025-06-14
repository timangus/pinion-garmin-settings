using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;

class ConnectedViewInputDelegate extends WatchUi.BehaviorDelegate
{
    private var _view as ConnectedView;
    private var _app as App?;

    public function initialize(view as ConnectedView)
    {
        WatchUi.BehaviorDelegate.initialize();
        _view = view;
    }

    public function setApp(app as App) as Void
    {
        _app = app;
    }

    public function onPreviousPage() as Lang.Boolean
    {
        _view.onPrevious();
        return true;
    }

    public function onNextPage() as Lang.Boolean
    {
        _view.onNext();
        return true;
    }

    public function onSelect() as Lang.Boolean
    {
        _view.onSelect();
        return true;
    }
}

class ConnectedView extends WatchUi.View
{
    private var _app as App?;
    private var _selectableItems as Lang.Array<Lang.String> = ["pre_select", "start_select"];
    private var _selectedItemIndex as Lang.Number = 0;

    public function initialize()
    {
        View.initialize();
    }

    public function setApp(app as App) as Void
    {
        _app = app;
    }

    public function onShow() as Void
    {
        updateSelection();
    }

    public function onLayout(dc as Graphics.Dc) as Void
    {
        setLayout(Rez.Layouts.ConnectedLayout(dc));
    }

    public function onPrevious() as Void
    {
        _selectedItemIndex = (_selectedItemIndex + _selectableItems.size() - 1) % _selectableItems.size();
        updateSelection();
    }

    public function onNext() as Void
    {
        _selectedItemIndex = (_selectedItemIndex + 1) % _selectableItems.size();
        updateSelection();
    }

    public function onSelect() as Void
    {
        var selectableItem = findDrawableById(_selectableItems[_selectedItemIndex]);
        switch(selectableItem)
        {
        case instanceof ToggleSwitch:
            var toggleSwitch = selectableItem as ToggleSwitch;
            toggleSwitch.setState(!toggleSwitch.state());
            break;
        }

        WatchUi.requestUpdate();
    }

    private function updateSelection() as Void
    {
        for(var i = 0; i < _selectableItems.size(); i++)
        {
            var selectableItemPrefix = _selectableItems[i];
            var selectableItemMarker = findDrawableById(selectableItemPrefix + "_marker");
            if(selectableItemMarker == null)
            {
                continue;
            }

            selectableItemMarker.setVisible(selectableItemPrefix.equals(_selectableItems[_selectedItemIndex]));
        }

        WatchUi.requestUpdate();
    }
}