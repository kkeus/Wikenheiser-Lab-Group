/**
 * @file customFunction.h
 *
 * Defines request IDs for custom peripherals.
 *
 * @Copyright 2017-2018 The MathWorks, Inc.
 *
 */
#ifndef CUSTOMFUNCTION_H
#define CUSTOMFUNCTION_H

#include "IO_include.h"
#include "IO_peripheralInclude.h"
typedef enum customFunctionRequestID
{
    /*===========================================
     * Custom Function Request ID
     * Request ID should be between 0xF100 - 0xFFFF
     *==========================================*/
    #if IO_CUSTOM_SERVO
    ATTACH_SERVO    = 0xF100,
    CLEAR_SERVO     = 0xF101,
    READ_POSITION   = 0xF102,
    WRITE_POSITION  = 0xF103,
    #endif
    // Tone
    PLAYTONE        = 0xF110,
    
    #if IO_CUSTOM_ROTARYENCODER
    ATTACH_ENCODER  = 0xF120,
    DETACH_ENCODER  = 0xF121,
    CHANGE_DELAY    = 0xF122,
    READ_ENCODER_COUNT  = 0xF123,
    READ_ENCODER_SPEED  = 0xF124,
    WRITE_ENCODER_COUNT = 0xF125,
    #endif
    
    #if IO_CUSTOM_ULTRASONIC
    ULTRASONIC_ATTACH = 0xF130,
    ULTRASONIC_DETACH = 0xF131,
    ULTRASONIC_READ   = 0xF132,
    #endif
    
    #if IO_CUSTOM_SHIFTREGISTER
    SHIFT_REGISTER_WRITE    = 0xF140,
    SHIFT_REGISTER_READ     = 0xF141,
    SHIFT_REGISTER_RESET    = 0xF142,
    #endif

    #if IO_CUSTOM_NEOPIXEL
    ATTACH_NEOPIXEL          = 0XF150,
    DETACH_NEOPIXEL          = 0XF151,
    WRITE_NEOPIXEL            = 0XF152,
    #endif
    
}requestIDs;

void customFunctionHookInit();
void customFunctionHook(uint16_T cmdID,uint8_T* payloadBufferRx, uint8_T* payloadBufferTx,uint16_T* peripheralDataSizeResponse);

#endif
