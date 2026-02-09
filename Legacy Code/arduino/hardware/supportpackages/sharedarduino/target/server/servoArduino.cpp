/**
 * @file servoArduino.cpp
 *
 * Provides Access to Servo using PWM C SVD layer.
 *
 * @copyright Copyright 2018-2024 The MathWorks, Inc.
 *
 */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#include "servoArduino.h"

#if IO_CUSTOM_SERVO
#include "Servo.h"
#if defined (ESP_H)
    #include "PWMChannel.cpp"
#endif

extern "C"{
    
    Servo *servoArray[IO_DIGITALIO_MODULES_MAX];
    
    void attachServo(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T servoID;
        uint8_T signalPin;
        uint16_T minPulseDuration;
        uint16_T maxPulseDuration;
        uint16_T index = 0;
#if DEBUG_FLAG == 2
        uint8_T num = 0;
#endif
        memcpy(&servoID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&signalPin, &servoID, sizeof(uint8_T));
        
        memcpy(&minPulseDuration, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);
        
        memcpy(&maxPulseDuration, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);
        
        if (NULL == servoArray[servoID]) {
            servoArray[servoID] = new Servo;
        }
        #if !defined(ESP_H)
            servoArray[servoID]->attach(signalPin, minPulseDuration, maxPulseDuration);
        #else
            assignPWMChannel((uint8_T)signalPin);
            uint8_T channel = getPWMChannel(signalPin);
            servoArray[servoID]->attach(signalPin, channel, 0, 180, minPulseDuration, maxPulseDuration);//pin,channel,minangle,maxAngle,minPulseduration,maxPulseDuration
        #endif
#if DEBUG_FLAG == 2
        //adding two different message IDs since the address is 16bit for AVR boards and 32bits for ARM boards. 
        #if defined(ARDUINO_ARCH_SAM) || defined(ARDUINO_ARCH_SAMD) || defined ARDUINO_ARCH_RP2040  || defined(ARDUINO_ARCH_RENESAS_UNO)
        DebugMsg.debugMsgID=DEBUGSERVOATTACH_ARM;
        #elif defined(ESP_H)
        DebugMsg.debugMsgID=DEBUGSERVOATTACH_ESP32;
        #else
        DebugMsg.debugMsgID=DEBUGSERVOATTACH_AVR;
        #endif

        #if defined(ARDUINO_ARCH_AVR) || defined(ARDUINO_ARCH_SAM) || defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_MBED) || defined(ARDUINO_ARCH_RENESAS_UNO)
        DebugMsg.args[num++]=servoID;
        // for 2 different message formation in m side which uses the same argument
        DebugMsg.args[num++]=servoID;
        DebugMsg.args[num++]=signalPin;
        DebugMsg.args[num++]=(uint8_T)minPulseDuration;
        DebugMsg.args[num++]=(uint8_T)(minPulseDuration >> 8);
        DebugMsg.args[num++]=(uint8_T)maxPulseDuration;
        DebugMsg.args[num++]=(uint8_T)(maxPulseDuration >> 8);
        memcpy(&DebugMsg.args[num],&servoArray[servoID],sizeof(servoArray[servoID]));
        num=num+sizeof(servoArray[servoID]);
        DebugMsg.argNum = num;
        #else
        DebugMsg.args[num++]=servoID;
        // for 2 different message formation in m side which uses the same argument
        DebugMsg.args[num++]=servoID;
        DebugMsg.args[num++]=signalPin;
        DebugMsg.args[num++]=channel;
        DebugMsg.args[num++]=(uint8_T)minPulseDuration;
        DebugMsg.args[num++]=(uint8_T)(minPulseDuration >> 8);
        DebugMsg.args[num++]=(uint8_T)maxPulseDuration;
        DebugMsg.args[num++]=(uint8_T)(maxPulseDuration >> 8);
        memcpy(&DebugMsg.args[num],&servoArray[servoID],sizeof(servoArray[servoID]));
        num=num+sizeof(servoArray[servoID]);
        DebugMsg.argNum = num;
        #endif
        sendDebugPackets();
#endif
    }
    
    void detachServo(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T servoID;
        uint16_T index = 0;
#if DEBUG_FLAG == 2
        uint8_T num = 0;
#endif
        memcpy(&servoID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        if (NULL != servoArray[servoID]) {
            servoArray[servoID]->detach();
#if DEBUG_FLAG == 2
            DebugMsg.debugMsgID=DEBUGSERVODETACH;
            DebugMsg.args[num++]=servoID;
            DebugMsg.argNum = num;
            sendDebugPackets();
#endif
        }
        
        
        
        //  Since Servo library does not actually free up the memory by using
        //  delete, any memory that has been allocated before will not be cleaned
        //  up in our code. The same memory address will be used for any servo
        //  object created on the same pin
        //
        //         if (NULL != servoArray[servoID]) {
        //             delete servoArray[servoID];
        //             servoArray[servoID] = NULL;
        //             debugPrint(MSG_SERVO_DELETE, servoID, servoID);
        //         }
    }
    
    void readPosition(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T servoID;
        uint8_T angle;
        uint16_T index = 0;
#if DEBUG_FLAG == 2
        uint8_T num = 0;
#endif
        memcpy(&servoID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        angle = servoArray[servoID]->read();
        payloadBufferTx[(*peripheralDataSizeResponse)++] = angle;
        
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID=DEBUGSERVOREAD;
        DebugMsg.args[num++]=servoID;
        DebugMsg.args[num++]=angle;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
    }
    
    void writePosition(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T servoID;
        uint8_T angle;
        uint16_T index = 0;
#if DEBUG_FLAG == 2
        uint8_T num = 0;
#endif
        memcpy(&servoID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&angle, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        servoArray[servoID]->write(angle);
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID=DEBUGSERVOWRITE;
        DebugMsg.args[num++]=servoID;
        DebugMsg.args[num++]=angle;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        
    }
    
}


#endif //IO_CUSTOM_SERVO
