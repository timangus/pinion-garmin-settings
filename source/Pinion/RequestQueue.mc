import Toybox.Lang;

module Pinion
{
    class RequestQueue
    {
        private var _array as Lang.Array<Request> = [];

        public function initialize() {}

        public function push(item as Request) as Void
        {
            _array.add(item);
        }

        public function skip(item as Request) as Void
        {
            var newArray = [];
            newArray.add(item);
            newArray.addAll(_array);
            _array = newArray;
        }

        public function skipAll(items as Lang.Array<Request>) as Void
        {
            var newArray = [];
            newArray.addAll(items);
            newArray.addAll(_array);
            _array = newArray;
        }

        public function pop() as Request?
        {
            if(!empty())
            {
                var item = _array[0];
                _array = _array.slice(1, null);
                return item;
            }

            return null;
        }

        public function size() as Lang.Number
        {
            return _array.size();
        }

        public function empty() as Lang.Boolean
        {
            return size() == 0;
        }

        public function clear() as Void
        {
            _array = [];
        }

        public function toString() as Lang.String
        {
            return _array.toString();
        }
    }
}