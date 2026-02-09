/*
 * File: rtiostream_serial.cpp
 * Copyright 2011-2020 The MathWorks, Inc.
 */

#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif
#if defined (EXT_MODE)
#include "MW_target_hardware_resources.h"
#define EXPECTED_FIRSTBYTE_SERIAL_DAEMON ('e')
#define SERIAL_COMPORTBAUDRATE MW_EXTMODE_COMPORTBAUD
#else
#include "MacroIncludeIO.h"
#define EXPECTED_FIRSTBYTE_SERIAL_DAEMON CUSTOM_EXPECTED_FIRSTBYTE_SERIAL
#define SERIAL_COMPORTBAUDRATE CUSTOM_SERIAL_COMPORTBAUD
#endif

#ifndef _rtiostream

extern "C" {
#include "rtiostream.h"
}
#define _rtiostream
#endif

extern "C" void __cxa_pure_virtual(void);

volatile boolean receivedSyncByteE = false;

/* Function: rtIOStreamOpen =================================================
 * Abstract:
 *  Open the connection with the target.
 */
int rtIOStreamOpen(int argc, void * argv[])
{
    /* ASCII character a is 65 */
    #define RTIOSTREAM_OPEN_COMPLETE 65
    static const uint8_t init_complete = RTIOSTREAM_OPEN_COMPLETE;
    
    int result = RTIOSTREAM_NO_ERROR;
    int flushedData;
     
//     #ifndef MW_PIL_ARUDINOSERIAL //commented due to Serial1 not working with external mode in MKR1000
//     init();
//     #endif

    #if defined(MW_PIL_ARUDINOSERIAL)
        serialPort.begin(MW_PIL_SERIAL_BAUDRATE);
        
        /* At high baud rates (i.e. 115200), the Arduino is receiving an 
         * initial byte of spurious data (0xF0 / 240) when opening a connection
         * even though the host has not transmitted this data! This is causing
         * an issue for PIL to read wrong init bytes at the beginning and
         * loosing sync with host. Adding delay of 1 sec to wait for host to
         * open the connection and then flush the spurious data from receive
         * buffer. A delay of 5Sec(rtiostream postopenpause) is given on the
         * host between opening the connection and init bytes.
        */ 
        delay(1000);
    #else  
        serialPort.begin(SERIAL_COMPORTBAUDRATE);
    #endif
   
    /* Flush out the serial receive buffer when opening a connection. This
     * works around an issue we've noticed with Arduino at high baud rates.
     * At high baud rates (i.e. 115200), the Arduino is receiving an 
     * initial byte of spurious data (0xF0 / 240) even though the host has
     * not transmitted this data! This may cause an issue for PIL and 
     * External mode during the handshaking process.
     */
    while (serialPort.available()) {
        flushedData = serialPort.read();
    }
    
    return result;
}

/* Function: rtIOStreamSend =====================================================
 * Abstract:
 *  Sends the specified number of bytes on the serial line. Returns the number of
 *  bytes sent (if successful) or a negative value if an error occurred.
 */
int rtIOStreamSend(
    int          streamID,
    const void * src,
    size_t       size,
    size_t     * sizeSent)
{
    //clearInt();
    serialPort.write( (const uint8_t *)src, (int16_t)size);
    //enableInt();
    
    *sizeSent = size;
     
    return RTIOSTREAM_NO_ERROR;
}

/* Function: rtIOStreamRecv ================================================
 * Abstract: receive data
 *
 */
int rtIOStreamRecv(
    int      streamID,
    void   * dst,
    size_t   size,
    size_t * sizeRecvd)
{
    int data;
    uint8_t * ptr = (uint8_t *)dst;
  
    *sizeRecvd = 0U;
    
    if (!serialPort.available()) {
        return RTIOSTREAM_NO_ERROR;
    }

    while( !receivedSyncByteE ){
        data = serialPort.read();
        if(data == EXPECTED_FIRSTBYTE_SERIAL_DAEMON){
            receivedSyncByteE = true;
            *ptr++ = (uint8_t)data;
            (*sizeRecvd)++;
        }
    }

    while ((*sizeRecvd < size)) {
        data = serialPort.read();
        if (data!=-1) {
            *ptr++ = (uint8_t) data;
            (*sizeRecvd)++;
        }
    }

    return RTIOSTREAM_NO_ERROR;
}

/* Function: rtIOStreamClose ================================================
 * Abstract: close the connection.
 * For Arduino Leonardo and its variants, the Virtual COM port is handled 
 * by the controller. In case the code running on the target exits main,
 * the COM port cannot be accessed until a hard reset is performed.
 * To over come this issue, a while loop is added to make sure that 
 * upon getting a stop command from external mode, the code running on
 * the target stops but the code will not exit the main.
 * This will ensure that the COM port is accessible even after the 
 * external mode has been stopped. 
 *
 *For External mode over serial, Arduino leonardo and its variats require
 *a flush out the serial receive buffer. This is done to get the last 
 * acknowledgement 
 *
 */
int rtIOStreamClose(int streamID)
{
    delay(1000);
#if defined(_ROTH_LEONARDO_) || defined(_ROTH_MKR1000_) ||  defined(_ROTH_MKRZERO_) || defined(_ROTH_MKRWIFI1010_) || defined(_ROTH_NANO33_IOT_) || defined(ARDUINO_VIRTUAL_COM_PORT)
    int flushedData;
    while (serialPort.available()) {
        flushedData = serialPort.read();
    }
    while(1){
        //wait to process any USB requests.
    }
#endif
    return RTIOSTREAM_NO_ERROR;
}
