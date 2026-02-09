/*
 * @file rtiostream_ble.cpp
 * rtiostream APIs implementation for BLE transport
 * @copyright Copyright 2021-2023 The MathWorks, Inc.
 */

#include "Arduino.h"
#include "MacroIncludeIO.h"

#ifndef _ArduinoBLE_h_
#define _ArduinoBLE_h_
#ifdef ESP_BLE
/* Include ESP BLE Libraries */
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEAdvertisedDevice.h>
#include <BLEServer.h>
#include <BLEAddress.h>
#include <BLECharacteristic.h>
#include <BLE2902.h>
#else
#include "ArduinoBLE.h"
#endif
#endif

#ifndef _rtiostream
extern "C" {
#include "rtiostream.h"
}
#define _rtiostream
#endif

const String blecmd = "whatisyouraddress";
const uint8_t blecmdNumBytes = blecmd.length();

const String blenamecmd = "whatisyourname";
const uint8_t blenamecmdNumBytes = blenamecmd.length();

const String blelibrariescmd = "whatisyourlibrarylist";
const uint8_t blelibrariescmdNumBytes = blelibrariescmd.length();
/* Defining BLE Macros */
/* Name of the peripheral that can be seen in the BLE advertising packet*/
#ifndef BLEADVERTISINGNAME
#define BLEADVERTISINGNAME "BLEIOServer"
#endif
/* Name of the BLE service */
#ifndef SERVICENAME
#define SERVICENAME IOService
#endif
/* 128-bit UUID of the BLE service */
#ifndef SERVICEUUID
#define SERVICEUUID "bec069d9-e1dc-49c4-8a05-f14198ed6e57"
#endif
/* Name of the BLE characteristic to which central device can write */
#ifndef WRITECHARACTERISTICNAME
#define WRITECHARACTERISTICNAME IOWriteCharacteristic
#endif
/* 128-bit UUID of the write characteristic */
#ifndef WRITECHARACTERISTICUUID
#define WRITECHARACTERISTICUUID "3236de8b-f993-48d0-9688-0c6c9ed5f6d1"
#endif
/* Name of the BLE characteristic from which central reads */
#ifndef READCHARACTERISTICNAME
#define READCHARACTERISTICNAME IOReadCharacteristic
#endif
/* 128-bit UUID of the read characteristic */
#ifndef READCHARACTERISTICUUID
#define READCHARACTERISTICUUID "f9eab5de-92e7-457e-b640-8bc64fc6ed7c"
#endif
/* Max size of the packet / characteristic */
#ifndef MAX_PACKET_SIZE
#define MAX_PACKET_SIZE 512
#endif
/* Error out if Max packet size is greater than 512 as the BLE characteristic doesn't support length greater than 512 */
#if (MAX_PACKET_SIZE > 512)
#error "Max packet size should be less than or equal to 512 for BLE transport."
#endif

/* Working of BLE communication between IOServer and IOClient:
  Target has the IOServer running. This will act as BLE Peripheral device. IOServer writes the responses to READCHARACTERISTIC which also notifies MATLAB.
  MATLAB is the IOClient. This will act as BLE Central device. MATLAB writes the commands to WRITECHARACTERISTIC. */

/* For ESP devices */
#ifdef ESP_BLE
/* Create BLE Server and Service pointers */
BLEServer *pServer;
BLEService *pService;
/* Create Write and Read characteristic pointers */
BLECharacteristic WRITECHARACTERISTIC = BLECharacteristic(WRITECHARACTERISTICUUID,  BLECharacteristic::PROPERTY_WRITE);
BLECharacteristic READCHARACTERISTIC = BLECharacteristic(READCHARACTERISTICUUID,  BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);

/* Create BLE2902 - this is required for the descriptor*/
BLE2902* p2902 = new BLE2902();

/* Create advertising pointer */
BLEAdvertising *pAdvertising;

/* Global variable indicates if data is written via Write characteristics */
bool isWritten = false;

/* Define callback when data is written */
class customCallBackForWrite: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      /* Set this variable to true when data is written*/
      isWritten = true;
    }
};

