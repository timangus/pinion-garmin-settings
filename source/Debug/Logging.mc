using Toybox.Lang;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Activity;

module Debug
{
    var _firstMessageLogged as Lang.Boolean = false;

    function _timeString() as Lang.String
    {
        var string = "";

        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        if(!_firstMessageLogged)
        {
            var date = Lang.format("$1$/$2$/$3$",
            [
                info.year.format("%04u"),
                (info.month as Lang.Number).format("%02u"),
                info.day.format("%02u")
            ]);

            string += "******** Log Start " + date + " " + Activity.getProfileInfo().name + "\n";
            _firstMessageLogged = true;
        }

        var time = Lang.format("$1$:$2$:$3$",
        [
            info.hour.format("%02u"),
            info.min.format("%02u"),
            info.sec.format("%02u")
        ]);

        string += time;
        return string;
    }

    function log(text as Lang.String) as Void
    {
        System.println(_timeString() + " " + text);
    }

    function error(text as Lang.String) as Void
    {
        System.println(_timeString() + " ERROR: " + text);
        System.error(text);
    }

    function assert(condition as Lang.Boolean, message as Lang.String) as Void
    {
        if(!condition) { error("Assertion failed: " + message); }
    }
}