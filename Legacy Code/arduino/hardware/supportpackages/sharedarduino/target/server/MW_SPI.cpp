/* Copyright 2017-2024 The MathWorks, Inc. */
#include "MW_SPI.h"
#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif
#include "SPI.h"
#include "IO_peripheralInclude.h"

#if IO_STANDARD_SPI
struct mwspisettings
{
    uint32_T SPIBusSpeed = 4000000;
    uint8_T SPIActiveLevel = 0;
    uint8_T SPIMode = SPI_MODE0;
    uint8_T SPIBitOrder = LSBFIRST;
    uint8_T SPISlaveSelect = 0;
    bool HasBegin = false;
    
};
mwspisettings ArduinoSPIParamSettings;

#ifdef __cplusplus
extern "C" {
#endif
    
    MW_Handle_Type MW_SPI_Open(uint32_T SPIModule, uint32_T MosiPin, uint32_T MisoPin, uint32_T ClockPin, uint32_T SlaveSelectPin, uint8_T ActiveLevel, uint8_T spi_device_type)
    {
        if ((uint8_T)SPIModule < (uint8_T)IO_SPI_MODULES_MAX)
        {
            
            ArduinoSPIParamSettings.SPIActiveLevel = 1-ActiveLevel;
            pinMode((uint8_T)SlaveSelectPin,OUTPUT);
#if DEBUG_FLAG == 2
            uint8_T index = 0;
            uint8_T dummy = 0; // For byte alignment
            DebugMsg.debugMsgID= DEBUGOPENDIGITALPIN;
            DebugMsg.args[index++]=(uint8_T)SlaveSelectPin;
            DebugMsg.args[index++]=(uint8_T)1;
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
            if(ArduinoSPIParamSettings.SPIActiveLevel == 1)
            {
                digitalWrite((uint8_T)SlaveSelectPin, LOW);
#if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
                DebugMsg.args[index++]=SlaveSelectPin;
                DebugMsg.args[index++]=(uint8_T)0;
                DebugMsg.argNum = index;
                sendDebugPackets();
#endif
            }
            else
            {
                digitalWrite((uint8_T)SlaveSelectPin, HIGH);
#if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
                DebugMsg.args[index++]=SlaveSelectPin;
                DebugMsg.args[index++]=(uint8_T)1;
                DebugMsg.argNum = index;
                sendDebugPackets();
#endif
            }
            if(!ArduinoSPIParamSettings.HasBegin)
            {                
                SPI.begin();
                ArduinoSPIParamSettings.HasBegin = true;
#if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID=DEBUGSPIBEGINAVR;
                DebugMsg.argNum = index;
                sendDebugPackets();
#endif
            }
            /* Adding a 1 just so that when SPIModule is 0, it goes through the NULL check. */
            return (MW_Handle_Type)((uint8_T)SPIModule + 1);
        }
        else
        {
            return NULL;
        }
    }
    
    MW_SPI_Status_Type MW_SPI_SetFormat(MW_Handle_Type SPIModuleHandle, uint8_T TargetPrecision, MW_SPI_Mode_type SPIMode, MW_SPI_FirstBitTransfer_Type TargetFirstBitToTransfer)
    {
        MW_SPI_Status_Type status = MW_SPI_SUCCESS;
        uint8_T bus = *((uint8_T*)(&SPIModuleHandle)) - 1;
        switch (SPIMode)
        {
            case MW_SPI_MODE_0:
                ArduinoSPIParamSettings.SPIMode = SPI_MODE0;
                break;
            case MW_SPI_MODE_1:
                ArduinoSPIParamSettings.SPIMode = SPI_MODE1;
                break;
            case MW_SPI_MODE_2:
                ArduinoSPIParamSettings.SPIMode = SPI_MODE2;
                break;
            case MW_SPI_MODE_3:
                ArduinoSPIParamSettings.SPIMode = SPI_MODE3;
                break;
            default:
                break;
        }
        
        switch (TargetFirstBitToTransfer)
        {
            case MW_SPI_LEAST_SIGNIFICANT_BIT_FIRST:
                /* ioclient, hwsdk maps msbfirst -> 0 and svd maps lsbfirst -> 0 */
                ArduinoSPIParamSettings.SPIBitOrder = MSBFIRST;
                break;
            case MW_SPI_MOST_SIGNIFICANT_BIT_FIRST:
                /* ioclient, hwsdk maps lsbfirst -> 1 and svd maps msbfirst -> 1 */
                ArduinoSPIParamSettings.SPIBitOrder = LSBFIRST;
                break;
            default:
                break;
        }
        return status;
    }
    
    MW_SPI_Status_Type MW_SPI_SetSlaveSelect(MW_Handle_Type SPIModuleHandle, uint32_T SlaveSelectPin, uint8_T ActiveLowSSPin)
    {
        MW_SPI_Status_Type status = MW_SPI_SUCCESS;
        uint8_T dummy = 0; // For byte alignment
        ArduinoSPIParamSettings.SPISlaveSelect = (uint8_T)SlaveSelectPin;
        return status;
    }
    
    MW_SPI_Status_Type MW_SPI_SetBusSpeed(MW_Handle_Type SPIModuleHandle, uint32_T BusSpeedInHz)
    {
        MW_SPI_Status_Type status = MW_SPI_SUCCESS;
        uint8_T bus = *((uint8_T*)(&SPIModuleHandle)) - 1;
        ArduinoSPIParamSettings.SPIBusSpeed = BusSpeedInHz;
        return status;
    }
    
    MW_SPI_Status_Type MW_SPI_MasterWriteRead_8bits(MW_Handle_Type SPIModuleHandle, const uint8_T * wrData, uint8_T * rdData, uint32_T datalength)
    {        
        uint32_T i;
        uint8_T bus = *((uint8_T*)(&SPIModuleHandle)) - 1;
        uint8_T SPISlaveSelect = ArduinoSPIParamSettings.SPISlaveSelect;
        uint8_T SPIActiveLevel = ArduinoSPIParamSettings.SPIActiveLevel;
        MW_SPI_Status_Type status = MW_SPI_BUS_ERROR;
#if DEBUG_FLAG == 2
        uint8_T index=0;
        uint8_T dummy = 0; //For Byte alignment
        uint8_T SPIModeDebug;
        uint8_T SPIBitOrderDebug;
#endif
        // The following flow is needed to resolve the problem of using SPI mode 3 for the first time;
        // 1. After SPI.beginTransaction(),
        // 2. write the SS pin LOW,
        // 3. call SPI.transfer() any number of times to transfer data
        
#if defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_SAMD  || defined ARDUINO_ARCH_MBED || defined ARDUINO_ARCH_RP2040 || defined ARDUINO_ARCH_RENESAS_UNO

        SPISettings settings(ArduinoSPIParamSettings.SPIBusSpeed, BitOrder(ArduinoSPIParamSettings.SPIBitOrder), ArduinoSPIParamSettings.SPIMode);
#else
        SPISettings settings(ArduinoSPIParamSettings.SPIBusSpeed, ArduinoSPIParamSettings.SPIBitOrder, ArduinoSPIParamSettings.SPIMode);
#endif
        SPI.beginTransaction(settings);
#if DEBUG_FLAG == 2
        switch (ArduinoSPIParamSettings.SPIMode)
        {
            case  SPI_MODE0:
                SPIModeDebug=MW_SPI_MODE_0;
                break;
            case SPI_MODE1:
                SPIModeDebug=MW_SPI_MODE_1;
                break;
            case SPI_MODE2:
                SPIModeDebug=MW_SPI_MODE_2;
                break;
            case SPI_MODE3:
                SPIModeDebug=MW_SPI_MODE_3;
                break;
            default:
                SPIModeDebug=MW_SPI_MODE_0;
                break;
        }
        switch (ArduinoSPIParamSettings.SPIBitOrder)
        {
            case LSBFIRST:
                SPIBitOrderDebug = MW_SPI_LEAST_SIGNIFICANT_BIT_FIRST;
                break;
            case MSBFIRST:
                SPIBitOrderDebug = MW_SPI_MOST_SIGNIFICANT_BIT_FIRST;
                break;
            default:
                SPIBitOrderDebug = MW_SPI_MOST_SIGNIFICANT_BIT_FIRST;
                break;
        }
        index=0;
        DebugMsg.debugMsgID=DEBUGSPIBEGINTRANSACTION;
        DebugMsg.args[index++] = (uint8_T)(ArduinoSPIParamSettings.SPIBusSpeed & 0x000000ffUL);
        DebugMsg.args[index++] = (uint8_T)((ArduinoSPIParamSettings.SPIBusSpeed & 0x0000ff00UL) >>  8);
        DebugMsg.args[index++] = (uint8_T)((ArduinoSPIParamSettings.SPIBusSpeed & 0x00ff0000UL) >> 16);
        DebugMsg.args[index++] = (uint8_T)((ArduinoSPIParamSettings.SPIBusSpeed & 0xff000000UL) >> 24);
        DebugMsg.args[index++] =  SPIBitOrderDebug;
        DebugMsg.args[index++] =  SPIModeDebug;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        
        // Enable the SPI device
        if(SPIActiveLevel == 0)
        {
            digitalWrite((uint8_T)SPISlaveSelect,LOW);
            #if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
                DebugMsg.args[index++]=SPISlaveSelect;
                DebugMsg.args[index++]=(uint8_T)0;
                DebugMsg.argNum = index;
                sendDebugPackets();
            #endif
        }
        else
        {
            digitalWrite((uint8_T)SPISlaveSelect, HIGH);
            #if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
                DebugMsg.args[index++]=SPISlaveSelect;
                DebugMsg.args[index++]=(uint8_T)1;
                DebugMsg.argNum = index;
                sendDebugPackets();
            #endif
        }
        
        for (i = 0; i <= datalength-1; i++)
        {
            rdData[i] = SPI.transfer(wrData[i]);
#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGSPITRANSFERAVR;
            DebugMsg.args[index++]= wrData[i];
            DebugMsg.args[index++]= rdData[i];
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
        }
        // Disable the SPI device
        if(SPIActiveLevel == 0)
        {
            digitalWrite((uint8_T)SPISlaveSelect, HIGH);
            #if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
                DebugMsg.args[index++]=SPISlaveSelect;
                DebugMsg.args[index++]=(uint8_T)1;
                DebugMsg.argNum = index;
                sendDebugPackets();
            #endif            
        }
        else
        {
            digitalWrite((uint8_T)SPISlaveSelect, LOW);
            #if DEBUG_FLAG == 2
                index = 0;
                DebugMsg.debugMsgID= DEBUGWRITEDIGITALPIN;
                DebugMsg.args[index++]=SPISlaveSelect;
                DebugMsg.args[index++]=(uint8_T)0;
                DebugMsg.argNum = index;
                sendDebugPackets();
            #endif
        }
        SPI.endTransaction();
#if DEBUG_FLAG == 2
        index=0;
        DebugMsg.debugMsgID=DEBUGSPIENDTRANSACTION;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        status = MW_SPI_SUCCESS;
        return status;
    }
    
    MW_SPI_Status_Type MW_SPI_SlaveWriteRead_8bits(MW_Handle_Type SPIModuleHandle, const uint8_T * wrData, uint8_T * rdData, uint32_T datalength)
    {
        return MW_SPI_SUCCESS;
    }
    
    MW_SPI_Status_Type MW_SPI_GetStatus(MW_Handle_Type SPIModuleHandle)
    {
        MW_SPI_Status_Type status = MW_SPI_SUCCESS;
        return status;
    }
    
    void MW_SPI_Close(MW_Handle_Type SPIModuleHandle, uint32_T MosiPin, uint32_T MisoPin, uint32_T ClockPin, uint32_T SlaveSelectPin)
    {
#if DEBUG_FLAG == 2
        uint8_T index=0;
        uint8_T dummy = 0; // For byte alignment
        uint8_T SPIModeDebug;
        uint8_T SPIBitOrderDebug;
#endif
        // Issue seen on Arduino's implementation of SPI in SAMD v1.8.4 - SPI's configure method bypasses the SPI enable if the current and previous settings are same.
        // This causes failed SPI enable when a new SPI device is created as the SPI constructor is not called upon (as the IOserver is unchanged)
        // leading to same setting prior to device destruction. This is the reason two consecutive SPI_MODE0 configuration fails.
        // see geck 2156301
#if defined ARDUINO_ARCH_SAMD
        SPISettings settings(0, BitOrder(ArduinoSPIParamSettings.SPIBitOrder), ArduinoSPIParamSettings.SPIMode);
        SPI.beginTransaction(settings);
#if DEBUG_FLAG == 2
        switch (ArduinoSPIParamSettings.SPIMode)
        {
            case SPI_MODE0:
                SPIModeDebug=MW_SPI_MODE_0;
                break;
            case SPI_MODE1:
                SPIModeDebug=MW_SPI_MODE_1;
                break;
            case SPI_MODE2:
                SPIModeDebug=MW_SPI_MODE_2;
                break;
            case SPI_MODE3:
                SPIModeDebug=MW_SPI_MODE_3;
                break;
            default:
                SPIModeDebug=MW_SPI_MODE_0;
                break;
        }
        switch (ArduinoSPIParamSettings.SPIBitOrder)
        {
            case LSBFIRST:
                SPIBitOrderDebug = MW_SPI_LEAST_SIGNIFICANT_BIT_FIRST;
                break;
            case MSBFIRST:
                SPIBitOrderDebug = MW_SPI_MOST_SIGNIFICANT_BIT_FIRST;
                break;
            default:
                SPIBitOrderDebug = MW_SPI_MOST_SIGNIFICANT_BIT_FIRST;
                break;
        }
        index=0;
        DebugMsg.debugMsgID=DEBUGSPIBEGINTRANSACTION;
        DebugMsg.args[index++] = 0;
        DebugMsg.args[index++] = 0;
        DebugMsg.args[index++] = 0;
        DebugMsg.args[index++] = 0;
        DebugMsg.args[index++] =  SPIBitOrderDebug;
        DebugMsg.args[index++] =  SPIModeDebug;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        SPI.endTransaction();
#if DEBUG_FLAG == 2
        index=0;
        DebugMsg.debugMsgID=DEBUGSPIENDTRANSACTION;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
#endif
        SPI.end();
#if DEBUG_FLAG == 2
        DebugMsg.debugMsgID=DEBUGSPIENDAVR;
        DebugMsg.argNum = index;
        sendDebugPackets();
#endif
        ArduinoSPIParamSettings.HasBegin = false;
    }
    
    
#ifdef __cplusplus
}
#endif

#endif //IO_STANDARD_SPI
