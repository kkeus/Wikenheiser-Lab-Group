/**
 * @file customFunction.cpp
 *
 * Switch yard for custom peripherals
 *
 * @Copyright 2017-2018 The MathWorks, Inc.
 *
 */

#ifdef __cplusplus
    extern "C" {
#endif

#include "servoArduino.h"
#include "playToneArduino.h"
#include "rotaryEncoderArduino.h"
#include "ultrasonicArduino.h"
#include "shiftRegisterArduino.h"
#include "customFunction.h"
#include "neopixelArduino.h"

/* Init Custom peripherals */
void customFunctionHookInit()
{
}

/* Hook to add the custom peripherals */
void customFunctionHook(uint16_T requestID,uint8_T* payloadBufferRx, uint8_T* payloadBufferTx,uint16_T* peripheralDataSizeResponse)
{
	switch(requestID)
	{
        #if IO_CUSTOM_SERVO
            case ATTACH_SERVO:
                attachServo(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;

            case CLEAR_SERVO:
                detachServo(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
            
            case READ_POSITION:
                readPosition(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
            
            case WRITE_POSITION:
                writePosition(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
        #endif
        
        // Tone START
        case PLAYTONE:
            playTone(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
        break;
        // Tone END
		
        #if IO_CUSTOM_ROTARYENCODER
            case ATTACH_ENCODER:
                attachEncoder(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
            
            case DETACH_ENCODER:
                detachEncoder(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
            
            case READ_ENCODER_COUNT:
                readEncoderCount(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;

            case READ_ENCODER_SPEED:
                readEncoderSpeed(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;

            case WRITE_ENCODER_COUNT:
                writeEncoderCount(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
        #endif
        
        #if IO_CUSTOM_ULTRASONIC
            case ULTRASONIC_ATTACH:
                attachUltrasonicSensor(payloadBufferRx, payloadBufferTx, peripheralDataSizeResponse);
            break;
            
            case ULTRASONIC_DETACH:
                detachUltrasonicSensor(payloadBufferRx, payloadBufferTx, peripheralDataSizeResponse);
            break;
            
            case ULTRASONIC_READ:
                readTravelTime(payloadBufferRx, payloadBufferTx, peripheralDataSizeResponse);
            break;
        #endif
        
        #if IO_CUSTOM_SHIFTREGISTER
            case SHIFT_REGISTER_WRITE:
                writeShiftRegister(payloadBufferRx, payloadBufferTx, peripheralDataSizeResponse);
            break;
            
            case SHIFT_REGISTER_READ:
                readShiftRegister(payloadBufferRx, payloadBufferTx, peripheralDataSizeResponse);
            break;
            
            case SHIFT_REGISTER_RESET:
                resetShiftRegister(payloadBufferRx, payloadBufferTx, peripheralDataSizeResponse);
            break;
        #endif
        
        #if IO_CUSTOM_NEOPIXEL
            case ATTACH_NEOPIXEL:
                attachNeopixel(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;

            case DETACH_NEOPIXEL:
                detachNeopixel(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
            
            case WRITE_NEOPIXEL:
                writeNeopixel(payloadBufferRx,payloadBufferTx,peripheralDataSizeResponse);
            break;
         #endif
        
		default:
		
		break;
	}
}

#ifdef __cplusplus
    }
#endif
