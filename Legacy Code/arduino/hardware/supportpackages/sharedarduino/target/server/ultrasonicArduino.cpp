/**
 * @file ultrasonicArduino.cpp
 *
 * Provides Access to Ultrasonic Sensor.
 *
 * @Copyright 2018-2019 The MathWorks, Inc.
 *
 */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#include "ultrasonicArduino.h"

#if IO_CUSTOM_ULTRASONIC

extern "C" {
// Attach an Ultrasonic Sensor to Arduino
    void attachUltrasonicSensor(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T trigger, echo;
        uint16_T index = 0;
#if DEBUG_FLAG == 2
        uint8_T num =0;
#endif
        memcpy(&trigger, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&echo, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGCREATEULTRASONIC;
        DebugMsg.args[num++]=trigger;
        DebugMsg.args[num++]=echo;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        pinMode(trigger, OUTPUT);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
        DebugMsg.args[num++]=(uint8_T)1;
        DebugMsg.argNum = num;
        sendDebugPackets();       
#endif
        
        if(echo != trigger)
        {
            pinMode(echo, INPUT);
#if DEBUG_FLAG == 2
            num=0;
            DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
            DebugMsg.args[num++]=echo;
            /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
            DebugMsg.args[num++]=(uint8_T)0;
            DebugMsg.argNum = num;
            sendDebugPackets();           
#endif
        }
    }
    
// Detach Ultrasonic Sensor
    void detachUltrasonicSensor(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T trigger, echo;
        uint16_T index = 0;
#if DEBUG_FLAG == 2
        uint8_T num =0;
#endif
        memcpy(&trigger, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&echo, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGDELETEULTRASONIC;
        DebugMsg.argNum = num;
        sendDebugPackets();        
#endif
        pinMode(trigger, OUTPUT);
        //debugPrint(MSG_ULTRASONIC_PIN_MODE, trigger, "OUTPUT");
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
        DebugMsg.args[num++]=(uint8_T)1;
        DebugMsg.argNum = num;
        sendDebugPackets();        
#endif
        digitalWrite(trigger, 0);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        DebugMsg.args[num++]=0;
        DebugMsg.argNum = num;
        sendDebugPackets();        
#endif
        pinMode(trigger, INPUT);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
        DebugMsg.args[num++]=(uint8_T)0;
        DebugMsg.argNum = num;
        sendDebugPackets();       
#endif 
        if(echo != trigger)
        {
            pinMode(echo, OUTPUT);
#if DEBUG_FLAG == 2
            num=0;
            DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
            DebugMsg.args[num++]=echo;
            /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
            DebugMsg.args[num++]=(uint8_T)1;
            DebugMsg.argNum = num;
            sendDebugPackets();            
#endif
            
            digitalWrite(echo, 0);
#if DEBUG_FLAG == 2
            num=0;
            DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
            DebugMsg.args[num++]=echo;
            DebugMsg.args[num++]=0;
            DebugMsg.argNum = num;
            sendDebugPackets();           
#endif 
            
            pinMode(echo, INPUT);
#if DEBUG_FLAG == 2
            num=0;
            DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
            DebugMsg.args[num++]=echo;
            /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
            DebugMsg.args[num++]=(uint8_T)0;
            DebugMsg.argNum = num;
            sendDebugPackets();            
#endif  
        }
    }
    
// Read the Distance of object from Ultrasonic Sensor
    void readTravelTime(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T trigger, echo;
        uint16_T index = 0;
        uint32_T timeOut;
        
        memcpy(&trigger, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&echo, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&timeOut, &payloadBufferRx[index], 4);
        index += sizeof(uint32_T);
        
        pinMode(trigger, OUTPUT);

        // Find out the time taken by the sound wave
        // Make trigger pin low for 2us
        digitalWrite(trigger, LOW);

        delayMicroseconds(2);
        // Make trigger pin high for >10us

        digitalWrite(trigger, HIGH);
        delayMicroseconds(15);
        // Make trigger pin low
        digitalWrite(trigger, LOW);
        
        // Get the echo pin ready
        pinMode(echo, INPUT);
        // Start looking for a pulse in the Echo pin and time it.
        uint32_T duration = pulseIn(echo, HIGH, timeOut);
        
        // Calculate the distance
        // Converting time to distance 1s -> 344m => 10^-6s -> 10^-6*344m => 1us -> 1 / 29.06 cm;
        // Calculate for one way travel => /2
        uint32_T value = duration / 29 / 2;

        uint8_T resultSize = 4;
        byte result [resultSize];
        result[0] = (uint8_T)(duration & 0x000000ffUL);
        result[1] = (uint8_T)((duration & 0x0000ff00UL) >> 8);
        result[2] = (uint8_T)((duration & 0x00ff0000UL) >> 16);
        result[3] = (uint8_T)((duration & 0xff000000UL) >> 24);
        
        memcpy(&payloadBufferTx[(*peripheralDataSizeResponse)], result, resultSize);
        (*peripheralDataSizeResponse) += resultSize;
#if DEBUG_FLAG == 2
        uint8_T num=0;

        num =0;
        DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
        DebugMsg.args[num++]=(uint8_T)1;
        DebugMsg.argNum = num;
        sendDebugPackets();        

        num = 0;
        DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        DebugMsg.args[num++]=LOW;
        DebugMsg.argNum = num;
        sendDebugPackets();        

        num = 0;
        DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        DebugMsg.args[num++]=HIGH;
        DebugMsg.argNum = num;
        sendDebugPackets();

        num = 0;
        DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
        DebugMsg.args[num++]=trigger;
        DebugMsg.args[num++]=LOW;
        DebugMsg.argNum = num;
        sendDebugPackets();
        num = 0;
        DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
        DebugMsg.args[num++]=echo;
        /*IOServer debug logic interprest 0 as INPUT, 1 as HIGH, and 2 as INPUT_PULLUP*/
        DebugMsg.args[num++]=(uint8_T)0;
        DebugMsg.argNum = num;
        sendDebugPackets();
        num=0;
        DebugMsg.debugMsgID = DEBUGPULSEIN;
        DebugMsg.args[num++]=echo;
        DebugMsg.args[num++]=HIGH;
        DebugMsg.args[num++]=(uint8_T)timeOut;
        DebugMsg.args[num++]=(uint8_T)((timeOut & 0x0000ff00UL) >> 8);
        DebugMsg.args[num++]=(uint8_T)((timeOut & 0x00ff0000UL) >> 16);
        DebugMsg.args[num++]=(uint8_T)((timeOut & 0xff000000UL) >> 24);
        DebugMsg.args[num++]=(uint8_T)duration;
        DebugMsg.args[num++]=(uint8_T)((duration & 0x0000ff00UL) >> 8);
        DebugMsg.args[num++]=(uint8_T)((duration & 0x00ff0000UL) >> 16);
        DebugMsg.args[num++]=(uint8_T)((duration & 0xff000000UL) >> 24);
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
    }
    
}

#endif  //IO_CUSTOM_ULTRASONIC