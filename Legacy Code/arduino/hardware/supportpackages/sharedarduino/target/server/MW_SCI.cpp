/* Copyright 2019-2021 The MathWorks, Inc. */
#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#include "MW_SCI.h"
#include "IO_peripheralInclude.h"

#if IO_STANDARD_SCI

// This macro ensure that MATLAB IO/Simulink IO over Serial doesn't use module 0 for SCI.
#define IO_SCI_MODULES_MIN 1

// This structure is used to store the baudrate and Frame format used, since arduino has only one API to do both
typedef struct _SerialParamters
{
    uint32_T baudRateSerial=9600;
    uint32_T timeOut = 1000;
    uint8_T numDataBits = 8;
    MW_SCI_Parity_Type parityType = MW_SCI_PARITY_NONE;
    MW_SCI_StopBits_Type stopBitsLength = MW_SCI_STOPBITS_1;
}SerialParamters;

SerialParamters serialPort1,serialPort2,serialPort3,serialPort4,serialPort5,serialPort6,serialPort7,serialPort8;

#ifdef __cplusplus
extern "C" {
#endif
    
// Function to recieve data from Arduino Serial Buffer.
    uint8_T serialRecieveBytes(uint8_T port, uint8_T * RxDataPtr, uint32_T RxDataLength);
    
// Function to get the frame format configuration of Arduino
    byte setconfig(HardwareSerial * ptrSerial,uint32_T BaudRate, uint8_T DataBitsLength, MW_SCI_Parity_Type parity, MW_SCI_StopBits_Type stopBits);
    
    /* Initialize a SCI */
    MW_Handle_Type MW_SCI_Open(void * SCIModule, uint8_T isString, uint32_T RxPin, uint32_T TxPin)
    {
        uint32_T port = 0;
        memcpy(&port,(uint32_T*)SCIModule, sizeof(uint32_T));
// For boards Arduino mega2560,megaADK and Due, Max usable SCI ports will be 3.
        //For teensy 4.1 max serial ports are 8
#if IO_SCI_MODULES_MAX == 8 || IO_SCI_MODULES_MAX == 7 || IO_SCI_MODULES_MAX == 3 || IO_SCI_MODULES_MAX == 2
        // open fails, if Serial 0 is given
        if((uint8_T)IO_SCI_MODULES_MIN <= port && port <=(uint8_T)IO_SCI_MODULES_MAX)
        {
            return (MW_Handle_Type)(port);
        }
        else
        {  //open fails if wrong port number is given
            return NULL;
        }
// For MKR Series and Leonardo
#elif IO_SCI_MODULES_MAX == 1
        if(port == IO_SCI_MODULES_MAX)
            return (MW_Handle_Type)(port);
        else
            // open fails for Invalid Port Number
            return NULL;
#else
        return NULL;
#endif
    }
    
    /* Set SCI frame format */
    MW_SCI_Status_Type MW_SCI_ConfigureHardwareFlowControl(MW_Handle_Type SCIModuleHandle, MW_SCI_HardwareFlowControl_Type HardwareFlowControl, uint32_T RtsDtrPin, uint32_T CtsDtsPin)
    {
        return MW_SCI_SUCCESS;
    }
    
    /* Set SCI TimeOut */
    MW_SCI_Status_Type MW_SCI_ConfigureTimeOut(MW_Handle_Type SCIModuleHandle, uint32_T timeOut)
    {
        uint8_T port = 0;
        uint8_T status = MW_SCI_BUS_ERROR;
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        switch(uint8_T(port))
        {
            case 1:
                serialPort1.timeOut = timeOut;
                Serial1.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                serialPort2.timeOut = timeOut;
                Serial2.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                serialPort3.timeOut = timeOut;
                Serial3.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 4
            case 4:
                serialPort4.timeOut = timeOut;
                Serial4.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 5
            case 5:
                serialPort5.timeOut = timeOut;
                Serial5.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 6
            case 6:
                serialPort6.timeOut = timeOut;
                Serial6.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
 #if IO_SCI_MODULES_MAX >= 7
            case 7:
                serialPort7.timeOut = timeOut;
                Serial7.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                serialPort8.timeOut = timeOut;
                Serial8.setTimeout(timeOut);
                status = MW_SCI_SUCCESS;
                break;
#endif
            default:
                status = MW_SCI_BUS_ERROR;
        }
#if DEBUG_FLAG == 2
        uint8_T num=0;
        DebugMsg.debugMsgID = DEBUGSCISETTIMEOUT;
        DebugMsg.args[num++]=port;
        DebugMsg.args[num++]=(uint8_T)timeOut;
        DebugMsg.args[num++]=(uint8_T)((timeOut & 0x0000ff00UL) >> 8);
        DebugMsg.args[num++]=(uint8_T)((timeOut & 0x00ff0000UL) >> 16);
        DebugMsg.args[num++]=(uint8_T)((timeOut & 0xff000000UL) >> 24);
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        return MW_SCI_SUCCESS;
    }
    
    /* Set the SCI bus speed */
    MW_SCI_Status_Type MW_SCI_SetBaudrate(MW_Handle_Type SCIModuleHandle, uint32_T baudRate)
    {
        uint8_T port = 0;
        uint8_T status = MW_SCI_BUS_ERROR;
        // SCIModuleHandle is set as module + 1 in PeripheraltoHandle.c
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        switch(uint8_T(port))
        {
            case 1:
                serialPort1.baudRateSerial = baudRate;
                status = setconfig(&Serial1,baudRate,serialPort1.numDataBits,serialPort1.parityType,serialPort1.stopBitsLength);
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                serialPort2.baudRateSerial = baudRate;
                status = setconfig(&Serial2,baudRate,serialPort2.numDataBits,serialPort2.parityType,serialPort2.stopBitsLength);
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                serialPort3.baudRateSerial = baudRate;
                status = setconfig(&Serial3,baudRate,serialPort3.numDataBits,serialPort3.parityType,serialPort3.stopBitsLength);
                break;
#endif
 #if IO_SCI_MODULES_MAX >= 4
            case 4:
                serialPort4.baudRateSerial = baudRate;
                status = setconfig(&Serial4,baudRate,serialPort4.numDataBits,serialPort4.parityType,serialPort4.stopBitsLength);
                break;
#endif
 #if IO_SCI_MODULES_MAX >= 5
            case 5:
                serialPort5.baudRateSerial = baudRate;
                status = setconfig(&Serial5,baudRate,serialPort5.numDataBits,serialPort5.parityType,serialPort5.stopBitsLength);
                break;
#endif
#if IO_SCI_MODULES_MAX >= 6
            case 6:
                serialPort6.baudRateSerial = baudRate;
                status = setconfig(&Serial6,baudRate,serialPort6.numDataBits,serialPort6.parityType,serialPort6.stopBitsLength);
                break;
#endif
#if IO_SCI_MODULES_MAX >= 7
            case 7:
                serialPort7.baudRateSerial = baudRate;
                status = setconfig(&Serial7,baudRate,serialPort7.numDataBits,serialPort7.parityType,serialPort7.stopBitsLength);
                break;
#endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                serialPort8.baudRateSerial = baudRate;
                status = setconfig(&Serial8,baudRate,serialPort8.numDataBits,serialPort8.parityType,serialPort8.stopBitsLength);
                break;
#endif
            default:
                status = MW_SCI_BUS_ERROR;
        }
        return (MW_SCI_Status_Type)(status);
    }
    
    
    /* Set SCI frame format */
    MW_SCI_Status_Type MW_SCI_SetFrameFormat(MW_Handle_Type SCIModuleHandle, uint8_T DataBitsLength, MW_SCI_Parity_Type Parity, MW_SCI_StopBits_Type StopBits)
    {
        uint8_T port = 0;
        uint8_T status = MW_SCI_SUCCESS;
        uint32_T baudRate;
        // SCIModuleHandle is set as module + 1 in PeripheraltoHandle.c
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        
        HardwareSerial *ptrSerial;
        SerialParamters *ptrSerialParameters;
        // Gets the baudrate from structure which stores the configuration of Serial Port and stores the frame format configuration in the structure
        switch(uint8_T(port))
        {
            case 1:
                ptrSerial = &Serial1;
                ptrSerialParameters = &serialPort1;
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                ptrSerial = &Serial2;
                ptrSerialParameters = &serialPort2;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                ptrSerial = &Serial3;
                ptrSerialParameters = &serialPort3;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 4
            case 4:
                ptrSerial = &Serial4;
                ptrSerialParameters = &serialPort4;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 5
            case 5:
                ptrSerial = &Serial5;
                ptrSerialParameters = &serialPort5;
                break;
#endif
 #if IO_SCI_MODULES_MAX >= 6
            case 6:
                ptrSerial = &Serial6;
                ptrSerialParameters = &serialPort6;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 7
            case 7:
                ptrSerial = &Serial7;
                ptrSerialParameters = &serialPort7;
                break;
#endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                ptrSerial = &Serial8;
                ptrSerialParameters = &serialPort8;
                break;
#endif
            default:
                status = MW_SCI_BUS_ERROR;
        }
        ptrSerialParameters->numDataBits = DataBitsLength;
        ptrSerialParameters->parityType = Parity;
        ptrSerialParameters->stopBitsLength = StopBits;
        status = setconfig(ptrSerial, ptrSerialParameters->baudRateSerial,DataBitsLength,Parity,StopBits);
        return (MW_SCI_Status_Type)(status);
    }
    
    /* Trasmit the series of bytes of data over SCI */
    MW_SCI_Status_Type MW_SCI_Transmit(MW_Handle_Type SCIModuleHandle, uint8_T * TxDataPtr, uint32_T TxDataLength)
    {
        uint8_T port = 0;
        uint8_T status = MW_SCI_BUS_ERROR;
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        switch(uint8_T(port))
        {
            case 1:
                Serial1.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                Serial2.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                Serial3.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 4
            case 4:
                Serial4.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 5
            case 5:
                Serial5.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 6
            case 6:
                Serial6.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
 #endif
 #if IO_SCI_MODULES_MAX >= 7
            case 7:
                Serial7.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                Serial8.write(TxDataPtr,TxDataLength);
                status = MW_SCI_SUCCESS;
                break;
#endif
            default:
                status = MW_SCI_BUS_ERROR;
        }
#if DEBUG_FLAG == 2
        uint8_T num=0;
        DebugMsg.args[num++]=port;
        if(TxDataLength==1)
        {
            DebugMsg.debugMsgID = DEBUGSCIWRITE1BYTE;
            DebugMsg.args[num++]=*TxDataPtr;
        }
        else if(TxDataLength==2)
        {
            DebugMsg.debugMsgID = DEBUGSCIWRITE2BYTE;
            DebugMsg.args[num++]=*TxDataPtr;
            DebugMsg.args[num++]=*(TxDataPtr+1);
        }
        else if(TxDataLength>2)
        {
            /* Only first three bytes will be printed in the debug message */
            DebugMsg.debugMsgID = DEBUGSCIWRITE3BYTE;
            DebugMsg.args[num++]=*TxDataPtr;
            DebugMsg.args[num++]=*(TxDataPtr+1);
            DebugMsg.args[num++]=*(TxDataPtr+2);
        }
        DebugMsg.args[num++]=TxDataLength;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        return (MW_SCI_Status_Type)(status);
    }
    
    
    /* Receive the data over SCI */
    MW_SCI_Status_Type MW_SCI_Receive(MW_Handle_Type SCIModuleHandle, uint8_T * RxDataPtr, uint32_T RxDataLength)
    {
        
        uint8_T port = 0;
        uint8_T status = 0;
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        status = serialRecieveBytes(port,RxDataPtr,RxDataLength);
        
        return (MW_SCI_Status_Type)(status);
    }
    
    /* Get the status of SCI device */
    MW_SCI_Status_Type MW_SCI_GetStatus(MW_Handle_Type SCIModuleHandle)
    {
        uint8_T port = 0;
        uint8_T status = MW_SCI_BUS_ERROR;
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        switch(uint8_T(port))
        {
            case 1:
                status = Serial1.available();
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                status = Serial2.available();
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                status = Serial3.available();
                break;
#endif
#if IO_SCI_MODULES_MAX >= 4
            case 4:
                status = Serial4.available();
                break;
#endif
#if IO_SCI_MODULES_MAX >= 5
            case 5:
                status = Serial5.available();
                break;
 #endif
#if IO_SCI_MODULES_MAX >= 6
            case 6:
                status = Serial6.available();
                break;
#endif
#if IO_SCI_MODULES_MAX >= 7
            case 7:
                status = Serial7.available();
                break;
#endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                status = Serial8.available();
                break;
#endif
            default:
                status = MW_SCI_BUS_ERROR;
        }
#if DEBUG_FLAG == 2
        uint8_T num=0;
        DebugMsg.debugMsgID = DEBUGSCIAVAILABLE;
        DebugMsg.args[num++]= port;
        DebugMsg.args[num++]= status;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        return (MW_SCI_Status_Type)(status);
    }
    
    /* Send break command */
    MW_SCI_Status_Type MW_SCI_SendBreak(MW_Handle_Type SCIModuleHandle)
    {
        return MW_SCI_SUCCESS;
    }
    
    /* Release SCI module */
    void MW_SCI_Close(MW_Handle_Type SCIModuleHandle)
    {
        uint8_T port = 0;
        uint8_T status = MW_SCI_BUS_ERROR;
        memcpy(&port,&SCIModuleHandle, sizeof(uint8_T));
        port=port-1;
        switch(uint8_T(port))
        {
            case 1:
                Serial1.end();
                status = MW_SCI_SUCCESS;
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                Serial2.end();
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                Serial3.end();
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 4
            case 4:
                Serial4.end();
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 5
            case 5:
                Serial5.end();
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 6
            case 6:
                Serial6.end();
                status = MW_SCI_SUCCESS;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 7
            case 7:
                Serial7.end();
                status = MW_SCI_SUCCESS;
                break;
 #endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                Serial8.end();
                status = MW_SCI_SUCCESS;
                break;
#endif
                
#if DEBUG_FLAG == 2
                uint8_T num=0;
                DebugMsg.debugMsgID = DEBUGSCIEND;
                DebugMsg.args[num++]=port;
                DebugMsg.argNum = num;
                sendDebugPackets();
#endif
        }
    }
    
    
    uint8_T serialRecieveBytes(uint8_T port,uint8_T *RxDataPtr, uint32_T RxDataLength)
    {
        // This function reads the reads the Oldest complete frame available in the Serial Buffer.
        uint8_T status = MW_SCI_DATA_NOT_AVAILABLE;
        uint8_T numBytesSerialbuffer = 0;
        uint32_T timeOutVal;
        HardwareSerial *ptrSerial;
        SerialParamters *ptrSerialParameters;
        switch(uint8_T(port))
        {
            case 1:
                ptrSerial = &Serial1;
                ptrSerialParameters = &serialPort1;
                break;
#if IO_SCI_MODULES_MAX >= 2
            case 2:
                ptrSerial = &Serial2;
                ptrSerialParameters = &serialPort2;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 3
            case 3:
                ptrSerial = &Serial3;
                ptrSerialParameters = &serialPort3;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 4
            case 4:
                ptrSerial = &Serial4;
                ptrSerialParameters = &serialPort4;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 5
            case 5:
                ptrSerial = &Serial5;
                ptrSerialParameters = &serialPort5;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 6
            case 6:
                ptrSerial = &Serial6;
                ptrSerialParameters = &serialPort6;
                break;
#endif
#if IO_SCI_MODULES_MAX >= 7
            case 7:
                ptrSerial = &Serial7;
                ptrSerialParameters = &serialPort7;
                break;
#endif
#if IO_SCI_MODULES_MAX == 8
            case 8:
                ptrSerial = &Serial8;
                ptrSerialParameters = &serialPort8;
                break;
#endif
        }
        timeOutVal = millis()+ ptrSerialParameters->timeOut;
        while(millis() <= timeOutVal)
        {
            numBytesSerialbuffer = ptrSerial->available();
            if(numBytesSerialbuffer >= RxDataLength)
                break;
        }
#if DEBUG_FLAG == 2
        if(millis()> timeOutVal || numBytesSerialbuffer >= RxDataLength)
        {
            uint8_T num=0;
            DebugMsg.debugMsgID = DEBUGSCIAVAILABLE;
            DebugMsg.args[num++]=port;
            DebugMsg.args[num++]= numBytesSerialbuffer;
            DebugMsg.argNum = num;
            sendDebugPackets();
        }
#endif
        if(numBytesSerialbuffer >= RxDataLength)
        {
            ptrSerial->readBytes(RxDataPtr,RxDataLength);
#if DEBUG_FLAG == 2
            uint8_T num=0;
            DebugMsg.args[num++]=port;
            if(RxDataLength==1)
            {
                DebugMsg.debugMsgID = DEBUGSCIREAD1BYTE;
                DebugMsg.args[num++]=*RxDataPtr;
            }
            else if(RxDataLength==2)
            {
                DebugMsg.debugMsgID = DEBUGSCIREAD2BYTE;
                DebugMsg.args[num++]=*RxDataPtr;
                DebugMsg.args[num++]=*(RxDataPtr+1);
            }
            else if(RxDataLength>2)
            {
                /* Only first three bytes will be printed in the debug message */
                DebugMsg.debugMsgID = DEBUGSCIREAD3BYTE;
                DebugMsg.args[num++]=*RxDataPtr;
                DebugMsg.args[num++]=*(RxDataPtr+1);
                DebugMsg.args[num++]=*(RxDataPtr+2);
            }
            DebugMsg.args[num++]=RxDataLength;
            DebugMsg.argNum = num;
            sendDebugPackets();
#endif
            status = MW_SCI_SUCCESS;
        }
        else
        {
            for(int ii=0;ii< RxDataLength;ii++)
            {
                *RxDataPtr++ = 0;
            }
            if(numBytesSerialbuffer > 0)
                status = (MW_SCI_Status_Type)numBytesSerialbuffer;
            /*If data points are not available, return data = 0; and status = MW_SCI_DATA_NOT_AVAILABLE */
            else
                status = MW_SCI_DATA_NOT_AVAILABLE;
        }
        return status;
    }
    
    byte setconfig(HardwareSerial *SerialPointer,uint32_T BaudRate,uint8_T DataBitsLength, MW_SCI_Parity_Type Parity, MW_SCI_StopBits_Type StopBits)
    {
        
        byte status  = MW_SCI_SUCCESS;
#ifdef ARDUINO_ARCH_SAM
        // for Arduino Due, the function begin with configuration parameter is in USART class.
        USARTClass *ptrSerial;
        ptrSerial = (USARTClass *)SerialPointer;
#else
        HardwareSerial *ptrSerial = SerialPointer;
#endif
        #if (defined(ARDUINO_TEENSY40) ||defined(ARDUINO_TEENSY41))
             ptrSerial->begin(BaudRate);
         #else
        if ((DataBitsLength == 5 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_1))
        {
            ptrSerial->begin(BaudRate, SERIAL_5N1);
        }
        else if ((DataBitsLength == 6 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_1))
        {
            ptrSerial->begin(BaudRate, SERIAL_6N1);
        }
        else if (DataBitsLength == 7 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate,SERIAL_7N1);
        }
        else if (DataBitsLength == 8 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_8N1);
        }
        else if (DataBitsLength == 5 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_5N2);
        }
        else if (DataBitsLength == 6 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_6N2);
        }
        else if (DataBitsLength == 7 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_7N2);
        }
        else if (DataBitsLength == 8 && Parity == MW_SCI_PARITY_NONE && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_8N2);
        }
        else if (DataBitsLength == 5 && Parity == MW_SCI_PARITY_EVEN && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_5E1);
        }
        else if (DataBitsLength == 6 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_6E1);
        }
        else if (DataBitsLength == 7 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_7E1);
        }
        else if (DataBitsLength == 8 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate,SERIAL_8E1);
        }
        else if (DataBitsLength == 5 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_5E2);
        }
        else if (DataBitsLength == 6 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_6E2);
        }
        else if (DataBitsLength == 7 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate,SERIAL_7E2);
        }
        else if (DataBitsLength == 8 && Parity == MW_SCI_PARITY_EVEN  && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_8E2);
        }
        else if (DataBitsLength == 5 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_5O1);
            
        }
        else if (DataBitsLength == 6 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_6O1);
        }
        else if (DataBitsLength == 7 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_7O1);
        }
        else if (DataBitsLength == 8 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_1)
        {
            ptrSerial->begin(BaudRate, SERIAL_8O1);
        }
        else if (DataBitsLength == 5 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_5O2);
        }
        else if (DataBitsLength == 6 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_6O2);
        }
        else if (DataBitsLength == 7 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_7O2);
        }
        else if (DataBitsLength == 8 && Parity == MW_SCI_PARITY_ODD && StopBits == MW_SCI_STOPBITS_2)
        {
            ptrSerial->begin(BaudRate, SERIAL_8O2);
        }
        else
        {
            status = MW_SCI_FRAME_ERROR;
        }
         #endif
