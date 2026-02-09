/**
 * @file APDS9960.h
 *
 * Class definition for APDS9960 class
 *
 * @copyright Copyright 2021 The MathWorks, Inc.
 *
 */

#include <Arduino.h>
#include "LibraryBase.h"
#include <Wire.h>
#include <math.h>

/* Custom peripheral specific command IDs */
#define APDS9960_CREATE_APDS9960                       0x01
#define APDS9960_INIT_APDS9960                         0x02
#define APDS9960_READ_GESTURE                          0x03
#define APDS9960_DELETE_APDS9960                       0x04

/* Gesture read time out of 8 seconds */
#define GESTURE_TIMEOUT                                8000

/* APDS9960 Register Addresses
 *
 * APDS9960_ENABLE
 * Enable/Disable power to the internal circuitry,
 * proximity engine, color engine, gesture engine,
 * and wait time
 */
#define APDS9960_ENABLE                                0x80

/* APDS9960_ADC_INTEGRATION_TIME
 * Controls the internal integration time of the
 * color engine's analog to digital converters
 */
#define APDS9960_ADC_INTEGRATION_TIME                  0x81

/* APDS9960_WAIT_TIME
 * Controls the amount of time in a low power mode
 * between Proximity and/or Color cycles
 */
#define APDS9960_WAIT_TIME                             0x83

/* APDS9960_CONFIGURE_ONE
 * Sets the wait long time. When asserted, the wait
 * cycle is increased by a factor 12x from that
 * programmed in the APDS9960_WAIT_TIME register
 */
#define APDS9960_CONFIGURE_ONE                         0x8D

/* APDS9960_PROXIMITY_PULSECOUNT
 * Sets Pulse Width modified current during a
 * Proximity Pulse. The proximity pulse count register
 * bits set the number of pulses to be output on the
 * LED. The Proximity width register bits set the
 * amount of time the LED is sinking current during
 * a proximity pulse.
 */
#define APDS9960_PROXIMITY_PULSECOUNT                  0x8E

/* APDS9960_CONTROL_ONE
 * Sets the LED drive current under Proximity mode,
 * sets the Proximity and Color gains
 */
#define APDS9960_CONTROL_ONE                           0x8F

/* APDS9960_CONFIGURE_TWO
 * Allows the LED to sink more current above the
 * maximum setting by LED drive current
 */
#define APDS9960_CONFIGURE_TWO                         0x90

/* APDS9960_GESTURE_PROXIMITY_ENTER_THRESHOLD
 * This register sets the Proximity threshold value
 * used to determine a “gesture start” and subsequent
 * entry into the gesture state machine
 */
#define APDS9960_GESTURE_PROXIMITY_ENTER_THRESHOLD     0xA0

/* APDS9960_GESTURE_EXIT_THRESHOLD
 * This register sets the threshold value used to
 * determine a “gesture end” and subsequent exit
 * of the gesture state machine
 */
#define APDS9960_GESTURE_EXIT_THRESHOLD                0xA1

/* APDS9960_GESTURE_CONFIGURE_ONE
 * Configure the number of gesture datasets
 * to be read from FIFO
 */
#define APDS9960_GESTURE_CONFIGURE_ONE                 0xA2

/* APDS9960_GESTURE_CONFIGURE_TWO
 * Settings that govern gesture wait time, LED drive
 * current strength and Gesture gain control
 */
#define APDS9960_GESTURE_CONFIGURE_TWO                 0xA3

/* APDS9960_GESTURE_PULSE_SETTING
 * Settings that govern gesture pulse count
 * and pulse width
 */
#define APDS9960_GESTURE_PULSE_SETTING                 0xA6

/* APDS9960_GESTURE_CONFIGURE_THREE
 * Gesture Dimension Select.
 * Selects which gesture photodiode pairs
 * are enabled to gather results during gesture
 */
#define APDS9960_GESTURE_CONFIGURE_THREE               0xAA

/* APDS9960_GESTURE_STATUS
 * Indicates the operational condition of
 * the gesture state machine. Contains a bit to
 * check if gesture data is ready to be read
 * back from FIFO
 */
#define APDS9960_GESTURE_STATUS                        0xAF

/* APDS9960_GESTURE_DATA
 * Geture FIFO data register
 */
