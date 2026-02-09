/**
 * @file rotaryEncoderArduino.cpp
 *
 * Provides Access to Rotary Encoder.
 *
 * @Copyright 2018-2024 The MathWorks, Inc.
 *
 */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#include "rotaryEncoderArduino.h"
#include "limits.h"

#if IO_CUSTOM_ROTARYENCODER

#define MAX_ENCODER 2
#define SpeedMeasureInterval 20

extern "C"{
    
    struct encoder_t
    {
#if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM) || defined(ESP_H)
        volatile uint32_t* registerA;
        volatile uint32_t* registerB;
        uint32_t maskA;
        uint32_t maskB;
#else
        volatile uint8_t* registerA;
        volatile uint8_t* registerB;
        uint8_t maskA;
        uint8_t maskB;
#endif
        volatile int32_t count;
        uint8_t lastValues;
        volatile int8_t overflow = 0;
    }myEncoder[MAX_ENCODER];
    
// Fast digital read without unnecessary checking
#define directDigitalRead(reg, mask) (((*reg) & mask)?1:0)
    
void updateCount(encoder_t& ec)
{
    int valA = directDigitalRead(ec.registerA, ec.maskA);
    int valB = directDigitalRead(ec.registerB, ec.maskB);
    
    uint8_t newValues = (valA << 1)|valB;
    uint8_t temp = (ec.lastValues << 2)|newValues;
    
    switch(temp){
        case 0b0000:
        case 0b1010:
        case 0b0101:
        case 0b1111:
            // Eliminate cases where no changes on both A and B.
            // The following four sequences are eliminated:
            // oldA   oldB  newA  newB
            //  0      0     0     0
            //  1      0     1     0
            //  0      1     0     1
            //  1      1     1     1
            // No action
        case 0b0011:
        case 0b0110:
        case 0b1001:
        case 0b1100:
            // Eliminate cases where changes on both A and B.
            // The following four sequences are eliminated:
            // oldA   oldB  newA  newB
            //  0      0     1     1
            //  0      1     1     0
            //  1      0     0     1
            //  1      1     0     0
            // No action
            break;
        case 0b1011:
        case 0b0100:
            // If change happens on B, increment if newA == newB, e.g
            // oldA   oldB  newA  newB
            //  1      0     1     1
            //  0      1     0     0
        case 0b0010:
        case 0b1101:
            // If change happens on A, increment if newA != newB, e.g
            // oldA   oldB  newA  newB
            //  0      0     1     0
            //  1      1     0     1
        {
            if(ec.count < LONG_MAX){
                ec.count++;
            }
            else{
                ec.count = 0;
                ec.overflow++;
            }
            break;
        }
        case 0b0001:
        case 0b1110:
            // If change happens on B, decrement if newA != newB, e.g
            // oldA   oldB  newA  newB
            //  0      0     0     1
            //  1      1     1     0
        case 0b0111:
        case 0b1000:
            // If change happens on A, decrement if newA == newB, e.g
            // oldA   oldB  newA  newB
            //  0      1     1     1
            //  1      0     0     0
        {
            if(ec.count > LONG_MIN){
                ec.count--;
            }
            else{
                ec.count = 0;
                ec.overflow--;
            }
            break;
        }
        default:{}
    }
    
    // Update lastValues to store new pin values
    ec.lastValues = newValues;
}

// Encoder 0 pin A interrupt service routine
void isrChannelA0(void)
{
    updateCount(myEncoder[0]);
}
// Encoder 0 pin B interrupt service routine
void isrChannelB0(void)
{
    updateCount(myEncoder[0]);
}
// Encoder 1 pin A interrupt service routine
void isrChannelA1(void)
{
    updateCount(myEncoder[1]);
}
// Encoder 1 pin B interrupt service routine
void isrChannelB1(void)
{
    updateCount(myEncoder[1]);
}

/* Attach the Quadrature Rotary Encoder to Arduino */
void attachEncoder(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
{
    uint8_T ID, pinA, pinB;
    uint16_T index = 0;
#if DEBUG_FLAG == 2
    uint8_T num =0;
#endif
    memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    memcpy(&pinA, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    memcpy(&pinB, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    /* Turn on pullup resistors */
    pinMode(pinA, INPUT);
    //debugPrint(MSG_MWARDUINOCLASS_PIN_MODE, pinA, "INPUT");
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
    DebugMsg.args[num++]=pinA;
    DebugMsg.args[num++]=(uint8_T)0;
    DebugMsg.argNum = num;
    sendDebugPackets();  
#endif
    pinMode(pinB, INPUT);
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
    DebugMsg.args[num++]=pinB;
    DebugMsg.args[num++]=(uint8_T)0;
    DebugMsg.argNum = num;
    sendDebugPackets();   
#endif
    digitalWrite(pinA, HIGH);
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
    DebugMsg.args[num++]=pinA;
    DebugMsg.args[num++]=uint8_T(HIGH);
    DebugMsg.argNum = num;
    sendDebugPackets(); 
#endif
    digitalWrite(pinB, HIGH);
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGWRITEDIGITALPIN;
    DebugMsg.args[num++]=pinB;
    DebugMsg.args[num++]=uint8_T(HIGH);
    DebugMsg.argNum = num;
    sendDebugPackets();   
#endif
    /* Initialize encoder count */
    myEncoder[ID].count = 0;
    myEncoder[ID].overflow = 0;
    
    /* Derive register and bit mask corresponds to the pin for fast digitalRead */
#if defined ARDUINO_ARCH_RENESAS_UNO
    myEncoder[ID].registerA = (volatile uint8_t*)portInputRegister(digitalPinToPort(pinA));
    myEncoder[ID].registerB = (volatile uint8_t*)portInputRegister(digitalPinToPort(pinB));
#else
    myEncoder[ID].registerA = portInputRegister(digitalPinToPort(pinA));
    myEncoder[ID].registerB = portInputRegister(digitalPinToPort(pinB));
#endif
    myEncoder[ID].maskA = digitalPinToBitMask(pinA);
    myEncoder[ID].maskB = digitalPinToBitMask(pinB);
    myEncoder[ID].lastValues = (digitalRead(pinA) << 1)|(digitalRead(pinB));
    switch(ID)
    {
        case 0:
        {
#if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
            attachInterrupt(pinA, isrChannelA0, CHANGE);
            attachInterrupt(pinB, isrChannelB0, CHANGE);
#elif defined(ESP_H)
            attachInterrupt(digitalPinToInterrupt((uint32_T)pinA), isrChannelA0, CHANGE);
            attachInterrupt(digitalPinToInterrupt((uint32_T)pinB), isrChannelB0, CHANGE);
#else
            attachInterrupt(digitalPinToInterrupt(pinA), isrChannelA0, CHANGE);
            attachInterrupt(digitalPinToInterrupt(pinB), isrChannelB0, CHANGE);
#endif
            break;
        }
        case 1:
        {
#if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
            attachInterrupt(pinA, isrChannelA1, CHANGE);
            attachInterrupt(pinB, isrChannelB1, CHANGE);
#elif defined(ESP_H)
           attachInterrupt(digitalPinToInterrupt((uint32_T)pinA), isrChannelA1, CHANGE);
           attachInterrupt(digitalPinToInterrupt((uint32_T)pinB), isrChannelB1, CHANGE);
#else
            attachInterrupt(digitalPinToInterrupt(pinA), isrChannelA1, CHANGE);
            attachInterrupt(digitalPinToInterrupt(pinB), isrChannelB1, CHANGE);
#endif
            break;
        }
        default:
        {}
    }
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGATTACHENCODER;
    DebugMsg.args[num++]=pinA;
    DebugMsg.args[num++]='A';
    DebugMsg.args[num++]=ID;
    DebugMsg.argNum = num;
    sendDebugPackets();
    num=0;
    DebugMsg.debugMsgID = DEBUGATTACHENCODER;
    DebugMsg.args[num++]=pinB;
    DebugMsg.args[num++]='B';
    DebugMsg.args[num++]=ID;
    DebugMsg.argNum = num;
    sendDebugPackets();
#endif
}

/* Detach the Encoder */
void detachEncoder(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
{
    noInterrupts();
    uint8_T ID, pinA, pinB;
    uint16_T index = 0;
#if DEBUG_FLAG == 2
    uint8_T num =0;
#endif
    memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    memcpy(&pinA, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    memcpy(&pinB, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
#if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
    detachInterrupt(pinA);
    detachInterrupt(pinB);
#elif defined(ESP_H)
    detachInterrupt(digitalPinToInterrupt((uint32_T)pinA));
    detachInterrupt(digitalPinToInterrupt((uint32_T)pinB));
#else
    detachInterrupt(digitalPinToInterrupt(pinA));
    detachInterrupt(digitalPinToInterrupt(pinB));
#endif
    
    // Enable interrupts before debugPrint or sendResponseMsg
    // as serial communication relys on interrupts
    interrupts();
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGDETACHENCODER;
    DebugMsg.args[num++]=pinA;
    DebugMsg.args[num++]=pinB;
    DebugMsg.argNum = num;
    sendDebugPackets();
#endif
}

/* Read the Encoder Speed. */
void readEncoderSpeed(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
{
#if DEBUG_FLAG == 2
    uint8_T num =0;
#endif
    noInterrupts();
    uint8_T numEncoders, ID, resultSize;
    uint16_T index = 0;
    
    memcpy(&numEncoders, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    resultSize = 3*numEncoders;
    
    uint8_T *result = new uint8_T [resultSize];
    for(size_t i = 0; i < numEncoders; ++i)
    {
        // uint8_T ID = dataIn[i+2];
        memcpy(&ID, &payloadBufferRx[i+1], sizeof(uint8_T));
        
        int32_t oldCount = myEncoder[ID].count;
        int8_t oldOverflow = myEncoder[ID].overflow;
        interrupts();
        delay(SpeedMeasureInterval);
        int32_t newCount = myEncoder[ID].count;
        int8_t overflowDiff = myEncoder[ID].overflow-oldOverflow;
        int16_t countDiff = newCount - oldCount;
#if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGREADSPEEDENCODER;
        DebugMsg.args[num++]=SpeedMeasureInterval;
        DebugMsg.args[num++]=ID;
        //pushing to range to overflowDiff to [0 255].
        DebugMsg.args[num++]=overflowDiff;
        DebugMsg.args[num++]=uint8_T(countDiff);
        DebugMsg.args[num++] = (uint8_T)(countDiff >> 8);
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        noInterrupts();
        
        result[i*3+0] = overflowDiff;
        result[i*3+1] = (countDiff & 0x00ff);
        result[i*3+2] = (countDiff & 0xff00) >> 8;
    }
    
    interrupts();
    memcpy(&payloadBufferTx[(*peripheralDataSizeResponse)], result, resultSize);
    (*peripheralDataSizeResponse) += resultSize;
    delete [] result;
}

/* Read the Encoder count. */
void readEncoderCount(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
{
#if DEBUG_FLAG == 2
    uint8_T num =0;
#endif
    noInterrupts();
    uint16_T index = 0;
    unsigned long time = millis();
    uint8_T ID;
    memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    int32_t count = myEncoder[ID].count;
    uint8_T flag;
    memcpy(&flag, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    if(flag)
        myEncoder[ID].count = 0;
    byte result [9];
    result[0] = (count & 0x000000ff);
    result[1] = (count & 0x0000ff00) >> 8;
    result[2] = (count & 0x00ff0000) >> 16;
    result[3] = (count & 0xff000000) >> 24;
    result[4] = (time & 0x000000ff);
    result[5] = (time & 0x0000ff00) >> 8;
    result[6] = (time & 0x00ff0000) >> 16;
    result[7] = (time & 0xff000000) >> 24;
    result[8] = myEncoder[ID].overflow;
    
    interrupts();
    memcpy(&payloadBufferTx[(*peripheralDataSizeResponse)], result, 9);
    (*peripheralDataSizeResponse) += 9;
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGREADCOUNTENCODER;
    DebugMsg.args[num++]=result[8];
    DebugMsg.args[num++]=ID;
    DebugMsg.args[num++]=(uint8_T)(count & 0x000000ffUL);
    DebugMsg.args[num++]=(uint8_T)((count & 0x0000ff00UL) >>  8);
    DebugMsg.args[num++]=(uint8_T)((count & 0x00ff0000UL) >> 16);
    DebugMsg.args[num++]=(uint8_T)((count & 0xff000000UL) >> 24);
    DebugMsg.argNum = num;
    sendDebugPackets();
#endif
}

/* Set the encoder count. */
void writeEncoderCount(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
{
#if DEBUG_FLAG == 2
    uint8_T num =0;
#endif
    noInterrupts();
    uint8_T ID;
    uint16_T index = 0;
    
    memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
    index += sizeof(uint8_T);
    
    int32_t count;
    memcpy(&count, &payloadBufferRx[index], sizeof(int32_t));
    index += sizeof(uint8_T);
    
    myEncoder[ID].count = count;
    myEncoder[ID].overflow = 0;
    
    interrupts();
#if DEBUG_FLAG == 2
    num=0;
    DebugMsg.debugMsgID = DEBUGWRITWCOUNTENCODER;
    DebugMsg.args[num++]=ID;
    DebugMsg.args[num++]=(uint8_T)(count & 0x000000ffUL);
    DebugMsg.args[num++]=(uint8_T)((count & 0x0000ff00UL) >>  8);
    DebugMsg.args[num++]=(uint8_T)((count & 0x00ff0000UL) >> 16);
    DebugMsg.args[num++]=(uint8_T)((count & 0xff000000UL) >> 24);
    DebugMsg.argNum = num;
    sendDebugPackets();
#endif
}



}
#endif //IO_CUSTOM_ROTARYENCODER
