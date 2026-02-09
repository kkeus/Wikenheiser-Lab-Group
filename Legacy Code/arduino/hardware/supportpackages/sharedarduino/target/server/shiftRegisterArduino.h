/**
 * @file shiftRegisterArduino.h
 *
 * Provides headers to shiftRegisterArduino.cpp
 *
 * @Copyright 2018 The MathWorks, Inc.
 *
 */

#ifndef SHIFTREGISTERARDUINO_H
#define SHIFTREGISTERARDUINO_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"

extern "C"{

/* Write to Shift Register (Arduino to SIPO) */
void writeShiftRegister(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Read from Shift Register (PISO to Arduino) */
void readShiftRegister(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
/* Reset the Shift Register */
void resetShiftRegister(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);
}

#endif //SHIFTREGISTERARDUINO_H