#define APDS9960_GESTURE_DATA                          0xFC

/*
 * Default values
 */

/* DEFAULT_ADC_INTEGRATION_TIME
 * Default value of ADC integration time
 * ADC Integration Time is calculated as
 * 256 - TIME(ms)/2.78(ms)
 * Setting default value to 200 ms
 * readColor API should be called in intervals
 * of 200 ms to fetch the current values of color
 * perceived by the sensor. With this setting the
 * maximum value fetched by the sensor is 65535
 */
#define DEFAULT_ADC_INTEGRATION_TIME                   0xB6

/* DEFAULT_WAIT_TIME
 * Default value of wait time in a low power mode
 * between Proximity and/or Color cycles.
 * Setting default value to 2.78 ms
 */
#define DEFAULT_WAIT_TIME                              0xFF

/* DEFAULT_PROXIMITY_PULSE_SETTING
 * Default value of the Proximity pulse count and
 * pulse width register. Setting default pulse count
 * to 10 pulses and pulse width to 8 us
 */
#define DEFAULT_PROXIMITY_PULSE_SETTING                0x49

/* DEFAULT_CONFIGURE_ONE
 * Default value of the Configuration Register One
 * Setting all the reserved bits to 1 and the wait
 * long bit to 0 to avoid the wait time to increase
 * 12 fold
 */
#define DEFAULT_CONFIGURE_ONE                          0x60

/* DEFAULT_CONFIGURE_TWO
 * No saturation interrupts or LED boost
 */
#define DEFAULT_CONFIGURE_TWO                          0x01

/* DEFAULT_CONFIGURE_THREE
 * Enable all photodiodes, no SAI
 */
#define DEFAULT_CONFIGURE_THREE                        0x00

/* DEFAULT_GESTURE_ENTER_THRESHOLD
 * Threshold for entering gesture mode
 * Set the default to 40
 */
#define DEFAULT_GESTURE_ENTER_THRESHOLD                0x28

/* DEFAULT_GESTURE_EXIT_THRESHOLD
 * Threshold for exiting gesture mode
 * Set the default to 30
 */
#define DEFAULT_GESTURE_EXIT_THRESHOLD                 0x1E

/* DEFAULT_GESTURE_CONFIGURE_ONE
 * Enable 8 gesture datasets to be
 * read from the FIFO
 */
#define DEFAULT_GESTURE_CONFIGURE_ONE                  0x80

/* DEFAULT_GESTURE_PULSE
 * Set the gesture pulse count to 10
 * and gesture pulse width to 8 us
 */
#define DEFAULT_GESTURE_PULSE                          0x49

/* DEFAULT_GESTURE_CONFIGURE_THREE
 * All photodiodes (up, down, left, and right)
 * active during gesture cycle
 */
#define DEFAULT_GESTURE_CONFIGURE_THREE                0x00

/* DEFAULT_CONTROL_ONE
 * Set Proximity Gain to 4x and
 * Color Gain to 1x
 */
#define DEFAULT_CONTROL_ONE                            0x08

/* DEFAULT_GESTURE_CONFIGURE_TWO
 * Set Gesture Gain to 4x,
 * Gesture LEDCurrent to 100 mA,
 * and Gesture wait time to 2.8 ms
 */
#define DEFAULT_GESTURE_CONFIGURE_TWO                  0x41

/* INITIALIZE_APDS9960_DEFAULTS
 * Initialize the sensor with default
 * register settings
 */
#define INITIALIZE_APDS9960_DEFAULTS                   0

/* POWER_ON_RESET_APDS9960_DEFAULTS
 * Bring back the sensor to the
 * power on reset settings
 */
#define POWER_ON_RESET_APDS9960_DEFAULTS               1

