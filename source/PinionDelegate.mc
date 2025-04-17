using Toybox.Lang;

class PinionDelegate
{
    public function onCurrentGearChanged(currentGear as Lang.Number) as Void {}
    public function onParameterRead(parameter as PinionParameterType, value as Lang.Number) as Void {}
    public function onParameterWrite(parameter as PinionParameterType) as Void {}
}