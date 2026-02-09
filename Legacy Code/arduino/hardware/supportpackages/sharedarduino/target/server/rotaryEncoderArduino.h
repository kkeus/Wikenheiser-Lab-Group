/**
 * @file rotaryEncoderArduino.h
 *
 * Provides headers to rotaryEncoderArduino.cpp
 *
 * @Copyright 2018 The MathWorks, Inc.
 *
 */

#ifndef ROTARYENCODERARDUINO_H
#define ROTARYENCODERARDUINO_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"

extern "C"{

/* Attach the Quadrature Rotary Encoder to Arduino */
void attachEncoder(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Detach the Encoder */
void detachEncoder(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Read the Encoder Speed. */
void readEncoderSpeed(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Read the Encoder count. */
void readEncoderCount(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Set the encoder count. */
void writeEncoderCount(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
}

#endif //ROTARYENCODERARDUINO_H