/* Debug message specific macros */
const char MSG_APDS9960_I2C_CREATE[]                  PROGMEM = "APDS9960::I2CBus%d;";
const char MSG_APDS9960_INIT[]                        PROGMEM = "APDS9960::INITSettings();";
const char MSG_APDS9960_READ_GESTURE[]                PROGMEM = "APDS9960::readGesture();";
const char MSG_APDS9960_DELETE[]                      PROGMEM = "APDS9960::delete();";
const char MSG_APDS9960_WRITE_VALUE[]                 PROGMEM = "APDS9960::Wire%s.write(%d); --> %d";
const char MSG_APDS9960_BEGIN_TRANSMISSION[]          PROGMEM = "APDS9960::Wire%s.beginTransmission(%d);";
const char MSG_APDS9960_END_TRANSMISSION[]            PROGMEM = "APDS9960::Wire%s.endTransmission(0); --> %d";
const char MSG_APDS9960_REQUEST_FROM[]                PROGMEM = "APDS9960::Wire%s.requestFrom(%d, %d, 1); --> %d";
const char MSG_APDS9960_READ_VALUE[]                  PROGMEM = "APDS9960::Wire%s.read(); --> %d";

uint8_t deviceAddress;
uint8_t i2cBusNum;
TwoWire* apds9960WireObj;

