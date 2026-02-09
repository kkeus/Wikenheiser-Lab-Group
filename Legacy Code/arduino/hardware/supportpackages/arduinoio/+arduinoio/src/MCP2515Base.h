/**
 * @file MCP2515Base.h
 *
 * Class definition for MCP2515 based shields working with ACAN2515 library
 *
 * @copyright Copyright 2019-2020 The MathWorks, Inc.
 *
 */

#include "LibraryBase.h"
#include <ACAN2515.h>

ACAN2515 *can = nullptr;

uint8_T csGlobal = 0;
uint8_T intGlobal = 0;

#define CAN_ATTACH 0x00
#define CAN_DETACH 0x01
#define CAN_READ   0x02
#define CAN_WRITE  0x03
#define CAN_MODE   0x04

// Arduino trace commands
const char MSG_CAN_ATTACH[]        PROGMEM = "MCP2515::attach(CSPin(%u), InterruptPin(%u), QuartzFrequency(%lu), DesiredBitRate(%lu));\n";
const char MSG_CAN_DETACH[]        PROGMEM = "MCP2515::detach(%u);\n";
const char MSG_CAN_READ[]          PROGMEM = "MCP2515::read(%u)->id(%lu), ext(%u), len(%u), data(%u, %u, %u, %u, %u, %u, %u, %u);\n";
const char MSG_CAN_ERROR[]         PROGMEM = "MCP2515::error(%u)->value(%d);\n";
const char MSG_CAN_WRITE[]         PROGMEM = "MCP2515::write(%u)->id(%lu), ext(%u), len(%u), data(%u, %u, %u, %u, %u, %u, %u, %u);\n";
const char MSG_CAN_MODE[]          PROGMEM = "MCP2515::mode(%u)->Silent(%d), errorcode(%d);\n";

const char MSG_ARDUINO_SPI_INTRPT[] PROGMEM = "Arduino::SPI.notUsingInterrupt(%u);\n";

void canISR () 
{
    can->isr () ;
}
        
class MCP2515Base : public LibraryBase
{
    public:
        MCP2515Base(MWArduinoClass& a)
        {
            libName = "CAN";
            a.registerLibrary(this);
        }
        
        void setup()
        {
            can = NULL;
        }
        
