using Toybox.Lang;

module Pinion
{
    enum ParameterType
    {
        HARDWARE_VERSION        = "HARDWARE_VERSION",
        FIRMWARE_VERSION        = "FIRMWARE_VERSION",
        BOOTLOADER_VERSION      = "BOOTLOADER_VERSION",
        SERIAL_NUMBER           = "SERIAL_NUMBER",

        MOUNTING_ANGLE          = "MOUNTING_ANGLE",
        REAR_TEETH              = "REAR_TEETH",
        FRONT_TEETH             = "FRONT_TEETH",
        WHEEL_CIRCUMFERENCE     = "WHEEL_CIRCUMFERENCE",
        POWER_SUPPLY            = "POWER_SUPPLY",
        CAN_BUS                 = "CAN_BUS",
        DISPLAY                 = "DISPLAY",
        SPEED_SENSOR_TYPE       = "SPEED_SENSOR_TYPE",
        NUMBER_OF_MAGNETS       = "NUMBER_OF_MAGNETS",

        REVERSE_TRIGGER_MAPPING = "REVERSE_TRIGGER_MAPPING",

        CURRENT_GEAR            = "CURRENT_GEAR",
        BATTERY_LEVEL           = "BATTERY_LEVEL",

        AUTO_START_GEAR         = "AUTO_START_GEAR",
        PRE_SELECT_CADENCE      = "PRE_SELECT_CADENCE",
        START_SELECT            = "START_SELECT",
        PRE_SELECT              = "PRE_SELECT",

        NUMBER_OF_GEARS         = "NUMBER_OF_GEARS",

        NUMBER_OF_ERRORS        = "NUMBER_OF_ERRORS",
        CLEAR_ERRORS            = "CLEAR_ERRORS",
        ERROR_LOG_TYPE          = "ERROR_LOG_TYPE",
        ERROR_LOG               = "ERROR_LOG",

        NUMBER_OF_ACTIVE_ERRORS = "NUMBER_OF_ACTIVE_ERRORS",
        GET_ACTIVE_ERROR        = "GET_ACTIVE_ERROR",
        ACTIVE_ERROR            = "ACTIVE_ERROR",

        // Don't set this manually, it's done automatically
        HIDDEN_SETTINGS_ENABLE  = "HIDDEN_SETTINGS_ENABLE",
    }

    const PARAMETERS =
    {
        HARDWARE_VERSION =>         { :address => [0x09, 0x10, 0x00]b,  :length => 4 },
        FIRMWARE_VERSION =>         { :address => [0x56, 0x1f, 0x01]b,  :length => 4 },
        BOOTLOADER_VERSION =>       { :address => [0x56, 0x1f, 0x02]b,  :length => 4 },
        SERIAL_NUMBER =>            { :address => [0x18, 0x10, 0x04]b,  :length => 4 },

        MOUNTING_ANGLE =>           { :address => [0x25, 0x25, 0x00]b,  :length => 2,   :minmax => [0, 359],        :hidden => true },
        REAR_TEETH =>               { :address => [0x02, 0x34, 0x02]b,  :length => 1,   :minmax => [15, 60],        :hidden => true },
        FRONT_TEETH =>              { :address => [0x02, 0x34, 0x03]b,  :length => 1,   :minmax => [15, 60],        :hidden => true },
        WHEEL_CIRCUMFERENCE =>      { :address => [0x02, 0x34, 0x01]b,  :length => 2,   :minmax => [1000, 3000],    :hidden => true },
        POWER_SUPPLY =>             { :address => [0x00, 0x34, 0x02]b,  :length => 1,   :values => [1, 3, 4],       :hidden => true },
        CAN_BUS =>                  { :address => [0x00, 0x34, 0x05]b,  :length => 1,   :values => [0, 1],          :hidden => true },
        DISPLAY =>                  { :address => [0x00, 0x34, 0x04]b,  :length => 1,   :values => [0, 1],          :hidden => true },
        SPEED_SENSOR_TYPE =>        { :address => [0x00, 0x34, 0x01]b,  :length => 1,   :values => [0, 1, 3],       :hidden => true },
        NUMBER_OF_MAGNETS =>        { :address => [0x00, 0x30, 0x01]b,  :length => 2,   :minmax => [1, 8],          :hidden => true },

        REVERSE_TRIGGER_MAPPING =>  { :address => [0x50, 0x25, 0x00]b,  :length => 1,   :values => [1, 2] },

        CURRENT_GEAR =>             { :address => [0x01, 0x61, 0x02]b,  :length => 1 },
        BATTERY_LEVEL =>            { :address => [0x64, 0x61, 0x01]b,  :length => 2 },

        AUTO_START_GEAR =>          { :address => [0x12, 0x25, 0x02]b,  :length => 1,   :minmax => [1, 12] },
        PRE_SELECT_CADENCE =>       { :address => [0x11, 0x25, 0x00]b,  :length => 1,   :minmax => [40, 100] },
        START_SELECT =>             { :address => [0x12, 0x25, 0x01]b,  :length => 1,   :values => [0, 1] },
        PRE_SELECT =>               { :address => [0x13, 0x25, 0x00]b,  :length => 1,   :values => [0, 1] },

        NUMBER_OF_GEARS =>          { :address => [0x00, 0x25, 0x00]b,  :length => 1 },

        NUMBER_OF_ERRORS =>         { :address => [0x02, 0x31, 0x01]b,  :length => 4 },
        CLEAR_ERRORS =>             { :address => [0x02, 0x31, 0x02]b,  :length => 1,   :values => [0, 1] },
        ERROR_LOG_TYPE =>           { :address => [0x05, 0x31, 0x05]b,  :length => 1,   :values => [0, 1, 2] },
        ERROR_LOG =>                { :address => [0x05, 0x31, 0x01]b },

        NUMBER_OF_ACTIVE_ERRORS =>  { :address => [0x04, 0x31, 0x01]b,  :length => 2 },
        GET_ACTIVE_ERROR =>         { :address => [0x04, 0x31, 0x02]b,  :length => 2,   :minmax => [0, 0xffff] },
        ACTIVE_ERROR =>             { :address => [0x04, 0x31, 0x03]b,  :length => 2 },

        HIDDEN_SETTINGS_ENABLE =>   { :address => [0x00, 0x30, 0x04]b,  :length => 4,   :values => [0, 0x56a93c03] },
    } as Lang.Dictionary<ParameterType, Lang.Dictionary>;

    class UnknownParameterException extends Lang.Exception
    {
        private var _parameter as ParameterType;

        public function initialize(parameter as ParameterType)
        {
            Lang.Exception.initialize();
            _parameter = parameter;
        }

        public function getErrorMessage() as Lang.String?
        {
            return "Unknown Pinion Parameter " + _parameter;
        }
    }

    class ParameterNotWritableException extends Lang.Exception
    {
        private var _parameter as ParameterType;

        public function initialize(parameter as ParameterType)
        {
            Lang.Exception.initialize();
            _parameter = parameter;
        }

        public function getErrorMessage() as Lang.String?
        {
            return "Pinion Parameter " + _parameter + " is not writable";
        }
    }
}