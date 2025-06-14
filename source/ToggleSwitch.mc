import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class ToggleSwitch extends WatchUi.Drawable
{
    private var _state as Lang.Boolean = false;

    function state() as Lang.Boolean { return _state; }
    function setState(state as Lang.Boolean) as Void { _state = state; }

    function initialize(options as
    {
        :identifier as Lang.Object,
        :locX as Lang.Numeric,
        :locY as Lang.Numeric,
        :width as Lang.Numeric,
        :height as Lang.Numeric,
        :visible as Lang.Boolean
    })
    {
        WatchUi.Drawable.initialize(options);
    }

    function draw(dc as Graphics.Dc) as Void
    {
        var radius = height / 2;

        var offset = Math.floor(height / 10);
        offset = offset < 1 ? 1 : offset;

        var dotDiameter = height - (offset * 2);
        var dotRadius = dotDiameter / 2;

        // Lozenge
        if(_state)
        {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        }
        else
        {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRoundedRectangle(locX, locY, width, height, radius);

        // Dot
        var dotX;
        if(_state)
        {
            dotX = (locX + width) - (dotDiameter + offset);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        else
        {
            dotX = locX + offset;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRoundedRectangle(dotX, locY + offset, dotDiameter, dotDiameter, dotRadius);
    }
}