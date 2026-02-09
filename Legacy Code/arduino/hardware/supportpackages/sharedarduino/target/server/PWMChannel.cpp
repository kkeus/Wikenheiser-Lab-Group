/**
 * @file PWMChannel.cpp
 *
 * Provides channel assignement for PWM and Servo on ESP32 hardware.
 *
 * @copyright Copyright 2018-2022 The MathWorks, Inc.
 *
 */

#include "IO_include.h"
#include "MW_PWM.h"
#include "IO_peripheralInclude.h"

#if defined (ESP_H)
  static uint16_T PWMFrequency = 1000; // this variable is used to define the time period
  static uint8_T PWMResolution = 8; // this will define the resolution of the signal which is 8 in this case
  static uint8_T PinChannelMap[IO_PWM_MODULES_MAX]; //ADD correct PWM ARRAY SIZE BASED On size of MAP
  static bool PWMChannels[16] = {0};
  static const uint8_T numChannels = 16;


static void assignPWMChannel(uint8_T pin)
{
    for(int i = 0; i < numChannels; ++i)
    {
        if(PWMChannels[i] == 0)
        {
            PinChannelMap[pin] = i;
            PWMChannels[i] = 1;
            break;
        }

        /* No channel is available */
        //Add error or debug print if possible
    }
}

static uint8_T getPWMChannel(uint8_T pin)
{
    uint8_T channel = PinChannelMap[pin];
    return channel;
}

#endif