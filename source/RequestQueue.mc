import Toybox.Lang;

class RequestQueue
{
    private var _array as Lang.Array<Request> = [];

    function initialize() {}

    function push(item as Request) as Void
    {
        _array.add(item);
    }

    function pop() as Request?
    {
        if(!empty())
        {
            var item = _array[0];
            _array = _array.slice(1, null);
            return item;
        }

        return null;
    }

    function size() as Lang.Number
    {
        return _array.size();
    }

    function empty() as Lang.Boolean
    {
        return size() == 0;
    }

    function clear() as Void
    {
        _array = [];
    }

    function toString() as Lang.String
    {
        return _array.toString();
    }
}