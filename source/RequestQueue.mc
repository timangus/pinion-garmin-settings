import Toybox.Lang;

class RequestQueue
{
    private var array as Lang.Array<Request> = [];

    function initialize() {}

    function push(item as Request) as Void
    {
        array.add(item);
    }

    function pop() as Request?
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

    function clear() as Void
    {
        array = [];
    }

    function toString() as Lang.String
    {
        return array.toString();
    }
}