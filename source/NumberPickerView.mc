using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class NumberFactory extends WatchUi.PickerFactory
{
    private var _min as Lang.Number;
    private var _max as Lang.Number;
    private var _increment as Lang.Number;

    public function initialize(min as Lang.Number, max as Lang.Number, increment as Lang.Number)
    {
        PickerFactory.initialize();

        _min = min;
        _max = max;
        _increment = increment;
    }

    public function getIndex(value as Lang.Number) as Lang.Number
    {
        if(value < _min || value > _max) { return -1; }
        if(((value - _min) % _increment) != 0) { return -1; }
        return (value - _min) / _increment;
    }

    public function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable?
    {
        var value = getValue(index);
        var text = value != null ? value.toString() : "-";

        return new WatchUi.Text(
        {
            :text => text,
            :color => Graphics.COLOR_WHITE,
            :font => text.length() > 3 ? Graphics.FONT_NUMBER_MILD : Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    public function getValue(index as Lang.Number) as Lang.Object? { return _min + (index * _increment); }
    public function getSize() as Lang.Number { return (_max - _min) / _increment + 1; }
}

class NumberPickerView extends WatchUi.Picker
{
    public function initialize(title as Lang.String,
        min as Lang.Number, max as Lang.Number,
        increment as Lang.Number, initial as Lang.Number)
    {
        var text = new WatchUi.Text(
        {
            :text => title,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER,
            :color => Graphics.COLOR_WHITE
        });
        var numberFactory = new NumberFactory(min, max, increment);
        var index = numberFactory.getIndex(initial);

        WatchUi.Picker.initialize({:title => text, :pattern => [numberFactory], :defaults => [index]});
    }
}