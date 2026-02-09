/*
 * File: rtiostream_serial.cpp
 * Copyright 2011-2024 The MathWorks, Inc.
 */

#include "Arduino.h"
#if defined(EXT_MODE)
#include "MW_target_hardware_resources.h"
#include <SPI.h>
#include <inttypes.h>
#if defined(_ROTH_MKR1000_) || defined(ARDUINO_WIFI_LIB_101)
#include <WiFi101.h>
#elif defined(_ROTH_MKRWIFI1010_) || defined(_ROTH_NANO33_IOT_) || defined(ARDUINO_WIFI_LIB_NINA)
#include <WiFiNINA.h>
#else
#include <WiFi.h>
#endif
#else
#include "rtwtypes.h"
#include <SPI.h>
#include "MacroIncludeIO.h"
#if defined(ARDUINO_SAMD_MKR1000) || defined(ARDUINO_WIFI_LIB_101)
#include <WiFi101.h>
#elif defined(ARDUINO_SAMD_MKRWIFI1010) || defined(ARDUINO_SAMD_NANO_33_IOT) || defined(ARDUINO_WIFI_LIB_NINA)
#include <WiFiNINA.h>
#elif defined(ARDUINO_ARCH_RENESAS_UNO)
#include <WiFiS3.h>
#elif defined(ESP_H) // For ESP32
#include <WiFi.h>
#endif
#endif

/* Uncomment to use clearInt() or enableInt() for interrupts
#if defined (_ROTH_DUE_) || defined (_ROTH_MKR1000_)
#define clearInt() DISABLE_SCHEDULER_INT()
#define enableInt() ENABLE_SCHEDULER_INT()
#if defined (_ROTH_DUE_)
#include "arduinoARMScheduler.h"
#else
#include "arduinoARM_M0plusScheduler.h"
#endif
#else
#define clearInt() cli()
#define enableInt() sei()
#include "arduinoAVRScheduler.h"
#endif
*/

#ifndef _rtiostream

// #define that helps to stringify build flags
// Double evaluation is needed so that the double quotes can be derived out
// of the build flag and can be assigned to a character array
#define RTT_StringifyBuildFlag(x) RTT_StringParamExpanded(x)
#define RTT_StringParamExpanded(x) #x

extern "C" {
#include "rtiostream.h"
}
#define _rtiostream
#endif

extern "C" void __cxa_pure_virtual(void);

/* The variable below has no use in this file. Used to preserve
 * compatibility with rtiostream_interface
 */
volatile boolean receivedSyncByteE = false;
#if defined(EXT_MODE)
WiFiServer extmode_wifi_server(17725);
#else
WiFiServer extmode_wifi_server(MW_PORT);
const String ipcmd = "whatisyourip";
const uint8_t ipcmdNumBytes = ipcmd.length();
#endif
WiFiClient extmode_wifi_client;

int extmodewifistatus = WL_IDLE_STATUS; // the Wifi radio's extmodewifistatus

IPAddress ip;

/* Function: rtIOStreamOpen ========================================================================
 * Abstract:
 *  Open the connection with the target.
 */
int rtIOStreamOpen(int argc, void* argv[]) {
    int result = RTIOSTREAM_NO_ERROR;
    char ssid[] = RTT_StringifyBuildFlag(_RTT_WIFI_SSID);
#if _RTT_DISABLE_Wifi_DHCP_ != 0
    IPAddress wifiLocalIpAddress(_RTT_WIFI_Local_IP1, _RTT_WIFI_Local_IP2, _RTT_WIFI_Local_IP3,
                                 _RTT_WIFI_Local_IP4);
#endif

#ifdef _RTT_WIFI_WEP
    char key[] = RTT_StringifyBuildFlag(_RTT_WIFI_KEY);
    int keyIndex = _RTT_WIFI_KEY_INDEX;
#endif

#ifdef _RTT_WIFI_WPA
    char wpapass[] = RTT_StringifyBuildFlag(_RTT_WIFI_WPA_PASSWORD);
#endif

#if _RTT_DISABLE_Wifi_DHCP_ != 0
#if defined(ESP_H)
    // ESP32 WiFi Library mandates users to provide the Gateway, Subnet mask and DNS IP address for
    // Static IP workflows. To get the required info, configure the hardware to auto IP addresss
    // mode, then get the configuration details and reconnect with the Static IP address given by
    // the user

#ifdef _RTT_WIFI_WPA
    extmodewifistatus = WiFi.begin(ssid, wpapass);
#endif
#ifdef _RTT_WIFI_NONE
    extmodewifistatus = WiFi.begin(ssid);
#endif

    // Wait until connection is established
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
    }

    // Get the network configurations
    IPAddress localGateWayIP = WiFi.gatewayIP();
    IPAddress localSubnetMask = WiFi.subnetMask();
    IPAddress localDNSIP0 = WiFi.dnsIP(0);
    IPAddress localDNSIP1 = WiFi.dnsIP(1);

    // inp1 indicates if the WiFi Radio to be turned off
    // inp2 indicates if you want to erase the AP configuration
    WiFi.disconnect(false, false);

    // Disconnect from WiFi
    while (WiFi.status() != WL_DISCONNECTED)
        ;
    delay(1000);

    // Configure WiFi with above network settings
    WiFi.config(wifiLocalIpAddress, localGateWayIP, localSubnetMask, localDNSIP0, localDNSIP1);