/* Define callback when the server is disconnected*/
class customCallbackForServer: public BLEServerCallbacks {
    void onDisconnect(BLEServer* pServer) {
       delay(500); /* give the bluetooth stack the chance to get things ready */
       pServer->startAdvertising(); /* restart advertising */
    }
};

/* For non ESP devices */
#else
/* Create BLEService object */
BLEService SERVICENAME(SERVICEUUID);

/* Create BLECharacteristic objects */
/* Write characteristic - Central device can only write to this characteristic */
BLECharacteristic WRITECHARACTERISTICNAME(WRITECHARACTERISTICUUID, BLEWrite, MAX_PACKET_SIZE, false);
/* Read characteristic - Central device can read from this characteristic and peripheral will notify the central */
/* if the characteristic is modified */
BLECharacteristic READCHARACTERISTICNAME(READCHARACTERISTICUUID, BLERead | BLENotify, MAX_PACKET_SIZE, false);

/* Create BLE Central object */
BLEDevice central;
#endif

/* helper functions for gettign ble name and libraries */
 String getLocalName()
 {
     uint8_t bleRequestBytes[blenamecmdNumBytes];
     Serial.readBytes((char*)bleRequestBytes, blenamecmdNumBytes);
     char request[blenamecmdNumBytes+1];
     memcpy(request, bleRequestBytes, sizeof(bleRequestBytes));
     request[sizeof(bleRequestBytes)] = '\0';
     if(String(request)==blenamecmd)
     {
         String name = BLEADVERTISINGNAME;
         return name;
     }
     return "";
 }

String getLibraryList()
{
    uint8_t bleRequestBytes[blelibrariescmdNumBytes];
    Serial.readBytes((char*)bleRequestBytes, blelibrariescmdNumBytes);
    char request[blelibrariescmdNumBytes+1];
    memcpy(request, bleRequestBytes, sizeof(bleRequestBytes));
    request[sizeof(bleRequestBytes)] = '\0';
    if(String(request)==blelibrariescmd)
    {
        String libList = LIBNAMES;
        return libList;
    }
    return "";
}

/* Function: rtIOStreamOpen =================================================
 * Abstract:
 *  Add the custom service and characterstics and start advertising.
 *  Wait till a BLE central device connects.
 */
int rtIOStreamOpen(int argc, void * argv[])
{
  Serial.begin(9600);
  delay(3000);// Use delay to wait for serial to begin. Dont use while (!Serial); this will not work when arduino is connected to Power adapter

  int result = RTIOSTREAM_NO_ERROR;

#ifdef ESP_BLE
  /* Initialise BLE Device*/
  BLEDevice::init(BLEADVERTISINGNAME);

  /* Create BLE Server*/
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new customCallbackForServer());

  /* Create Service and add write and read characteristics*/
  pService = pServer->createService(SERVICEUUID);
  pService->addCharacteristic(&WRITECHARACTERISTIC);
  WRITECHARACTERISTIC.setCallbacks(new customCallBackForWrite());
  pService->addCharacteristic(&READCHARACTERISTIC);
  READCHARACTERISTIC.addDescriptor(p2902);

  /* Start service and advertise */
  pService->start();
  pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICEUUID);
  pServer->startAdvertising();

#else
  while (!BLE.begin());

  BLE.setLocalName(BLEADVERTISINGNAME);
  BLE.setAdvertisedService(SERVICENAME);

  /* add the characteristic to the service */
  SERVICENAME.addCharacteristic(WRITECHARACTERISTICNAME);
  SERVICENAME.addCharacteristic(READCHARACTERISTICNAME);

  /* add service */
  BLE.addService(SERVICENAME);

  /* start advertising */
  BLE.advertise();