class  APDS9960: public LibraryBase
{
    public:
        APDS9960(MWArduinoClass& a)
        {
            /* Step 3 - Define 3P library name */
            libName = "APDS9960";
            /* Register library name and its pointer. */
            a.registerLibrary(this);
        }
    private:
      void initWire(uint8_t, uint8_t);
      void endWire(void);
      void readGestureData(uint8_t);
      uint8_t wireReadDataBytes(uint8_t, uint8_t*, unsigned int);
      bool configureSensor(uint8_t);
      bool wireWriteDataByte(uint8_t, uint8_t);
    public:
        void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
        {
            switch (cmdID)
            {
                case APDS9960_CREATE_APDS9960:
                {
                    /* I2C bus number is dataIn[0]
                     * I2C device address is dataIn[1]
                     */
                    initWire(dataIn[0], dataIn[1]);
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case APDS9960_INIT_APDS9960:
                {
                    uint8_t status;
                    /* Configure the sensor with default values */
                    status = (uint8_t)configureSensor(INITIALIZE_APDS9960_DEFAULTS);
                    sendResponseMsg(cmdID, &status, 1);
                    break;
                }
                case APDS9960_READ_GESTURE:
                {
                    /* Only Gesture is read with the custom peripheral
                     * Proximity and Color are read by using the I2C device
                     * workflow with readRegister and writeRegister methods
                     */
                    readGestureData(cmdID);
                    break;
                }
                case APDS9960_DELETE_APDS9960:
                {
                    /* Bring back the sensor to the power on default settings */
                    endWire();
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
            }
         }

};

/* APDS9960 private methods */
void APDS9960::initWire(uint8_t busNum, uint8_t i2cAddress)
{
    i2cBusNum = busNum;
    deviceAddress = i2cAddress;
    if(busNum == 0)
    {
        /* Wire object is defined for all supported boards */
        apds9960WireObj = &Wire;
    }
    else
    {
        /* Wire1 object is not defined for AVR and SAMD (MKR1000, MKR1010, MKRZero, Nano33IoT) */
        #if defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_MBED
            apds9960WireObj = &Wire1;
        #endif
    }
    debugPrint(MSG_APDS9960_I2C_CREATE, busNum);
}

void APDS9960::endWire()
{
    /* Bring back the sensor to the power on settings */
    configureSensor(POWER_ON_RESET_APDS9960_DEFAULTS);
}

bool APDS9960::configureSensor(uint8_t powerResetSettings)
{
    /* Print a debug to indicate the registers have been reset to power on settings
     * debugPrint(MSG_APDS9960_DELETE)
     *
     * Print a debug to indicate the registers are initialized
     * debugPrint(MSG_APDS9960_INIT)
     */
    (powerResetSettings == 0) ? debugPrint(MSG_APDS9960_INIT) : debugPrint(MSG_APDS9960_DELETE);

    if(powerResetSettings)
    {
        /*
         * Set ENABLE register to 0 (disable all features)
         * wireWriteDataByte(APDS9960_ENABLE, 0x00)
         *
         * Set power on reset default ADC integration time of 2.78 ms (Reg = 0x81)
         * wireWriteDataByte(APDS9960_ADC_INTEGRATION_TIME, 0xFF)
         *
         * Set power on reset default value of 0x40 (Reg = 0x8D)
         * wireWriteDataByte(APDS9960_CONFIGURE_ONE, 0x40)
         *
         * Set power on reset default proximity pulse count and pulse width of 1 pulses and 8 us (Reg = 0x8E)
         * wireWriteDataByte(APDS9960_PROXIMITY_PULSECOUNT, 0x40)
         *
         * Configuring power on reset default values of LEDCurrent, Proximity gain, ALS gain (Reg = 0x8F)
         * wireWriteDataByte(APDS9960_CONTROL_ONE, 0x00)
         *
         * Set power on reset default Gesture Proximity Entry Threshold value of 0 (Reg = 0xA0)
         * wireWriteDataByte(APDS9960_GESTURE_PROXIMITY_ENTER_THRESHOLD, 0x00)
         *
         * Set power on reset default Gesture Exit Threshold value of 0 (Reg = 0xA1)
         * wireWriteDataByte(APDS9960_GESTURE_EXIT_THRESHOLD, 0x00)
         *
         * Set power on reset default Gesture FIFO Threshold of 0 (Reg = 0xA2)
         * wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_ONE, 0x00)
         *
         * Set power on reset default values of Gesture LEDCurrent, Gain, and wait time (Reg = 0xA3)
         * wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_TWO, 0x00)
         *
         * Set power on reset default values of Gesture Pulse Count and Pulse Width (Reg = 0xA6)
         * wireWriteDataByte(APDS9960_GESTURE_PULSE_SETTING, 0x40)
         */
        if(!(wireWriteDataByte(APDS9960_ENABLE, 0x00) &&
             wireWriteDataByte(APDS9960_ADC_INTEGRATION_TIME, 0xFF) &&
             wireWriteDataByte(APDS9960_CONFIGURE_ONE, 0x40) &&
             wireWriteDataByte(APDS9960_PROXIMITY_PULSECOUNT, 0x40) &&
             wireWriteDataByte(APDS9960_CONTROL_ONE, 0x00) &&
             wireWriteDataByte(APDS9960_GESTURE_PROXIMITY_ENTER_THRESHOLD, 0x00) &&
             wireWriteDataByte(APDS9960_GESTURE_EXIT_THRESHOLD, 0x00) &&
             wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_ONE, 0x00) &&
             wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_TWO, 0x00) &&
             wireWriteDataByte(APDS9960_GESTURE_PULSE_SETTING, 0x40)))
           return false;
    }
        /*
         * Set ENABLE register to 8 (enable only wait time)
         * wireWriteDataByte(APDS9960_ENABLE, 0x08)
         *
         * Initialize the ADC integration time (Reg = 0x81) to DEFAULT_ADC_INTEGRATION_TIME i.e. 200 ms
         * wireWriteDataByte(APDS9960_ADC_INTEGRATION_TIME, DEFAULT_ADC_INTEGRATION_TIME)
         *
         * Disable WLONG (wait long) in Configuration Register One (Reg = 0x8D)
         * wireWriteDataByte(APDS9960_CONFIGURE_ONE, DEFAULT_CONFIGURE_ONE)
         *
         * Initialize proximity pulse count and pulse width (Reg = 0x8E) to 10 pulses and 8 us
         * wireWriteDataByte(APDS9960_PROXIMITY_PULSECOUNT, DEFAULT_PROXIMITY_PULSE_SETTING)
         *
         * Configuring default values of LEDCurrent, Proximity gain, ALS gain (Reg = 0x8F)
         * wireWriteDataByte(APDS9960_CONTROL_ONE, DEFAULT_CONTROL_ONE)
         *
         * Set default Gesture Proximity Entry Threshold value to 0x28 (Reg = 0xA0)
         * wireWriteDataByte(APDS9960_GESTURE_PROXIMITY_ENTER_THRESHOLD, DEFAULT_GESTURE_ENTER_THRESHOLD)
         *
         * Set default Gesture Exit Threshold value to 0x1E (Reg = 0xA1)
         * wireWriteDataByte(APDS9960_GESTURE_EXIT_THRESHOLD, DEFAULT_GESTURE_EXIT_THRESHOLD)
         *
         * Set default Gesture FIFO Threshold to 0x80 (Reg = 0xA2)
         * wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_ONE, DEFAULT_GESTURE_CONFIGURE_ONE) 
         *
         * Set default values of Gesture LEDCurrent, Gain, and wait time to 100 mA, 4, and 2.78 ms(Reg = 0xA3)
         * wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_TWO, DEFAULT_GESTURE_CONFIGURE_TWO)
         *
         * Set default values of Gesture Pulse Count and Pulse Width (Reg = 0xA6)
         * wireWriteDataByte(APDS9960_GESTURE_PULSE_SETTING, DEFAULT_GESTURE_PULSE)
         */
    else if(!(wireWriteDataByte(APDS9960_ENABLE, 0x08) &&
              wireWriteDataByte(APDS9960_ADC_INTEGRATION_TIME, DEFAULT_ADC_INTEGRATION_TIME) &&
              wireWriteDataByte(APDS9960_CONFIGURE_ONE, DEFAULT_CONFIGURE_ONE) &&
              wireWriteDataByte(APDS9960_PROXIMITY_PULSECOUNT, DEFAULT_PROXIMITY_PULSE_SETTING) &&
              wireWriteDataByte(APDS9960_CONTROL_ONE, DEFAULT_CONTROL_ONE) &&
              wireWriteDataByte(APDS9960_GESTURE_PROXIMITY_ENTER_THRESHOLD, DEFAULT_GESTURE_ENTER_THRESHOLD) &&
              wireWriteDataByte(APDS9960_GESTURE_EXIT_THRESHOLD, DEFAULT_GESTURE_EXIT_THRESHOLD) &&
              wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_ONE, DEFAULT_GESTURE_CONFIGURE_ONE) &&
              wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_TWO, DEFAULT_GESTURE_CONFIGURE_TWO) &&
              wireWriteDataByte(APDS9960_GESTURE_PULSE_SETTING, DEFAULT_GESTURE_PULSE)))
            return false;

    /*
     * Set default Wait time (Reg = 0x83) to DEFAULT_WAIT_TIME i.e. 2.78 ms
     * wireWriteDataByte(APDS9960_WAIT_TIME, DEFAULT_WAIT_TIME)
     *
     * Set default LEDBoost to 100% (Reg = 0x90)
     * wireWriteDataByte(APDS9960_CONFIGURE_TWO, DEFAULT_CONFIGURE_TWO)
     *
     * Enable Up-Down Left-Right FIFO data (Reg = 0xAA)
     * wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_THREE, DEFAULT_GESTURE_CONFIGURE_THREE)
     *
     */
    if(!(wireWriteDataByte(APDS9960_WAIT_TIME, DEFAULT_WAIT_TIME) &&
         wireWriteDataByte(APDS9960_CONFIGURE_TWO, DEFAULT_CONFIGURE_TWO) &&
         wireWriteDataByte(APDS9960_GESTURE_CONFIGURE_THREE, DEFAULT_GESTURE_CONFIGURE_THREE)))
       return false;

    return true;
}

