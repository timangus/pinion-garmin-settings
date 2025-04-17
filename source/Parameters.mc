using Toybox.Lang;

enum PinionRequestType
{
    PINION_ERR      = 0x00,
    PINION_READ     = 0x01,
    PINION_REPLY    = 0x02,
    PINION_WRITE    = 0x03,
    PINION_ACK      = 0x04
}

enum PinionParameterType
{
    HARDWARE_VERSION,
    FIRMWARE_VERSION,
    BOOTLOADER_VERSION,
    SERIAL_NUMBER,

    MOUNTING_ANGLE,
    REAR_TEETH,
    FRONT_TEETH,
    WHEEL_CIRCUMFERENCE,
    POWER_SUPPLY,
    CAN_BUS,
    DISPLAY,
    SPEED_SENSOR_TYPE,
    NUMBER_OF_MAGNETS,
    REVERSE_TRIGGER_MAGNETS,

    CURRENT_GEAR,
    BATTERY_LEVEL,

    AUTO_START_GEAR,
    PRE_SELECT_CADENCE,
    START_SELECT,
    PRE_SELECT,

    NUMBER_OF_GEARS,

    // Don't set this manually, it's done automatically
    HIDDEN_SETTINGS_ENABLE,
}

const PINION_PARAMETERS =
{
    HARDWARE_VERSION =>
    {
        :address => [0x09, 0x10, 0x00]b,
        :length => 4
    },
    SERIAL_NUMBER =>
    {
        :address => [0x18, 0x10, 0x04]b,
        :length => 4
    },
    WHEEL_CIRCUMFERENCE =>
    {
        :address => [0x02, 0x34, 0x01]b,
        :length => 2,
        :hidden => true
    },
    CURRENT_GEAR =>
    {
        :address => [0x01, 0x61, 0x02]b,
        :length => 1
    },
    BATTERY_LEVEL =>
    {
        :address => [0x64, 0x61, 0x01]b,
        :length => 2
    },
    AUTO_START_GEAR =>
    {
        :address => [0x12, 0x25, 0x02]b,
        :length => 1
    },
    PRE_SELECT =>
    {
        :address => [0x13, 0x25, 0x00]b,
        :length => 1
    },
    HIDDEN_SETTINGS_ENABLE =>
    {
        :address => [0x00, 0x30, 0x04]b,
        :length => 4
    },
} as Lang.Dictionary<PinionParameterType, Lang.Dictionary>;

class UnknownParameterException extends Lang.Exception
{
    private var _parameter as PinionParameterType;

    public function initialize(parameter as PinionParameterType)
    {
        Lang.Exception.initialize();
        _parameter = parameter;
    }

    public function getErrorMessage() as Lang.String?
    {
        return "Unknown Pinion Parameter " + _parameter;
    }
}