    public:
        void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
        {
            /* ext(1), id(4), rtr(1), len(1), data(8) = 15 bytes in total - Maximum to be used across all cases */
            uint8_T result[15] {0};
            uint8_T resultLength = 0;
            switch (cmdID){
                case CAN_ATTACH:
                {
                    uint8_T cs;
                    uint8_T index;
                    uint8_T interruptPin;
                    uint32_T busSpeed, oscFreq;
                    
                    // Fetch the CAN channel number (Chip Select)
                    memcpy(&cs, &dataIn[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                    csGlobal = cs;
                    
                    // Fetch the Interrupt Pin Number
                    memcpy(&interruptPin, &dataIn[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                    intGlobal = interruptPin;
                    
                    // Fetch the oscillator frequency of the CAN Shield
                    memcpy(&oscFreq, &dataIn[index], sizeof(uint32_T));
                    index += sizeof(uint32_T);
                    
                    // Fetch the bus speed of interest
                    memcpy(&busSpeed, &dataIn[index], sizeof(uint32_T));
                    index += sizeof(uint32_T);
                    
                    if (nullptr == can)
                    {
                        can = new ACAN2515(cs, SPI, interruptPin);
                    }

                    ACAN2515Settings settings (oscFreq, busSpeed);
                    settings.mRequestedMode = ACAN2515Settings::NormalMode; // Select Normal mode
                    // Reducing the number of TX buffers from 16 to 1 in want of more free memory on Uno
                    settings.mTransmitBuffer0Size = 1;
                    // Reducing the number of RX buffers from 32 to 10 in want of more free memory on Uno
                    settings.mReceiveBufferSize = 10;

                    debugPrint(MSG_CAN_ATTACH, cs, interruptPin, settings.mQuartzFrequency, settings.mDesiredBitRate);
                    
                    const uint16_t errorCode = can->begin (settings, canISR);
                    
                    if(errorCode == 0)
                    {
                        uint32_T actualBitRate = settings.actualBitRate();
                        result[resultLength++] = (uint8_T)(actualBitRate & 0x000000ffUL);
                        result[resultLength++] = (uint8_T)((actualBitRate & 0x0000ff00UL) >> 8);
                        result[resultLength++] = (uint8_T)((actualBitRate & 0x00ff0000UL) >> 16);
                        result[resultLength++] = (uint8_T)((actualBitRate & 0xff000000UL) >> 24);
                    }
                    else
                    {
                        result[resultLength++] = errorCode;
                        debugPrint(MSG_CAN_ERROR, cs, errorCode);
                    }
                    break;
                }
                case CAN_DETACH:
                { 
                    if (nullptr != can)
                    {
                        #if defined(ARDUINO_ARCH_SAMD)
                            // Bug in ACAN2515 3P library for SAMD. Incorporating the undocumented API notUsingInterrupt seems to fix it. Other arch's doesn't seem to need this. This is not implemented in SAM.
                            SPI.notUsingInterrupt (digitalPinToInterrupt (intGlobal));
                            debugPrint(MSG_ARDUINO_SPI_INTRPT, intGlobal);
                        #endif
                        // Detach interrupt and free receive and transmit buffers
                        can->end();
                        delete can;
                        can = nullptr;
                        
                        debugPrint(MSG_CAN_DETACH, csGlobal);
                    }
                    else
                    {
                        debugPrint(MSG_CAN_ERROR, csGlobal, 255);
                        result[resultLength++] = 255;
                    }
                    break;
                }
                case CAN_READ:
                { 
                    CANMessage frame;
                    
                    if (nullptr != can)
                    {
                        if (can->available())
                        {
                            can->receive (frame);
                            // Extract type of frame
                            result[resultLength++] = frame.ext ? 1 : 0; // 1 => extended. 0 => standard
                            // Extract ID of frame
                            result[resultLength++] = (uint8_T)(frame.id & 0x000000ffUL);
                            result[resultLength++] = (uint8_T)((frame.id & 0x0000ff00UL) >> 8);
                            result[resultLength++] = (uint8_T)((frame.id & 0x00ff0000UL) >> 16);
                            result[resultLength++] = (uint8_T)((frame.id & 0xff000000UL) >> 24);
                            // Extract RTR from frame
                            result[resultLength++] = frame.rtr ? 1 : 0; // 1 => Remote. 0 => Not Remote
                            // Extract Length of data in frame
                            result[resultLength++] = frame.len;
                            // Extract data of non-RTR frame
                            memcpy(&result[resultLength], frame.data, frame.len * sizeof(uint8_T));
                            resultLength += frame.len;
                            
                            uint8_T dispDataArr[8]{0}, i;
                            for(i = 0 ; i < frame.len ; i++)
                            {
                                dispDataArr[i] = frame.data[i];
                            }
                            debugPrint(MSG_CAN_READ, csGlobal, frame.id, frame.ext, frame.len, dispDataArr[0], dispDataArr[1], dispDataArr[2], dispDataArr[3], 
    dispDataArr[4], dispDataArr[5], dispDataArr[6], dispDataArr[7]);
                        }
                        if(resultLength == 0)
                        {
                            debugPrint(MSG_CAN_ERROR, csGlobal, 3);
                            resultLength = 1;
                        }
                    }
                    else
                    {
                        debugPrint(MSG_CAN_ERROR, csGlobal, 255);
                        result[resultLength++] = 255;
                    }
                    break;
                }
                case CAN_WRITE:
                { 
                    uint8_T canType, datalen;
                    uint8_T index = 0;
                    uint32_T canID;
                    CANMessage frame;
                    
                    // Fetch the Identifier of the message to be transmitted
                    memcpy(&canID, &dataIn[index], sizeof(uint32_T));
                    index += sizeof(uint32_T);
                    
                    // Fetch the type of can Message
                    memcpy(&canType, &dataIn[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                    
                    // Fetch the length of CAN data to be transmitted
                    memcpy(&datalen, &dataIn[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);
                    
                    // Fetch the data to be transmitted
                    uint8_T data[datalen];
                    memcpy(data, &dataIn[index], datalen * sizeof(uint8_T));
                    index += datalen * sizeof(uint8_T);
                    
                    frame.id = canID;
                    frame.ext = canType ? true : false; // 0 for Standard; 1 for Extended.
                    frame.len = datalen;
                    memcpy(frame.data, data, datalen * sizeof(uint8_T));
                    
                    if (nullptr != can)
                    {
                        result[resultLength++] = can->tryToSend(frame);
                        if (result[0])
                        {
                            uint8_T dispDataArr[8]{0}, i;
                            for(i = 0 ; i < datalen ; i++)
                            {
                                dispDataArr[i] = data[i];
                            }
                            debugPrint(MSG_CAN_WRITE, csGlobal, frame.id, frame.ext, frame.len, dispDataArr[0], dispDataArr[1], dispDataArr[2], dispDataArr[3], 
    dispDataArr[4], dispDataArr[5], dispDataArr[6], dispDataArr[7]);
                        }
                        else
                        {
                            debugPrint(MSG_CAN_ERROR, csGlobal, result[0]);
                        }
                    }
                    else
                    {
                        debugPrint(MSG_CAN_ERROR, csGlobal, 255);
                        result[resultLength++] = 255;
                    }
                    break;
                }
                
                case CAN_MODE:
                {
                    uint8_T index = 0;
                    uint8_T mode = 0;
                    uint16_T errorCode = 0;
                    
                    // Fetch the operating mode of MCP2515
                    memcpy(&mode, &dataIn[index], sizeof(uint8_T));
                    index += sizeof(uint8_T);

                    if (nullptr != can)
                    {
                        errorCode = can->changeModeOnTheFly(mode ? ACAN2515Settings::ListenOnlyMode : ACAN2515Settings::NormalMode);
                        debugPrint(MSG_CAN_MODE, csGlobal, mode, errorCode);
                        result[resultLength++] = (uint8_T)(errorCode & 0x00ffUL);
                        result[resultLength++] = (uint8_T)((errorCode & 0xff00UL) >> 8);
                    }
                    else
                    {
                        debugPrint(MSG_CAN_ERROR, csGlobal, 255);
                        result[resultLength++] = 255;
                    }
                    
                    break;
                }
                
                default:
                    break;
            }
            sendResponseMsg(cmdID, result, resultLength);
        }
};