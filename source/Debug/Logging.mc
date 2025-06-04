import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

module Debug
{
    var _firstMessageLogged as Lang.Boolean = false;

    function log(text as Lang.String) as Void
    {
        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var time = Lang.format("$1$:$2$:$3$",
        [
            info.hour.format("%02u"),
            info.min.format("%02u"),
            info.sec.format("%02u")
        ]);

        if(!_firstMessageLogged)
        {
            var date = Lang.format("$1$/$2$/$3$",
            [
                info.year.format("%04u"),
                (info.month as Lang.Number).format("%02u"),
                info.day.format("%02u")
            ]);
            System.println("******** Log Start " + date);
            _firstMessageLogged = true;
        }

        System.println(time + " " + text);
    }
}