/* Copyright 2017-2024 The MathWorks, Inc. */

#include "MW_AnalogIn.h"

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif
#include "IO_peripheralInclude.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    /* Create AnalogIn group with Channels and Conversion time */
    MW_Handle_Type MW_AnalogInSingle_Open(uint32_T Pin)
    {
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        if((uint8_T)Pin <= IO_ANALOGINPUT_MODULES_MAX)
        {
            pinMode((uint8_T)Pin, INPUT);
#if DEBUG_FLAG == 2
            DebugMsg.debugMsgID = DEBUGOPENDIGITALPIN;
            DebugMsg.args[index++]=(uint8_T)Pin;
            DebugMsg.args[index++]=(uint8_T)0;
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
            /* Pin can be 0 which is NULL. So basing it from 1 */
            return (MW_Handle_Type)((uint8_T)Pin + 1);
        }
        else
        {
            return (MW_Handle_Type)NULL;
        }
    }
    
    /* Select trigger source for AnalogIn group to start conversion */
    void MW_AnalogIn_SetTriggerSource(MW_Handle_Type AnalogInHandle, MW_AnalogIn_TriggerSource_Type TriggerType, uint32_T TriggerValue)
    {
    }
    
    /* Enable Conversion complete notification */
    void MW_AnalogIn_EnableNotification(MW_Handle_Type AnalogInHandle)
    {
    }
    
    /* Disable notifications */
    void MW_AnalogIn_DisableNotification(MW_Handle_Type AnalogInHandle)
    {
    }
    
    /* Enable continuous conversion */
    void MW_AnalogIn_EnableContConversion(MW_Handle_Type AnalogInHandle)
    {
    }
    
    /* Set channel conversion priority */
    void MW_AnalogIn_SetChannelConvRank(MW_Handle_Type AnalogInHandle, uint32_T Channel, uint32_T Rank)
    {
    }
    
    /* Get status of AnalogIn conversion group */
    MW_AnalogIn_Status_Type MW_AnalogIn_GetStatus(MW_Handle_Type AnalogInHandle)
    {
        return MW_ANALOGIN_CONVERSION_COMPLETE;
    }
    
    /* Read channel conversion result */
    void MW_AnalogInSingle_ReadResult(MW_Handle_Type AnalogInHandle, void * Result_ptr, MW_AnalogIn_ResultDataType_Type ResultDataType)
    {
        uint16_T counts;
        uint8_T pin;
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
#if defined(ARDUINO_ARCH_SAM) || defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_MBED) || defined(ARDUINO_ARCH_RP2040) || defined(ARDUINO_ARCH_RENESAS_UNO)
        /* By default ADC resolution is 10-bits, changing it to 12-bits for ARM boards */
        analogReadResolution(12);
#endif
        pin = *((uint8_T*)(&AnalogInHandle)) - 1;
#ifdef MW_AREF        
        /* To avoid setting analog reference, everytime readVoltage command is called aref_call variable is used */
       static boolean_T aref_call = 'T';
        
       if (aref_call == 'T')
       {
            /* Call Microcontroller specific MACRO values to set analog reference */
#if defined(__AVR_ATmega328P__) || defined(__AVR_ATmega328__) || defined(__AVR_ATmega32U4__) || defined(__AVR_ATmega2560__)
            {
                /*'Uno','Nano3','ProMini328_3V','ProMini328_5V','DigitalSandbox','Leonardo','Micro','Mega2560','MegaADK'*/
               analogReference(MW_AREF);
            }
#elif defined(ARDUINO_ARCH_SAMD)
            {
                /*'MKR1000','MKR1010','MKRZero','Nano33IoT*/
                /*Due supports only Default analog reference mode and hence its not being set*/
                /*Type casting is being done as per definition of macros for SAMD boards*/
               analogReference(static_cast<eAnalogReference>(MW_AREF));
            }
#endif
           aref_call = 'F';
       }
#endif
        
        counts = analogRead(pin);
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID = DEBUGREADRESULTANALOGINSINGLE;
        DebugMsg.args[index++]=pin;
        DebugMsg.args[index++]=(uint8_T)counts;
        DebugMsg.args[index++]=(uint8_T)(counts >> 8);
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        
#if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_MBED)
        // Currently added to fix byte alignment issue in MKR1000 captured in g1928743. This needs to be revisited in 19b
        *(uint8_T *)Result_ptr = (uint8_T)counts;
        *((uint8_T *)Result_ptr + sizeof(uint8_T)) = (uint8_T)(counts>>8);
#else
        *(uint16_T *)Result_ptr = (uint16_T)counts;
#endif
    }
    
    /* Start conversion */
    void MW_AnalogIn_Start(MW_Handle_Type AnalogInHandle)
    {
    }
    
    /* Stop conversion */
    void MW_AnalogIn_Stop(MW_Handle_Type AnalogInHandle)
    {
    }
    
    /* De-initialise */
    void MW_AnalogIn_Close(MW_Handle_Type AnalogInHandle)
    {
    }
    
    MW_Handle_Type MW_AnalogIn_GetHandle(uint32_T Pin)
    {
        return (MW_Handle_Type)NULL;
    }
#ifdef __cplusplus
}
#endif
