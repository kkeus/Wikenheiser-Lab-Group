/* Copyright 2017-2019 The MathWorks, Inc. */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif
#include "MW_digitalIO.h"
#include "IO_peripheralInclude.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    /* Called for each GPIO pin */
    MW_Handle_Type MW_digitalIO_open(uint32_T pin, uint8_T direction)
    {
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        if((uint8_T)pin <= IO_DIGITALIO_MODULES_MAX)
        {
            if (direction == (uint8_T)0)
            {
                pinMode(pin, INPUT);
            }
            else if (direction == (uint8_T)1)
            {
                pinMode(pin, OUTPUT);
            }
            else if(direction == (uint8_T)2)
            {
                pinMode(pin, INPUT_PULLUP);
            }
#if DEBUG_FLAG == 2
            DebugMsg.debugMsgID= DEBUGOPENDIGITALPIN;
            DebugMsg.args[index++]=(uint8_T)pin;
            DebugMsg.args[index++]=(uint8_T)direction;
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
            return (MW_Handle_Type)(pin+1);
        }
        else
            return 0;
    }
    
    /* Read the logical state of a GPIO input pin */
    boolean_T MW_digitalIO_read(MW_Handle_Type DigitalIOPinHandle)
    {
        boolean_T ret;
        uint8_T pin;
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        pin = *((uint8_T*)(&DigitalIOPinHandle)) - 1;
        ret = (digitalRead((uint8_T)pin) == HIGH) ? 1:0;
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID= DEBUGREADDIGITALPIN;
        DebugMsg.args[index++]=pin;
        DebugMsg.args[index++]=(uint8_T)ret;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        return ret;
    }
    
    /* Set the logical state of a GPIO output pin */
    void MW_digitalIO_write(MW_Handle_Type DigitalIOPinHandle, boolean_T value)
    {
        uint8_T pin;
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        pin = *((uint8_T*)(&DigitalIOPinHandle)) - 1;
        if (value)
        {
            digitalWrite((uint8_T)pin, HIGH);
        }
        else
        {
            digitalWrite((uint8_T)pin, LOW);
        }
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
        DebugMsg.args[index++]=pin;
        DebugMsg.args[index++]=(uint8_T)value;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
    }
    
    /* Release resources used */
    void MW_digitalIO_close(MW_Handle_Type DigitalIOPinHandle)
    {
        uint8_T pin;
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        pin = *((uint8_T*)(&DigitalIOPinHandle)) - 1;
        /* set the pin to default state */
        pinMode(pin, INPUT);
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID= DEBUGUNCONFIGUREDIGITALPIN;
        DebugMsg.args[index++]=pin;
		/*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
        DebugMsg.args[index++]=(uint8_T)0;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
    }
    
#ifdef __cplusplus
}
#endif