void APDS9960::readGestureData(uint8_t cmdID)
{
    /* 32 bytes of gesture data */
    unsigned int gestureDataBytesNum = 32;
    /* Create a uint8_t array to hold 8 datasets i.e. 32 bytes */
    uint8_t gestureFIFOData[gestureDataBytesNum];
    /* Timeout variable */
    unsigned long gestureTimeout = 0;
    /* Gesture status byte */
    uint8_t gestureStatus = 0;
    /* Check if gesture data is read back */
    uint8_t gestureDetected = 0;
    /* Check if gesture timeout has occured */
    uint8_t gestureTimeoutFlag = 1;
    /* Number of bytes read from the sensor */
    uint8_t bytesRead = 0;

    debugPrint(MSG_APDS9960_READ_GESTURE);

    /* Start the timer */
    gestureTimeout = millis();

    /* Wait until GVALID bit is set i.e. a gesture is detected and timeout is not reached
     * or break out of the loop if timeout occurs i.e. no hand movemement is detected
     * by the sensor within the timeout period
     */
    while(!gestureDetected && (millis() - gestureTimeout < GESTURE_TIMEOUT))
    {
        /* Read the STATUS register */
        wireReadDataBytes(APDS9960_GESTURE_STATUS, &gestureStatus, 1);
        /* Check the GVALID bit. Read from the FIFO only if the GVALID is 1
         * GVALID is bit number 0 in the STATUS register
         * GVALID = 1 indicates that valid data has been recorded in
         * the FIFO due to a hand movement over the photodiodes
         */
        if ((gestureStatus & 0x01) == 1)
        {
            /* Read current 8 datasets from the FIFO i.e. 32 bytes */
            bytesRead = wireReadDataBytes(APDS9960_GESTURE_DATA, (uint8_t*)gestureFIFOData, gestureDataBytesNum);
            /* Set the flag to break out of while loop */
            gestureDetected = 1;
            /* Reset the timeout flag */
            gestureTimeoutFlag = 0;
        }
    }

    if(gestureTimeoutFlag)
    {
        /* Send the status of gesture read */
        sendResponseMsg(cmdID, &gestureDetected, 1);
    }
    else
    {
        /* Check if 32 bytes are read successfully */
        if(bytesRead != gestureDataBytesNum)
        {
            /* Send the status of gesture read */
            sendResponseMsg(cmdID, &gestureDetected, 1);
        }
        else
        {
            /* Send out the gesture data to MATLAB */
            sendResponseMsg(cmdID, gestureFIFOData, gestureDataBytesNum);
        }
    }

}

