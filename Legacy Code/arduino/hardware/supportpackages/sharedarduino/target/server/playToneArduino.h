/**
 * @file playToneArduino.h
 *
 * Helper for playToneArduino.cpp
 *
 * @Copyright 2018 The MathWorks, Inc.
 *
 */
 
#ifndef PLAYTONEARDUINO_H
#define PLAYTONEARDUINO_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"

/* Wrap playTone interface */
void playTone(uint8_T* payloadBufferRx, uint8_T* payloadBufferTx, uint16_T* peripheralDataSizeResponse);

#endif