#if DEBUG_FLAG == 2
        uint8_T port = 0;
        uint8_T num=0;
        if(ptrSerial==&Serial1)
            port = 1;
#if IO_SCI_MODULES_MAX >= 2
        else if (ptrSerial==&Serial2)
            port = 2;
#endif
#if IO_SCI_MODULES_MAX >= 3
        else if (ptrSerial==&Serial3)
            port = 3;
#endif
 #if IO_SCI_MODULES_MAX >= 4
        else if (ptrSerial==&Serial4)
            port = 4;
#endif
#if IO_SCI_MODULES_MAX >= 5
        else if (ptrSerial==&Serial5)
            port = 5;
#endif
#if IO_SCI_MODULES_MAX >= 6
        else if (ptrSerial==&Serial6)
            port = 6;
#endif
 #if IO_SCI_MODULES_MAX >= 7
        else if (ptrSerial==&Serial7)
            port = 7;
#endif
#if IO_SCI_MODULES_MAX == 8
        else if (ptrSerial==&Serial8)
            port = 8;
#endif
        DebugMsg.debugMsgID = DEBUGSCIBEGIN;
        DebugMsg.args[num++]=port;
        DebugMsg.args[num++]=(uint8_T)BaudRate;
        DebugMsg.args[num++]=(uint8_T)((BaudRate & 0x0000ff00UL) >> 8);
        DebugMsg.args[num++]=(uint8_T)((BaudRate & 0x00ff0000UL) >> 16);
        DebugMsg.args[num++]=(uint8_T)((BaudRate & 0xff000000UL) >> 24);
        DebugMsg.args[num++]=DataBitsLength;
        DebugMsg.args[num++]=Parity;
        DebugMsg.args[num++]=StopBits;
        DebugMsg.argNum = num;
        sendDebugPackets();
#endif
        return status;
    }
    
#ifdef __cplusplus
}
#endif

#endif //IO_STANDARD_SCI
