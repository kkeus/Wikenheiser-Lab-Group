//   Copyright 2017-2021 The MathWorks, Inc.
#include "boardInit.h"

void boardInit()
{
    // Serial Pins of Arduino Due doesn't work if the pins are configured using PinMode
#if defined(ARDUINO_ARCH_SAM) && defined(IO_STANDARD_SCI)
    uint8_T sciPinStart = 14; // Pins 14-19  are used for Serial communications
    uint8_T sciPinEnd = 19;
    for( uint8_T i = 2; i < sciPinStart; i++)
    {
        pinMode(i, INPUT);
    }
    for( uint8_T i = (sciPinEnd+1); i < IO_DIGITALIO_MODULES_MAX; i++)
    {
        pinMode(i, INPUT);
    }
#elif defined(ARDUINO_SAMD_MKRZERO)
    for( uint8_T i = 0; i < IO_ANALOGINPUT_MODULES_MAX; i++)
    {
        pinMode(i, INPUT);
    }
#elif defined(ESP_H)
	for( uint8_T i = 2; i < IO_DIGITALIO_MODULES_MAX; i++)
    {
		//Configure only 2, 4-5, 12-19, 21-23, 25-27, 32-39
        switch(i)
		{
		    case 2:
		    case 4 ... 5:
		    case 12 ... 19:
		    case 21 ... 23:
            case 25 ... 27:
            case 32 ... 39:
				pinMode(i, INPUT);
			    break;
		}
    }
#else
    for( uint8_T i = 2; i < IO_DIGITALIO_MODULES_MAX; i++)
    {
        pinMode(i, INPUT);
    }
#endif
}