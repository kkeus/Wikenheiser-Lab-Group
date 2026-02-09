/**
 * @file ultrasonicArduino.h
 *
 * Provides headers to ultrasonicArduino.cpp
 *
 * @Copyright 2018 The MathWorks, Inc.
 *
 */

#ifndef ULTRASONICARDUINO_H
#define ULTRASONICARDUINO_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"


extern "C"{

/* Attach an Ultrasonic Sensor to Arduino */
void attachUltrasonicSensor(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Detach Ultrasonic Sensor */
void detachUltrasonicSensor(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Read the Distance of object from Ultrasonic Sensor */
void readTravelTime(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
}
#endif
