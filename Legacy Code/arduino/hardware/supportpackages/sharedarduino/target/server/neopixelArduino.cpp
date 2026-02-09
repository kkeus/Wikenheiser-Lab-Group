/**
* @file neopixelArduino.cpp
*
* Provides Access to Neopixel.
*
* Copyright 2024 The MathWorks, Inc.
*
*/
#include "peripheralIncludes.h"
#if IO_CUSTOM_NEOPIXEL
#ifndef _Arduino_h_
#define _Arduino_h_
#include "Arduino.h"
#endif

#include "neopixelArduino.h"

#include "Adafruit_NeoPixel.h"

#define MAX_NEOPIXEL 10


extern "C" {
    Adafruit_NeoPixel pixels[MAX_NEOPIXEL];
    // Attach a Neopixel to Arduino
    void attachNeopixel(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {

        uint16_T numPixels;
        uint8_T pin;
        uint16_T pixelType;
        uint8_T ID;
        uint16_T index = 0;
        #if DEBUG_FLAG == 2
        uint8_T num =0;
        #endif

        memcpy(&numPixels, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);

        memcpy(&pin, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);

        memcpy(&pixelType, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);

        memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);

        pixels[ID].setPin(pin);
        pixels[ID].updateLength(numPixels);
        pixels[ID].updateType(pixelType);
        //
        pixels[ID].begin();
        pixels[ID].show();

    }

    // Detach Neopixel
    void detachNeopixel(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T ID;
        uint16_T index = 0;
        #if DEBUG_FLAG == 2
        uint8_T num =0;
        #endif
        memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);

        #if DEBUG_FLAG == 2
        num=0;
        DebugMsg.debugMsgID = DEBUGDELETENEOPIXEL;
        DebugMsg.argNum = num;
        sendDebugPackets();
        #endif

        pixels[ID].clear(); // Set all pixel colors to 'off'
        pixels[ID].show(); // Update strip with new contents
    }

    //Write different sets of input to Neopixel
    void writeNeopixel(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse)
    {
        uint8_T ID;
        uint16_T  numPixels;
        uint8_T numLeds,brightness,length,*RGBColor,*ledNum;

        uint16_T index = 0;
        #if DEBUG_FLAG == 2
        uint8_T num = 0;
        #endif
        if(length==3){
            RGBColor=(uint8_T*)malloc(sizeof(uint8_T)*3);
        }
        else if(length==4){
            RGBColor=(uint8_T*)malloc(sizeof(uint8_T)*4);
        }
        else if (length % 3==0){
            RGBColor=(uint8_T*)malloc(sizeof(uint8_T)*3*numLeds);
        }

        else{
            RGBColor=(uint8_T*)malloc(sizeof(uint8_T)*4*numLeds);
        }


        ledNum=(uint8_T*)malloc(sizeof(uint8_T)*numLeds);


        memcpy(&ID, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);

        memcpy(&numPixels, &payloadBufferRx[index], sizeof(uint16_T));
        index += sizeof(uint16_T);

        memcpy(&numLeds, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);

        memcpy(&brightness, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);

        memcpy(&length, &payloadBufferRx[index], sizeof(uint8_T));
        index += sizeof(uint8_T);


        if(length==3){
            memcpy(RGBColor, &payloadBufferRx[index], sizeof(uint8_T)*3);
            index += sizeof(uint8_T)*3;
        }
        else if(length==4){
            memcpy(RGBColor, &payloadBufferRx[index], sizeof(uint8_T)*4);
            index += sizeof(uint8_T)*4;
        }

        else if(length%3==0){
            memcpy(RGBColor, &payloadBufferRx[index], sizeof(uint8_T)*3*numLeds);
            index += sizeof(uint8_T)*3*numLeds;
        }

        else{
            memcpy(RGBColor, &payloadBufferRx[index], sizeof(uint8_T)*4*numLeds);
            index += sizeof(uint8_T)*4*numLeds;
        }

        memcpy(ledNum, &payloadBufferRx[index], sizeof(uint8_T)*numLeds);
        index += sizeof(uint8_T)*numLeds;



        pixels[ID].clear();

        for(uint8_t i=0;i<numLeds;i++)
        {
            if(length==3)
            {
                pixels[ID].setPixelColor(ledNum[i],RGBColor[0],RGBColor[1],RGBColor[2]);
            }
            else if(length==4)
            {
                pixels[ID].setPixelColor(ledNum[i],RGBColor[0],RGBColor[1],RGBColor[2],RGBColor[3]);
            }
            else if(length % 3 ==0)
            {
                pixels[ID].setPixelColor(ledNum[i],RGBColor[0+3*i],RGBColor[1+3*i],RGBColor[2+3*i]);
            }
            else
            {
                pixels[ID].setPixelColor(ledNum[i],RGBColor[0+4*i],RGBColor[1+4*i],RGBColor[2+4*i],RGBColor[3+4*i]);
            }
        }

        pixels[ID].setBrightness(brightness);
        pixels[ID].show();   // Send the updated pixel colors to the hardware.
        free(RGBColor);
        free(ledNum);

    }


}

 #endif  //IO_CUSTOM_NEOPIXEL