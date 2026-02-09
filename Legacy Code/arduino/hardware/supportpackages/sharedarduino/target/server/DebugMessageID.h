/**
 * @file DebugMessageID.h
 *
 * Contains  Debug Message IDs for standard peripherals
 *
 * @Copyright 2019-2022 The MathWorks, Inc.
 *
 */

#ifndef IO_DEBUGMSGID_H_
#define IO_DEBUGMSGID_H_

typedef enum DebugMessageIDTag
{
    /*=============================
     *Standard Debug Message ID
     *=============================*/
    
    /* Digital IO Debugmessages */
    DEBUGOPENDIGITALPIN             = 00,
    DEBUGWRITEDIGITALPIN            = 01,
    DEBUGREADDIGITALPIN             = 02,
    DEBUGUNCONFIGUREDIGITALPIN      = 04,
    
    /* Analog IO Debugmessages */
    
    DEBUGREADRESULTANALOGINSINGLE   = 06,
    
    
    /* I2C Debugmessages */
    
    DEBUGI2CWRITEARM3DATA           = 10,
    DEBUGI2CWRITEARM2DATA           = 11,
    DEBUGI2CWRITEARM1DATA           = 12,
    DEBUGI2CWRITEAVR3DATA           = 13,
    DEBUGI2CWRITEAVR2DATA           = 14,
    DEBUGI2CWRITEAVR1DATA           = 15,
    DEBUGI2CENDTRANSMISSIONARM      = 16,
    DEBUGI2CWRITEARM                = 17,
    DEBUGI2CBEGINTRANSMISSIONARM    = 18,
    DEBUGI2CENDTRANSMISSIONAVR      = 19,
    DEBUGI2CBEGINAVR                = 20,
    DEBUGI2CBEGINARM                = 21,
    DEBUGI2CSETCLOCKAVR             = 22,
    DEBUGI2CSETCLOCKARM             = 23,
    DEBUGI2CREQUESTFROMAVR          = 24,
    DEBUGI2CREQUESTFROMARM          = 25,
    DEBUGI2CREADFROMAVR             = 26,
    DEBUGI2CREADFROMARM             = 27,
    DEBUGI2CBEGINTRANSMISSIONAVR    = 28,
    DEBUGI2CWRITEAVR                = 29,
    
    
    
    /* SPI Debugmessages */
    
    DEBUGSPIBEGINARM                = 30,
    DEBUGSPIBEGINAVR                = 31,
    DEBUGSPIENDTRANSACTION          = 32,
    DEBUGSPIENDARM                  = 33,
    DEBUGSPIENDAVR                  = 34,
    DEBUGSPIBEGINTRANSACTION        = 35,
    DEBUGSPITRANSFERARM             = 36,
    DEBUGSPITRANSFERAVR             = 37,
    
    
    /* PWM Debugmessages*/
    
    DEBUGPWMSETDUTYCYCLE            = 40,
    DEBUGPWMOPEN                    = 41,
    DEBUGPWMSETDUTYCYCLEESP32       = 42,
    /* Servo Debugmessages*/
    DEBUGSERVODETACH               = 50,
    DEBUGSERVOREAD                 = 51,
    DEBUGSERVOWRITE                = 52,
    DEBUGSERVOATTACH_AVR           = 53,
    DEBUGSERVOATTACH_ARM           = 54,
    DEBUGSERVOATTACH_ESP32         = 55,
    
    //Ultrasonice
    DEBUGDELAYMICROSECONDS         =60,
    DEBUGDELETEULTRASONIC          =61,
    DEBUGCREATEULTRASONIC          =62,
    DEBUGPULSEIN                   =63,
    
    //playtone
    DEBUGPLAYTONE                 = 65,
    
    //shiftregister
    DEBUGWRITEDIGITALPIN_LOADPIN_CEPIN =70,
    DEBUGSHIFTREGISTERWRITE        = 71,
    DEBUGSHIFTOUT                  = 72,
    DEBUGSHIFTIN                   = 73,
    
    //rotaryencoder
    DEBUGATTACHENCODER           = 81,
    DEBUGDETACHENCODER           = 82,
    DEBUGREADSPEEDENCODER       =  83,
    DEBUGREADCOUNTENCODER       =  85,
    DEBUGWRITWCOUNTENCODER      =  86,
    
    //SCI debug messages
    DEBUGSCIBEGIN                = 90,
    DEBUGSCISETTIMEOUT           = 91,
    DEBUGSCIWRITE1BYTE           = 92,
    DEBUGSCIWRITE2BYTE           = 93,
    DEBUGSCIWRITE3BYTE           = 94,
    DEBUGSCIREAD1BYTE            = 95,
    DEBUGSCIREAD2BYTE            = 96,
    DEBUGSCIREAD3BYTE            = 97,
    DEBUGSCIAVAILABLE            = 98,
    DEBUGSCIEND                  = 99,

    DEBUGDELETENEOPIXEL         =100,
    DEBUGNEOPIXELWRITE          =101,
    
    
} debugMessageIDValues;
#endif /* IO_DEBUGMSGID_H_ */