bool APDS9960::wireWriteDataByte(uint8_t registerAddress, uint8_t registerVal)
{
    uint8_t status;
    apds9960WireObj->beginTransmission(deviceAddress);
    /* Indicate which register we want to write to */
    apds9960WireObj->write(registerAddress);
    /* Indicate the value to be written */
    apds9960WireObj->write(registerVal);
    status = apds9960WireObj->endTransmission();

    /* Print out the debug messages */
    /* Print debug message for beginTransmission */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_BEGIN_TRANSMISSION, "",deviceAddress) : debugPrint(MSG_APDS9960_BEGIN_TRANSMISSION, "1", deviceAddress);
    /* Print debug message for write */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_WRITE_VALUE, "",registerAddress, 1) : debugPrint(MSG_APDS9960_WRITE_VALUE, "1", registerAddress, 1);
    /* Print debug message for write */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_WRITE_VALUE, "",registerVal, 1) : debugPrint(MSG_APDS9960_WRITE_VALUE, "1", registerVal, 1);
    /* Print debug message for endTranmssion */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_END_TRANSMISSION, "", status) : debugPrint(MSG_APDS9960_END_TRANSMISSION, "1", status);

    /* Return true if data write is successful */
    if(!status)
        return true;
    else
        return false;
}

uint8_t APDS9960::wireReadDataBytes(uint8_t registerAddress, uint8_t *registerVal, unsigned int numBytes)
{
    unsigned char byteIndex = 0;
    uint8_t status;

    /* Indicate which register we want to read from */
    apds9960WireObj->beginTransmission(deviceAddress);
    apds9960WireObj->write(registerAddress);
    status = apds9960WireObj->endTransmission();

    /* Print out debug messages */
    /* Print debug message for beginTransmission */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_BEGIN_TRANSMISSION, "",deviceAddress) : debugPrint(MSG_APDS9960_BEGIN_TRANSMISSION, "1", deviceAddress);
    /* Print debug message for write */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_WRITE_VALUE, "",registerAddress, 1) : debugPrint(MSG_APDS9960_WRITE_VALUE, "1", registerAddress, 1);
    /* Print debug message for endTranmssion */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_END_TRANSMISSION, "", status) : debugPrint(MSG_APDS9960_END_TRANSMISSION, "1", status);

    /* Read data bytes */
    apds9960WireObj->requestFrom(deviceAddress, numBytes);

    /* Print debug message for requestFrom i.e. requesting databytes from sensor */
    (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_REQUEST_FROM, "",deviceAddress, numBytes, 1) : debugPrint(MSG_APDS9960_REQUEST_FROM, "1", deviceAddress, numBytes, 1);

    while (apds9960WireObj->available())
    {
        if (byteIndex >= numBytes)
        {
            return 0;
        }
        /* Read data bytes until data is available to be read */
        registerVal[byteIndex] = apds9960WireObj->read();
        /* Print debgug message for data read */
        (i2cBusNum == 0) ? debugPrint(MSG_APDS9960_READ_VALUE, "", registerVal[byteIndex]) : debugPrint(MSG_APDS9960_READ_VALUE, "1", registerVal[byteIndex]);
        byteIndex++;
    }

    return byteIndex;
}