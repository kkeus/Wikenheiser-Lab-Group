/* Copyright 2017-2020 The MathWorks, Inc. */
#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif
#include "IO_peripheralInclude.h"
#include "MW_I2C.h"
#include "Wire.h"

#if IO_STANDARD_I2C

bool hasBegin[IO_I2C_MODULES_MAX] = {false};
#ifdef __cplusplus
extern "C" {
#endif
    
    /* I2CModule + 1 is returned to IO_Wrapper so that the PeripheralMap 0 refers to 1.
     * This is done because for dynamic memory allocation implementation IO_Wrapper uses NULL to verify if a bus is not opened.
     * returning bus = 0 for first bus to the IOWrapper would mean bus is not open, But Arduino I2C buses are 0 indexed, i,e, first bus = 0 etc,
     * In Read/Write functions IOWrapper sends I2CModuleHandle = 1 for bus 0, 2 for bus 1, therefore subtracting 1 from the recieved I2CModuleHandle
     * value to get the bus id compatible with Arduino*/
    
    /* Initialize an I2C */
    MW_Handle_Type MW_I2C_Open(uint32_T I2CModule, MW_I2C_Mode_Type i2c_mode)
    {
        /* Arduino specific wire library func */
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        if ((uint8_T)I2CModule < (uint8_T)IO_I2C_MODULES_MAX)
        {
            if (hasBegin[I2CModule] == false)
            {
                if((uint8_T)I2CModule == 0)
                {
                    Wire.begin();
#if DEBUG_FLAG == 2
                    DebugMsg.debugMsgID=DEBUGI2CBEGINAVR;
                    DebugMsg.argNum = index;
                    sendDebugPackets();
#endif
                }
                else
                {
#if defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_NRF52840
                    Wire1.begin();
#if DEBUG_FLAG == 2
                    DebugMsg.debugMsgID=DEBUGI2CBEGINARM;
                    DebugMsg.argNum = index;
                    sendDebugPackets();
#endif
#endif
                }
                hasBegin[I2CModule] = true;
            }
            return (MW_Handle_Type)(I2CModule+1);
        }
        else
        {
            return NULL;
        }
    }
    
    /* Set the I2C bus speed in Master Mode */
    MW_I2C_Status_Type MW_I2C_SetBusSpeed(MW_Handle_Type I2CModuleHandle, uint32_T BusSpeed)
    {
        uint8_T bus = *((uint8_T*)(&I2CModuleHandle)) - 1;
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        if(bus == 0)
        {
            Wire.setClock(BusSpeed);
#if DEBUG_FLAG == 2
            DebugMsg.debugMsgID=DEBUGI2CSETCLOCKAVR;
            //unpacking bytes (little endian )
            DebugMsg.args[index++] = (uint8_T)(BusSpeed & 0x000000ffUL);
            DebugMsg.args[index++] = (uint8_T)((BusSpeed & 0x0000ff00UL) >>  8);
            DebugMsg.args[index++] = (uint8_T)((BusSpeed & 0x00ff0000UL) >> 16);
            DebugMsg.args[index++] = (uint8_T)((BusSpeed & 0xff000000UL) >> 24);
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
        }
        else
        {
#if defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_NRF52840
            Wire1.setClock(BusSpeed);
	#if DEBUG_FLAG == 2
            DebugMsg.debugMsgID=DEBUGI2CSETCLOCKARM;
            //unpacking bytes (little endian )
            DebugMsg.args[index++] = (uint8_T)(BusSpeed & 0x000000ffUL);
            DebugMsg.args[index++] = (uint8_T)((BusSpeed & 0x0000ff00UL) >>  8);
            DebugMsg.args[index++] = (uint8_T)((BusSpeed & 0x00ff0000UL) >> 16);
            DebugMsg.args[index++] = (uint8_T)((BusSpeed & 0xff000000UL) >> 24);
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
#endif
        }
        return MW_I2C_SUCCESS;
    }
    
    /* Set the slave address (used only by slave). Since, Arduino has no usecase to be used as slave leaving it empty */
    MW_I2C_Status_Type MW_I2C_SetSlaveAddress(MW_Handle_Type I2CModuleHandle, uint32_T SlaveAddress)
    {
        return MW_I2C_SUCCESS;
    }
    
    /* Receive the data on Master device from a specified slave */
    MW_I2C_Status_Type MW_I2C_MasterRead(MW_Handle_Type I2CModuleHandle, uint16_T SlaveAddress, uint8_T * data, uint32_T DataLength, uint8_T RepeatedStart, uint8_T SendNoAck)
    {
        uint8_T bus = *((uint8_T*)(&I2CModuleHandle)) - 1;
        uint8_T address  = (uint8_T)SlaveAddress;
        uint8_T numBytes = (uint8_T)DataLength; /* numBytes can only be a byte according to requestFrom API prototype */
        uint8_T status;
#if DEBUG_FLAG == 2
        uint8_T index=0;
#endif
        bool sendstop;
        if (RepeatedStart == 0)
        {
            sendstop = true;
        }
        else
        {
            sendstop = false;
        }
        MW_I2C_Status_Type RequestFromStatus;
        if(bus == 0)
        {
            status = Wire.requestFrom(address, (uint8_T)numBytes,sendstop);
#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGI2CREQUESTFROMAVR;
            DebugMsg.args[index++]=address;
            DebugMsg.args[index++]=numBytes;
            DebugMsg.args[index++]=sendstop;
            DebugMsg.args[index++]=status;
            DebugMsg.argNum = index;
            sendDebugPackets();
#endif
            if(status != numBytes)
            {
                RequestFromStatus = MW_I2C_BUS_ERROR;
            }
            else
            {
                RequestFromStatus = MW_I2C_SUCCESS;
                for(int i = 0; i < numBytes; ++i)
                {
                    data[i] = Wire.read();
#if DEBUG_FLAG == 2
                    index=0;
                    DebugMsg.debugMsgID=DEBUGI2CREADFROMAVR;
                    DebugMsg.args[index++]=data[i];
                    DebugMsg.argNum = index;
                    sendDebugPackets();
#endif
                }
            }
            
        }
        else
        {
#if defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_NRF52840
            status = Wire1.requestFrom(address, (uint8_T)numBytes,sendstop);
	#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID= DEBUGI2CREQUESTFROMARM;
            DebugMsg.args[index++]=address;
            DebugMsg.args[index++]=numBytes;
            DebugMsg.args[index++]=sendstop;
            DebugMsg.args[index++]=status;
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
            if(status != numBytes)
            {
                RequestFromStatus = MW_I2C_BUS_ERROR;
            }
            else
            {
                RequestFromStatus = MW_I2C_SUCCESS;
                for(int i = 0; i < numBytes; ++i)
                {
                    data[i] = Wire1.read();
	#if DEBUG_FLAG == 2
                    index=0;
                    DebugMsg.debugMsgID=DEBUGI2CREADFROMARM;
                    DebugMsg.args[index++]=data[i];
                    DebugMsg.argNum = index;
                    sendDebugPackets();
	#endif
                }
            }
#endif
        }
        return RequestFromStatus;
    }
    
    /* Send the data from master to a specified slave */
    MW_I2C_Status_Type MW_I2C_MasterWrite(MW_Handle_Type I2CModuleHandle, uint16_T SlaveAddress, uint8_T * data, uint32_T DataLength, uint8_T RepeatedStart, uint8_T SendNoAck)
    {
        uint8_T bus = *((uint8_T*)(&I2CModuleHandle)) - 1;
        uint8_T address  = (uint8_T)SlaveAddress;
        uint8_T numBytes = DataLength; /* numBytes can only be a byte according to requestFrom API prototype */
        uint8_T status;
        uint8_T n=0;
        bool sendstop;
	#if DEBUG_FLAG == 2
        uint8_T index=0;
	#endif
        if (RepeatedStart == 0)
        {
            sendstop = true;
        }
        else
        {
            sendstop = false;
        }
        if(bus == 0)
        {
            Wire.beginTransmission(address);
	#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGI2CBEGINTRANSMISSIONAVR;
            DebugMsg.args[index++]=address;
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
            if(numBytes > 0)
            {
                n = Wire.write(data, numBytes);
    #if DEBUG_FLAG == 2
                index=0;
                DebugMsg.debugMsgID=DEBUGI2CWRITEAVR;
                DebugMsg.args[index++]=data[0];
                DebugMsg.args[index++]=1;// one byte address
                DebugMsg.argNum = index;
                sendDebugPackets();
    #endif
            }
    #if DEBUG_FLAG == 2       
            if(numBytes>1)
            {
                index = 0;
                switch (numBytes)
                {
                    case 2:
                        DebugMsg.debugMsgID=DEBUGI2CWRITEAVR1DATA;
                        DebugMsg.args[index++] = data[1];
                        break;
                    case 3:
                        DebugMsg.debugMsgID=DEBUGI2CWRITEAVR2DATA;
                        DebugMsg.args[index++] = data[1];
                        DebugMsg.args[index++] = data[2];
                        break;
                    default:
                        DebugMsg.debugMsgID=DEBUGI2CWRITEAVR3DATA;
                        DebugMsg.args[index++] = data[1];
                        DebugMsg.args[index++] = data[2];
                        DebugMsg.args[index++] = data[3];
                }
                DebugMsg.args[index++] = numBytes-1;
                DebugMsg.args[index++] = n-1;
                DebugMsg.argNum = index;
                sendDebugPackets();
            }
        #endif
            status = Wire.endTransmission(sendstop);
	#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGI2CENDTRANSMISSIONAVR;
            DebugMsg.args[index++]=sendstop;
            DebugMsg.args[index++]=status;
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
        }
#if defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_NRF52840
        else
        {
            /* For now, only bus 0 and 1 are supported */

            Wire1.beginTransmission(address);
	#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGI2CBEGINTRANSMISSIONARM;
            DebugMsg.args[index++]=address;
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
            if(numBytes > 0)
            {
            n = Wire1.write(data, numBytes);
	#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGI2CWRITEARM;
            DebugMsg.args[index++]=data[0];
            DebugMsg.args[index++]=1;// one byte
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
            }
            
	#if DEBUG_FLAG == 2
            if(numBytes>1)
            {
                index = 0;
                switch (numBytes)
                {
                    case 2:
                        DebugMsg.debugMsgID=DEBUGI2CWRITEARM1DATA;
                        DebugMsg.args[index++] = data[1];
                        break;
                    case 3:
                        DebugMsg.debugMsgID=DEBUGI2CWRITEARM2DATA;
                        DebugMsg.args[index++] = data[1];
                        DebugMsg.args[index++] = data[2];
                        break;
                    default:
                        DebugMsg.debugMsgID=DEBUGI2CWRITEARM3DATA;
                        DebugMsg.args[index++] = data[1];
                        DebugMsg.args[index++] = data[2];
                        DebugMsg.args[index++] = data[3];
                }
                DebugMsg.args[index++] = numBytes-1;
                DebugMsg.args[index++] = n-1;
                DebugMsg.argNum = index;
                sendDebugPackets();
            }
	#endif
            status = Wire1.endTransmission(sendstop);
	#if DEBUG_FLAG == 2
            index=0;
            DebugMsg.debugMsgID=DEBUGI2CENDTRANSMISSIONARM;
            DebugMsg.args[index++]=sendstop;
            DebugMsg.args[index++]=status;
            DebugMsg.argNum = index;
            sendDebugPackets();
	#endif
        }
#endif
        if(status == 0)
        {
            return MW_I2C_SUCCESS;
        }
        else
        {
            /*TODO : check what error should I send */
            return  MW_I2C_BUS_ERROR;
        }
    }
    
    /* Read data on the slave device from a Master. Since, Arduino has no usecase to be used as slave leaving it empty  */
    MW_I2C_Status_Type MW_I2C_SlaveRead(MW_Handle_Type I2CModuleHandle, uint8_T * data, uint32_T DataLength, uint8_T SendNoAck)
    {
        return MW_I2C_SUCCESS;
    }
    
    /* Send the data to a master from the slave. Since, Arduino has no usecase to be used as slave leaving it empty  */
    MW_I2C_Status_Type MW_I2C_SlaveWrite(MW_Handle_Type I2CModuleHandle, uint8_T * data, uint32_T DataLength, uint8_T SendNoAck)
    {
        return MW_I2C_SUCCESS;
    }
    
    /* Get the status of I2C device */
    MW_I2C_Status_Type MW_I2C_GetStatus(MW_Handle_Type I2CModuleHandle)
    {
        return MW_I2C_SUCCESS;
    }
    
    /* Release I2C module */
    void MW_I2C_Close(MW_Handle_Type I2CModuleHandle)
    {
        uint8_T bus;
        bus = *((uint8_T*)(&I2CModuleHandle))- 1;
        hasBegin[bus] = false;
    }
    
#ifdef __cplusplus
}
#endif

#endif //IO_STANDARD_I2C