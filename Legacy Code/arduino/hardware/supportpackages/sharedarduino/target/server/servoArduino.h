/**
 * @file servoArduino.h
 *
 * Provides headers to Servo.
 *
 * @copyright Copyright 2018 The MathWorks, Inc.
 *
 */
 
#ifndef servoArduino_H
#define servoArduino_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"

#ifdef __cplusplus
extern "C" {
#endif
/* Attach the Servo motor */
void attachServo(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Detach the Servo Motor */
void detachServo(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Read the position of servo motor shaft. */
void readPosition(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Set the position of servo motor shaft. */
void writePosition(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);

#ifdef __cplusplus
}
#endif

#endif