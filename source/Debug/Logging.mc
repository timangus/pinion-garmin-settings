import Toybox.Lang;
import Toybox.System;

module Debug
{
    function log(text as Lang.String) as Void
    {
        System.println(text);
    }
}