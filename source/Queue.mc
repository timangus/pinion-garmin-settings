import Toybox.Lang;

class Queue
{
    private var array as Lang.Array = [];

    function initialize() {}

    function push(item)
    {
        array.add(item);
    }

    function pop() as Lang.Object?
    {
        if(!empty())
        {
            var item = array[0];
            array = array.slice(1, null);
            return item;
        }

        return null;
    }

    function size() as Lang.Number
    {
        return array.size();
    }

    function empty() as Lang.Boolean
    {
        return size() == 0;
    }

    function clear()
    {
        array = [];
    }

    function toString() as Lang.String
    {
        return array.toString();
    }
}