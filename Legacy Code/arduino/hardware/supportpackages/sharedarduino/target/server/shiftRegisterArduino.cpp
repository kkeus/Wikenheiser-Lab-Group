/**
 * @file shiftRegisterArduino.cpp
 *
 * Provides Access to Shift Register.
 *
 * @Copyright 2018-2019 The MathWorks, Inc.
 *
 */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#include "shiftRegisterArduino.h"

#if IO_CUSTOM_SHIFTREGISTER

extern "C"
{
    
#define MW_74HC165 1
#define MW_74HC595 2
#define MW_74HC164 3
    
    void write74HC595(uint8_T dataPin, uint8_T clockPin, uint8_T latchPin, uint8_T numBytes, uint8_T* value)
    {
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        
        digitalWrite(latchPin,LOW);
#if DEBUG_FLAG == 2
        index=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[index++]=latchPin;
        DebugMsg.args[index++]=LOW;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        
        // MSBFIRST
        for(int iLoop = numBytes-1; iLoop >= 0; iLoop--)
        {
            shiftOut(dataPin, clockPin, MSBFIRST, value[iLoop]);
#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID = DEBUGSHIFTOUT;
            DebugMsg.args[index++]=dataPin;
            DebugMsg.args[index++]=clockPin;
            DebugMsg.args[index++]=MSBFIRST;
            DebugMsg.args[index++]=value[iLoop];
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
        }
        digitalWrite(latchPin,HIGH);
#if DEBUG_FLAG == 2
        index=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[index++]=latchPin;
        DebugMsg.args[index++]=HIGH;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        
    }
    
    void write74HC164(uint8_T dataPin, uint8_T clockPin, uint8_T numBytes, uint8_T* value)
    {
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        
        for(size_t iLoop = 0; iLoop < numBytes; ++iLoop)
        {
            shiftOut(dataPin, clockPin, MSBFIRST, value[iLoop]);
#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID = DEBUGSHIFTOUT;
            DebugMsg.args[index++]=dataPin;
            DebugMsg.args[index++]=clockPin;
            DebugMsg.args[index++]=MSBFIRST;
            DebugMsg.args[index++]=value[iLoop];
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
        }
    }
    
    /* Write to Shift Register (Arduino to SIPO) */
    void writeShiftRegister(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
#if DEBUG_FLAG == 2
        uint8_T num=0;
#endif
        uint8_T model, dataPin, clockPin;
        
        uint16_T index = 0;
        
        memcpy(&model, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&dataPin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&clockPin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        switch(model){
            case MW_74HC595: {
                uint8_T latchPin, isReset, numBytes;
                
                memcpy(&latchPin, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                memcpy(&isReset, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                if(isReset){
                    uint8_T resetPin;
                    
                    memcpy(&resetPin, &payloadBufferRx[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                    digitalWrite(resetPin,HIGH);
#if DEBUG_FLAG == 2
                    num=0;
                    DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
                    DebugMsg.args[num++]=resetPin;
                    DebugMsg.args[num++]=HIGH;
                    DebugMsg.argNum = num;
                    sendDebugPackets();
#endif
                    
                    
                    memcpy(&numBytes, &payloadBufferRx[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                }
                else{
                    memcpy(&numBytes, &payloadBufferRx[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                }
                write74HC595(dataPin, clockPin, latchPin, numBytes, &payloadBufferRx[index]);
                break;
            }
            case MW_74HC164: {
                uint8_T isReset;
                
                memcpy(&isReset, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                uint8_T numBytes;
                
                if(isReset){
                    uint8_T resetPin;
                    
                    memcpy(&resetPin, &payloadBufferRx[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                    digitalWrite(resetPin,HIGH);
#if DEBUG_FLAG == 2
                    num=0;
                    DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
                    DebugMsg.args[num++]=resetPin;
                    DebugMsg.args[num++]=HIGH;
                    DebugMsg.argNum = num;
                    sendDebugPackets();
#endif
                    
                    
                    memcpy(&numBytes, &payloadBufferRx[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                }
                else{
                    memcpy(&numBytes, &payloadBufferRx[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                }
                write74HC164(dataPin, clockPin, numBytes, &payloadBufferRx[index]);
                break;
            }
            default:{
                // return -1 if wrong model received
                return;
            }
        }
    }
    
    void read74HC165(uint8_T dataPin, uint8_T clockPin, uint8_T loadPin, uint8_T cePin, uint8_T numBytes, uint8_T* value)
    {
#if DEBUG_FLAG == 2
        uint8_T num=0;
#endif
        digitalWrite(clockPin, HIGH); // PL HIGH and CP HIGH makes DS output D7 first
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[num++]=clockPin;
        DebugMsg.args[num++]=HIGH;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN_LOADPIN_CEPIN;
        DebugMsg.args[num++]=loadPin;
        DebugMsg.args[num++]=LOW;
        DebugMsg.args[num++]=loadPin;
        DebugMsg.args[num++]=HIGH;
        DebugMsg.args[num++]=cePin;
        DebugMsg.args[num++]=LOW;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        digitalWrite(loadPin, LOW);
        
        delayMicroseconds(5); // Requires a delay here according to the datasheet timing diagram
        digitalWrite(loadPin, HIGH);
        delayMicroseconds(5);
        
        digitalWrite(cePin, LOW); // Enable the clock
        for(size_t iLoop = 0; iLoop < numBytes; ++iLoop){
            value[iLoop] = shiftIn(dataPin, clockPin, MSBFIRST);
#if DEBUG_FLAG == 2
            num=0;
            DebugMsg.debugMsgID = DEBUGSHIFTIN;
            DebugMsg.args[num++]=dataPin;
            DebugMsg.args[num++]=clockPin;
            DebugMsg.args[num++]=MSBFIRST;
            DebugMsg.args[num++]=value[iLoop];
            DebugMsg.argNum = num;
            sendDebugPackets();
#endif
        }
        digitalWrite(cePin, HIGH); // Disable the clock
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[num++]=cePin;
        DebugMsg.args[num++]=HIGH;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
    }
    
    /* Read from Shift Register (PISO to Arduino) */
    void readShiftRegister(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T model, dataPin, clockPin;
        uint8_T numBytes;
        uint8_T* value;
        
        uint16_T index = 0;
        
        memcpy(&model, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&dataPin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&clockPin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        switch(model){
            case MW_74HC165: {
                uint8_T loadPin, cePin;
                
                memcpy(&loadPin, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                memcpy(&cePin, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                memcpy(&numBytes, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                value = new uint8_T [numBytes];
                read74HC165(dataPin, clockPin, loadPin, cePin, numBytes, value);
                break;
            }
            default:{
                // return -1 if wrong model received
                return;
            }
        }
        
        memcpy(&payloadBufferTx[(*peripheralDataSizeResponse)], value, numBytes);
        (*peripheralDataSizeResponse) += numBytes;
        
        delete [] value;
        value = NULL;
    }
    
    void reset74HC595(uint8_T latchPin, uint8_T resetPin){
        // shift register output reset when MR/Reset low with rising edge STCP/Latch.
#if DEBUG_FLAG == 2
        uint8_T num=0;
#endif
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[num++]=resetPin;
        DebugMsg.args[num++]=LOW;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        digitalWrite(resetPin,LOW);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[num++]=latchPin;
        DebugMsg.args[num++]=LOW;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        digitalWrite(latchPin,LOW);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[num++]=latchPin;
        DebugMsg.args[num++]=HIGH;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        digitalWrite(latchPin,HIGH);
    }
    
    void reset74HC164(uint8_T resetPin){
#if DEBUG_FLAG == 2
        uint8_T num=0;
#endif
        // according to datasheet, LOW level on MR/Reset clears the registers asynchronously, forcing all outputs LOW
        digitalWrite(resetPin,LOW);
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGSHIFTREGISTERWRITE;
        DebugMsg.args[num++]=resetPin;
        DebugMsg.args[num++]=LOW;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
    }
    
    /* Reset the Shift Register */
    void resetShiftRegister(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T model, dataPin, clockPin;
        
        uint16_T index = 0;
        
        memcpy(&model, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&dataPin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        memcpy(&clockPin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);
        
        switch(model){
            case MW_74HC595: {
                uint8_T latchPin, isReset, resetPin;
                
                memcpy(&latchPin, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                memcpy(&isReset, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                memcpy(&resetPin, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                reset74HC595(latchPin, resetPin);
                break;
            }
            case MW_74HC164: {
                uint8_T isReset, resetPin;
                
                memcpy(&isReset, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                memcpy(&resetPin, &payloadBufferRx[index], sizeof(uint8_T));
                index += sizeof(uint8_T);
                
                reset74HC164(resetPin);
                break;
            }
            default:{
                // return -1 if wrong model received
                return;
            }
        }
    }
}   // extern "C"

#endif //IO_CUSTOM_SHIFTREGISTER