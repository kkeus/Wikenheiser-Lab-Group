/**
 * @file playToneArduino.cpp
 *
 * Wraps around tone Advanced I/O functionality of Arduino.
 *
 * @Copyright 2018-2020 The MathWorks, Inc.
 *
 */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif
    
#include "playToneArduino.h"
    

    void playTone(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
#if defined ARDUINO_ARCH_AVR || defined ARDUINO_ARCH_MBED || defined ARDUINO_ARCH_SAMD 
        uint16_T index = 0, frequency, duration;
        uint8_T pin;
#if DEBUG_FLAG == 2
        uint8_T num=0;
#endif
        
        memcpy(&pin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&frequency, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);
        
        memcpy(&duration, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);
    

        if (frequency == 0 || duration == 0)
        {
            noTone(pin);
        }
        else
        {
            tone(pin, frequency, duration);
        }

        
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID=DEBUGPLAYTONE;
        DebugMsg.args[num++] = pin;
        DebugMsg.args[num++] = frequency;
        DebugMsg.args[num++] = (uint8_T)(frequency >> 8);
        DebugMsg.args[num++] = duration;
        DebugMsg.args[num++] = (uint8_T)(duration >> 8);
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
#endif
    }
    
#ifdef __cplusplus
}
#endif
