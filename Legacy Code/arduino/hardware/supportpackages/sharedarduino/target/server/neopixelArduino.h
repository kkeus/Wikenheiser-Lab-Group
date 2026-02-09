/**
 * file neopixelArduino.h
 *
 * Provides headers to neopixelArduino.cpp
 *
 * Copyright 2023 The MathWorks, Inc.
 *
 */

#ifndef NEOPIXELARDUINO_H
#define NEOPIXELARDUINO_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"


extern "C"{

/* Attach an Ultrasonic Sensor to Arduino */
void attachNeopixel(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Detach Ultrasonic Sensor */
void detachNeopixel(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Read the Distance of object from Ultrasonic Sensor */
void writeNeopixel(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
}
#endif