#else
    WiFi.config(wifiLocalIpAddress);
#endif
#endif

    Serial.begin(_RTT_BAUDRATE_SERIAL0_);
    delay(3000);// Use delay to wait for serial to begin. Dont use while (!Serial); this will not work when arduino is connected to Power adapter

#ifdef _RTT_WIFI_WEP
    extmodewifistatus = WiFi.begin(ssid, keyIndex, key);
#endif

#ifdef _RTT_WIFI_WPA
    extmodewifistatus = WiFi.begin(ssid, wpapass);
#endif

#ifdef _RTT_WIFI_NONE
    extmodewifistatus = WiFi.begin(ssid);
#endif

    while (extmodewifistatus != WL_CONNECTED) {
        extmodewifistatus = WiFi.status();
        delay(500);
    }
    extmode_wifi_server.begin();
    if (extmodewifistatus == WL_CONNECTED) {
        // If the Configuration is successful, relay back the assigned IP address.
        ip = WiFi.localIP();
#if defined(EXT_MODE)
        Serial.print("<<<IP address: ");
        Serial.print(ip);
        Serial.println(">>>");
#endif
    } else {
#if defined(EXT_MODE)
        // If the Configuration failed,relay back the error message.
        Serial.println("<<< IP address :Failed to configure. >>>");
#endif
    }
    return result;
}

/* Function: rtIOStreamSend ========================================================================
 * Abstract:
 *  Sends the specified number of bytes on the serial line. Returns the number of
 *  bytes sent (if successful) or a negative value if an error occurred.
 */
int rtIOStreamSend(int streamID, const void* src, size_t size, size_t* sizeSent) {
#if defined(ARDUINO_SAMD_MKR1000) || defined(ARDUINO_SAMD_MKRWIFI1010) || \
    defined(ARDUINO_SAMD_NANO_33_IOT) || defined(ESP_H)
    /*Check for available clients only when not connected*/
    if (!extmode_wifi_client.connected()) {
        extmode_wifi_client = extmode_wifi_server.available();
    }

    if (!extmode_wifi_client) {
        return RTIOSTREAM_ERROR;
    }
    extmode_wifi_client.write((const uint8_t*)src, (int16_t)size);
    *sizeSent = size;
#else
    /*Writing byte by byte else WiFi Shield gives ExtPktPending() error
     * in external mode for 2nd EXT_CONNECT_RESPONSE (g1626221)
     */
    *sizeSent = 0U;
    uint8_t data;
    while (((*sizeSent) < size)) {
        data = *((uint8_t*)src + *sizeSent);
        extmode_wifi_server.write(data);
        (*sizeSent)++;
    }
#endif
    return RTIOSTREAM_NO_ERROR;
}

/* Function: rtIOStreamRecv ========================================================================
 * Abstract: receive data
 *
 */
int rtIOStreamRecv(int streamID, void* dst, size_t size, size_t* sizeRecvd) {
    int data;
    uint8_t* ptr = (uint8_t*)dst;

    *sizeRecvd = 0U;
    /*Check for available clients only when not connected*/
    if (!extmode_wifi_client.connected()) {
#if !defined(EXT_MODE)
        if (Serial.available() == ipcmdNumBytes) {
            uint8_t ipRequestBytes[ipcmdNumBytes];
            Serial.readBytes((char*)ipRequestBytes, ipcmdNumBytes);
            char request[ipcmdNumBytes + 1];
            memcpy(request, ipRequestBytes, sizeof(ipRequestBytes));
            request[sizeof(ipRequestBytes)] = '\0';
            if (String(request) == ipcmd) {
                {
                    Serial.print(WiFi.status());
                    Serial.write(';');
                    if (WiFi.status() == WL_CONNECTED) {
                        Serial.print(ip);
                        Serial.print(';');
                        Serial.print(MW_PORT);
                        Serial.print('#');
                    }
                }
            }
        }
#endif
        extmode_wifi_client = extmode_wifi_server.available();
    }

    if (!extmode_wifi_client) {
        return RTIOSTREAM_ERROR;
    }
    int availableBytes = extmode_wifi_client.available();
    while ((*sizeRecvd < size) && (availableBytes > 0)) {
        data = extmode_wifi_client.read();
        if (data != -1) {
            *ptr++ = (uint8_t)data;
            (*sizeRecvd)++;
        }
    }
    return RTIOSTREAM_NO_ERROR;
}

/* Function: rtIOStreamClose =======================================================================
 * Abstract: close the connection.
 * For Arduino Leonardo + its variants and MKR 1000, the Virtual COM port is handled
 * by the controller. In case the code running on the target exits main,
 * the COM port cannot be accessed until a hard reset is performed.
 * To over come this issue, a while loop is added to make sure that
 * upon getting a stop command from external mode, the code running on
 * the target stops but the code will not exit the main.
 * This will ensure that the COM port is accessible even after the
 * external mode has been stopped.
 *
 */
int rtIOStreamClose(int streamID) {
#if defined(ARDUINO_AVR_LEONARDO) || defined(ARDUINO_SAMD_MKR1000) ||         \
    defined(ARDUINO_SAMD_MKRWIFI1010) || defined(ARDUINO_SAMD_NANO_33_IOT) || \
    defined(ARDUINO_VIRTUAL_COM_PORT)
    while (1) {
        // wait to process any USB requests.
    }
#endif
    return RTIOSTREAM_NO_ERROR;
}