#endif

  /* wait till a central device connects */
  while (1)
  {
#ifdef ESP_BLE
    /* getConnectedCount indicates the number of connected devices. Since we are not using multi connect getConnectedCount should indicate the connection with the peripheral */
    if (pServer->getConnectedCount() == 1)
    {
      break;
    }
#else
    central = BLE.central();
    if (central.connected())
    {
      break;
    }
#endif

    else if (Serial && Serial.available() > 0)
    {
      delay(1000); // wait till to read the data

      /* Only required for HWSetup workflow to connect to the Serial read the address over serial */
      if (Serial.available() == blecmdNumBytes)
      {
        uint8_t bleRequestBytes[blecmdNumBytes];
        Serial.readBytes((char*)bleRequestBytes, blecmdNumBytes);
        char request[blecmdNumBytes + 1];
        memcpy(request, bleRequestBytes, sizeof(bleRequestBytes));
        request[sizeof(bleRequestBytes)] = '\0';
        if (String(request) == blecmd)
        {
#ifdef ESP_BLE
          BLEAddress addressBLE = BLEDevice::getAddress().toString();
          String address = addressBLE.toString().c_str();
#else
          String address = BLE.address();
#endif
          Serial.print(address);
        }
      }
      else if (Serial.available() == blenamecmdNumBytes)
      {
        String name = getLocalName();
        Serial.print(name);
      }
      else if (Serial.available() == blelibrariescmdNumBytes)
      {
        String libList = getLibraryList();
        Serial.print(libList);
      }
    }
  }


  return result;
}

/* Function: rtIOStreamSend =====================================================
 * Abstract:
 *  Write the specified number of bytes to the characteristic
 */
int rtIOStreamSend(
  int          streamID,
  const void * src,
  size_t       size,
  size_t     * sizeSent)
{
  *sizeSent = 0;

  /* Check whether central device is connected */
#ifdef ESP_BLE
  if (pServer->getConnectedCount() == 1)
  {
    READCHARACTERISTIC.setValue((uint8_t*)src, (int16_t) size);
    READCHARACTERISTIC.notify();
    *sizeSent = size;
  }
#else
  if (central.connected())
  {
    READCHARACTERISTICNAME.writeValue((uint8_t*)src, size);
    *sizeSent = size;
  }

#endif

  else {
    return RTIOSTREAM_ERROR;
  }
  return RTIOSTREAM_NO_ERROR;
}

/* Function: rtIOStreamRecv ================================================
 * Abstract:
 *  Read data from the characteristic if it's value has been modified by the central
 */
int rtIOStreamRecv(
  int      streamID,
  void   * dst,
  size_t   size,
  size_t * sizeRecvd)
{
  *sizeRecvd = 0U;

  /* Check whether central device is connected */
#ifdef ESP_BLE
  if (pServer->getConnectedCount() == 1)
  {
    if (isWritten)
    {
      std::string value = WRITECHARACTERISTIC.getValue();
      *sizeRecvd = (size_t)value.length();
      /* Get the pointer to the received data */
      const uint8_t *receivedBuffer = reinterpret_cast<const uint8_t*>(value.c_str());

      /* Copy the characteristic data into the dst buffer */
      memcpy(dst, receivedBuffer, *sizeRecvd);
      isWritten = false;
    }
  }
#else
  if (central.connected())
  {

    if (WRITECHARACTERISTICNAME.written()) {
      /* Get the size of the data written to characteristic */
      *sizeRecvd = (size_t)WRITECHARACTERISTICNAME.valueLength();
      /* Get the pointer to the received data */
      const uint8_t *receivedBuffer = WRITECHARACTERISTICNAME.value();
        
      /* Copy the characteristic data into the dst buffer */
      memcpy(dst, receivedBuffer, *sizeRecvd);
    }
  }
#endif


  else {
    if (Serial && Serial.available() == blenamecmdNumBytes)
    {
      /* Return the BLE device local name if client asked for it when not connected over BLE, used in Hwsetup screen when device is already configured*/
      String name = getLocalName();
      Serial.print(name);

    }
    else if (Serial && Serial.available() == blelibrariescmdNumBytes)
    {
      /* Return the BLE library list if client asked for it when not connected over BLE, used in Hwsetup screen when device is already configured */
      String libList = getLibraryList();
      Serial.print(libList);
    }
    return RTIOSTREAM_ERROR;
  }

  return RTIOSTREAM_NO_ERROR;
}

/* Function: rtIOStreamClose ================================================
 * Abstract:
 *  Close the connection with central device
 */
int rtIOStreamClose(int streamID)
{
#ifdef ESP_BLE
  delay(500); // give the bluetooth stack the chance to get things ready
  pServer->startAdvertising(); // restart advertising
  delete[] p2902;
#else
  BLE.end();
#endif
  if (Serial)
    Serial.end();
  return RTIOSTREAM_NO_ERROR;
}