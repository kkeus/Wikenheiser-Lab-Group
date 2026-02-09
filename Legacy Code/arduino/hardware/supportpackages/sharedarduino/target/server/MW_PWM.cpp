/* Copyright 2017-2024 The MathWorks, Inc. */

#include "MW_PWM.h"
#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif
#include "IO_peripheralInclude.h"
#if defined (ESP_H)
    #include "PWMChannel.cpp"
#endif

#if defined(ARDUINO_ARCH_RENESAS_UNO)
#include "pwm.h"

// Define the number of PWM pins
#define NUM_PWM_PINS 6

// Create an array of PwmOut objects
static PwmOut* pwmObjects[NUM_PWM_PINS];
static uint8_T pwmPinIndex[NUM_PWM_PINS];
static uint8_T pwmPinCounter = 0;


// Create a PwmOut object for a specified pin and add it to the array
void createPwmObject(int pin) {
    pwmObjects[pwmPinCounter] = new PwmOut(pin);
    pwmPinIndex[pwmPinCounter] = (uint8_T)pin;
    pwmPinCounter++;
    if (pwmPinCounter>= NUM_PWM_PINS) {
        // A safeguard to avoid accidental out-of-bound access
        pwmPinCounter = NUM_PWM_PINS-1;
    }
}


int getIndexForPWMPin(int pin) {
    int i=0;
    int idx = 0;
    for (i=0;i<NUM_PWM_PINS;i++) {
        if (pin==pwmPinIndex[i]) {
            idx = i;
            break;
        }
    }
    return idx;
}

#endif

#ifdef __cplusplus
extern "C" {
#endif
/*#if defined (ESP_H)
    uint16_T PWMFrequency = 1000; // this variable is used to define the time period
    uint8_T PWMResolution = 8; // this will define the resolution of the signal which is 8 in this case
    uint8_T PinChannelMap[IO_PWM_MODULES_MAX]; //ADD correct PWM ARRAY SIZE BASED On size of MAP
    bool PWMChannels[16] = {0};
    const uint8_T numChannels = 16;
#endif*/
    /* PWM Initialisation selected by the pinNumber (PWM Channel) */
    MW_Handle_Type MW_PWM_Open(uint32_T pin, real_T frequency, real_T dutyCycle)
    {
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        if((uint8_T)pin <= IO_PWM_MODULES_MAX)
        {
            #if !defined(ESP_H)
            #if defined(ARDUINO_ARCH_RENESAS_UNO)
            createPwmObject(pin);
            pwmObjects[pwmPinCounter-1]->begin(frequency, 0, false, TIMER_SOURCE_DIV_1);
            #elif defined(__IMXRT1062__)
            #include "core_pins.h"
            if(frequency > 0)                    // Specify Frequency
            {
                analogWriteFrequency(pin,frequency);
            }
            #else
            pinMode((uint8_T)pin,OUTPUT);
            #endif
            #else /*ESP32*/
                assignPWMChannel((uint8_T)pin);
            #endif
#if DEBUG_FLAG == 2
            DebugMsg.debugMsgID = DEBUGPWMOPEN;
            DebugMsg.args[index++]=(uint8_T)pin;
            DebugMsg.args[index++]=(uint8_T)1;
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
            return (MW_Handle_Type)(pin + 1);
        }
        else
        {
            return (MW_Handle_Type)NULL;
        }
        
    }
    
    /* Start PWM */
    void MW_PWM_Start(MW_Handle_Type PWMPinHandle)
    {
    }
    
    /* Set the duty cycle or pulse width for the PWM signal */
    void MW_PWM_SetDutyCycle(MW_Handle_Type PWMPinHandle, real_T dutyCycle)
    {
        uint8_T pin, dutyCycleValue;
        pin = *((uint8_T*)(&PWMPinHandle)) - 1;
   
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        dutyCycleValue = (uint8_T)(255*dutyCycle/100);
        #if !defined(ESP_H)
            analogWrite(pin, dutyCycleValue);
        #elif defined(ARDUINO_ARCH_RENESAS_UNO)
        uint8_T pin;
        if(*((uint8_T*)(&PWMPinHandle)))
        {
            /* The handle of a Pin is stored as (Pin+1) */
            pin =  *((uint8_T*)(&PWMPinHandle)) - 1;
            if(PinMapTable[pin]==1)       /* Specify frequency */
            {
                dutyCycle = dutyCycle * -1;
                int locPinIndex = getIndexForPWMPin(pin);
                pwmObjects[locPinIndex]->pulse_perc((float)(dutyCycle * 100) / 255);
            }
            else
            {
                analogWrite(pin, dutyCycle);  /* Default frequency*/
            }
        }
        #else /*ESP32 */
            uint8_T channel = getPWMChannel(pin);
            ledcAttachPin(pin, channel);
            ledcSetup(channel, PWMFrequency, PWMResolution);
            ledcWrite(channel, dutyCycleValue);
        #endif
#if DEBUG_FLAG == 2
        #if !defined(ESP_H)
            DebugMsg.debugMsgID = DEBUGPWMSETDUTYCYCLE;
            DebugMsg.args[index++]=pin;
            DebugMsg.args[index++]=dutyCycleValue;
            DebugMsg.argNum = index;
            sendDebugPackets();
        #else        
            DebugMsg.debugMsgID = DEBUGPWMSETDUTYCYCLEESP32;
            DebugMsg.args[index++]=pin;
            DebugMsg.args[index++]=channel;
            DebugMsg.args[index++]=dutyCycleValue;
            DebugMsg.argNum = index;
            sendDebugPackets();
        #endif
#endif
    }
    
    /* Set the PWM signal frequency */
    void MW_PWM_SetFrequency(MW_Handle_Type PWMPinHandle, real_T frequency)
    {
    }
    
    /* Disable notifications on the channel */
    void MW_PWM_DisableNotification(MW_Handle_Type PWMPinHandle)
    {
    }
    
    /* Enable notifications on the channel */
    void MW_PWM_EnableNotification(MW_Handle_Type PWMPinHandle, MW_PWM_EdgeNotification_Type Notification)
    {
    }
    
    /* Set PWM output to idle state */
    void MW_PWM_SetOutputToIdle(MW_Handle_Type PWMPinHandle)
    {
    }
    
    /* Get the PWM output status */
    boolean_T MW_PWM_GetOutputState(MW_Handle_Type PWMPinHandle)
    {
        #if defined ARDUINO_ARCH_RP2040
        return 0;
        #endif
    }
    
    /* Stop PWM */
    void MW_PWM_Stop(MW_Handle_Type PWMPinHandle)
    {
    }
    
    /* Close PWM */
    void MW_PWM_Close(MW_Handle_Type PWMPinHandle)
    {
    }
    
#ifdef __cplusplus
}
#endif
