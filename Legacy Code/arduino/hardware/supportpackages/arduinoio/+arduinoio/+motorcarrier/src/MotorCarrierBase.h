/**
 * @file MotorCarrierBase.h
 *
 * Class definition for MotorCarrierBase class that wraps APIs of Arduino MKR or Nano Motor carrier library
 *
 * @copyright Copyright 2020 The MathWorks, Inc.
 *
 */

#include "LibraryBase.h"
#if defined(ARDUINO_SAMD_NANO_33_IOT)
    #include "ArduinoMotorCarrier.h"
#else
    #include "MKRMotorCarrier.h"
#endif

bool mcused = 0;
mc::MotorController controllerMW;

mc::ServoMotor servos[4] = {
    mc::ServoMotor(),
    mc::ServoMotor(),
    mc::ServoMotor(),
    mc::ServoMotor(),
};

mc::DCMotor dcmotors[2] = {
    mc::DCMotor(),
    mc::DCMotor(),
};

d21::DCMotor dcmotorsd21[2] = {
    d21::DCMotor(),
    d21::DCMotor(),
};

mc::Encoder encoders[2] = {
    mc::Encoder(),
    mc::Encoder(),
};

mc::PID pid[2] = {
    mc::PID(),
    mc::PID(),
};

volatile uint8_t irq_status;

void getDataIrq(){
    irq_status = 1;
};

// Arduino trace commands
const char MSG_MC_CREATE_MOTOR_CARRIER[]         PROGMEM = "ArduinoMC.begin(%d);\n";
const char MSG_MC_DELETE_MOTOR_CARRIER[]         PROGMEM = "ArduinoMC.end[%d];\n";
const char MSG_MC_CREATE_DC_MOTOR[]              PROGMEM = "ArduinoMC::DCM[%d].getMotor(%d);\n";
const char MSG_MC_CREATE_DC_MOTOR_MODE[]         PROGMEM = "ArduinoMC::PID[%d].setControlMode(%s);\n";
const char MSG_MC_START_DC_MOTOR[]               PROGMEM = "ArduinoMC::DCMStart[%d].setDuty(%d);\n";
const char MSG_MC_RELEASE_DC_MOTOR[]             PROGMEM = "ArduinoMC::DCM[%d].run(4);\n";
const char MSG_MC_WRITE_DUTYCYCLE_DC_MOTOR[]     PROGMEM = "ArduinoMC::DCM[%d].setDuty(%d);\n";
const char MSG_MC_CREATE_ENCODER[]               PROGMEM = "ArduinoMC::Encoder(%d).attach();\n";
const char MSG_MC_DELETE_ENCODER[]               PROGMEM = "ArduinoMC::Encoder(%d).detach();\n";
const char MSG_MC_READ_ENCODER_COUNT[]           PROGMEM = "ArduinoMC::Encoder(%d).readCount(%ld);\n";
const char MSG_MC_READ_ENCODER_COUNT_OVERFLOW[]  PROGMEM = "ArduinoMC::Encoder(%d).Overflow(%ld);\n";
const char MSG_MC_RESET_ENCODER_COUNT[]          PROGMEM = "ArduinoMC::Encoder(%d).resetCount(%ld);\n";
const char MSG_MC_READ_ENCODER_SPEED[]           PROGMEM = "ArduinoMC::Encoder(%d).readSpeed(%ld);\n";
const char MSG_MC_SERVO_ATTACH[]                 PROGMEM = "ArduinoMC::Servo[%d].attach(%d)\n";
const char MSG_MC_SERVO_DETACH[]                 PROGMEM = "ArduinoMC::Servo[%d].detach()\n";
const char MSG_MC_SERVO_READ[]                   PROGMEM = "ArduinoMC::Servo[%d].read(); --> %d\n";
const char MSG_MC_SERVO_WRITE[]			         PROGMEM = "ArduinoMC::Servo[%d].write(%d);\n";
const char MSG_MC_WRITE_VELOCITY_DC_MOTOR[]      PROGMEM = "ArduinoMC::PID[%d].writeSpeed(%d);\n";
const char MSG_MC_WRITE_POSITION_DC_MOTOR[]      PROGMEM = "ArduinoMC::PID[%d].writeCount(%d);\n";
const char MSG_MCMKR_SETPIDGAINS[]               PROGMEM = "ArduinoMC::PID[%d].setGains(%d,%d,%d);\n";
const char MSG_MCNANO_SETPIDGAINS[]              PROGMEM = "ArduinoMC::PID[%d].setGains(%f,%f,%f);\n";
const char MSG_MC_SETMAXACCELERATION[]           PROGMEM = "ArduinoMC::PID[%d].setMaxAcceleration(%d);\n";
const char MSG_MC_SETMAXSPEED[]                  PROGMEM = "ArduinoMC::PID[%d].setMaxSpeed(%d);\n";


// motor carrier
#define CREATE_MOTOR_CARRIER         0x00
#define DELETE_MOTOR_CARRIER         0x01

//dc motor
#define CREATE_DC_MOTOR              0x02
#define START_DC_MOTOR               0x03
#define STOP_DC_MOTOR                0x04
#define SET_DUTYCYCLE_DC_MOTOR       0x05

//servo motor
#define CREATE_SERVO_MOTOR           0x06
#define CLEAR_SERVO_MOTOR            0x07
#define READ_SERVO_POSITION          0x08
#define WRITE_SERVO_POSITION         0x09


//encoder
#define CREATE_ENCODER               0x0A
#define RESET_ENCODER_COUNT          0x0B
#define READ_ENCODER_COUNT           0x0C
#define READ_ENCODER_SPEED           0x0D
#define DELETE_ENCODER               0x0E

//PID
#define SET_DCM_VELOCITY             0x0F
#define SET_DCM_POSITION             0x10

#define SET_PIDGAINS                 0x11
#define SET_MAX_ACCELERATION         0x12
#define SET_MAX_VELOCITY             0x13

static int16_t MaxAcceleration[2];
#if defined(ARDUINO_SAMD_NANO_33_IOT)
    static float Kp[2] ,Ki[2] ,Kd[2];
#else
    static int16_t Kp[2] ,Ki[2] ,Kd[2];
#endif
class MotorCarrierBase : public LibraryBase
{
public:
    MotorCarrierBase(MWArduinoClass& a)
    {
        libName = "MotorCarrier";
        a.registerLibrary(this);
    }
    void setup(){
        
    }
    void loop(){
        if(mcused)
        {
            controllerMW.ping();
        }
    }
    
    static void resetEncoderCount(byte encodernum,int32_t count)
    {
        encoders[encodernum].resetCounter(count);
        debugPrint(MSG_MC_RESET_ENCODER_COUNT,encodernum,count);
    }
    
    static int32_t getEncoderCount(byte encodernum)
    {
        int32_t count = encoders[encodernum].getRawCount();
        debugPrint(MSG_MC_READ_ENCODER_COUNT,encodernum,count);
        return count;
    }
#if defined(ARDUINO_SAMD_NANO_33_IOT)
    static void configurePIDGains(byte motornum, float kp, float ki, float kd)
    {
        pid[motornum].setGains(kp,ki,kd);
        debugPrint(MSG_MCNANO_SETPIDGAINS,motornum,kp,ki,kd);
    }
#else
    static void configurePIDGains(byte motornum, int16_t kp, int16_t ki,int16_t kd)
    {
        pid[motornum].setGains(kp,ki,kd);
        debugPrint(MSG_MCMKR_SETPIDGAINS,motornum,kp,ki,kd);
    }
#endif
    static void setMaxAcceleration(byte motornum,int16_t acceleration)
    {
        
        pid[motornum].setMaxAcceleration(acceleration);
        debugPrint(MSG_MC_SETMAXACCELERATION,motornum,acceleration);
    }
    
    static void setMaxSpeed(byte motornum,int16_t speed)
    {
        pid[motornum].setMaxVelocity(speed);
        debugPrint(MSG_MC_SETMAXSPEED,motornum,speed);
    }
    
    void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
    {
        switch (cmdID){
            // Motor Carrier
            case CREATE_MOTOR_CARRIER:{
                byte i2caddress = dataIn[0];
                // controllerMW.begin() contains Wire.begin() and an additional 
                // enable_battery_charging() API to provide software controlled 
                // charging of the battery attached to the nano motor carrier
                #if defined(ARDUINO_SAMD_NANO_33_IOT)
                    controllerMW.begin();
                #else
                    Wire.begin();
                #endif
                debugPrint(MSG_MC_CREATE_MOTOR_CARRIER,i2caddress);
                controllerMW.reboot();
                mcused = true;
                sendResponseMsg(cmdID,0, 0);
                break;
            }
            case DELETE_MOTOR_CARRIER:{
                byte carriernum = dataIn[0];
                mcused = false;
                debugPrint(MSG_MC_DELETE_MOTOR_CARRIER,carriernum);
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            
            // DC motor
            case CREATE_DC_MOTOR:{
                byte motornum = dataIn[0];
                int pwmfreq = (int)dataIn[1];
                byte mode = dataIn[2];
                
                if ((motornum == 0) || (motornum == 1))
                {
                    dcmotors[motornum].setFrequency(pwmfreq);
                    dcmotors[motornum].setDuty(0);
                    debugPrint(MSG_MC_CREATE_DC_MOTOR,motornum,pwmfreq);
                }
                else
                {
                    dcmotorsd21[motornum-2].setFrequency(pwmfreq);
                    debugPrint(MSG_MC_CREATE_DC_MOTOR,motornum-2,pwmfreq);
                }
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            case START_DC_MOTOR:{
                byte motornum   = dataIn[0];
                int16_t dutycycle;
                dutycycle = ((int16_t)dataIn[2]<<8|(int16_t)dataIn[1]);
                if ((motornum == 0) || (motornum == 1))
                {
                    dcmotors[motornum].setDuty(dutycycle);
                    debugPrint(MSG_MC_START_DC_MOTOR,motornum,dutycycle);
                }
                else
                {
                    dcmotorsd21[motornum-2].setDuty(dutycycle);
                    debugPrint(MSG_MC_START_DC_MOTOR,motornum-2,dutycycle);
                }
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            case STOP_DC_MOTOR:{
                byte motornum = dataIn[0];
                if ((motornum == 0) || (motornum == 1))
                {
                    dcmotors[motornum].setDuty(0);
                    debugPrint(MSG_MC_RELEASE_DC_MOTOR,motornum);
                }
                else
                {
                    dcmotorsd21[motornum-2].setDuty(0);
                    debugPrint(MSG_MC_RELEASE_DC_MOTOR,motornum-2);
                }
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            case SET_DUTYCYCLE_DC_MOTOR:{
                byte motornum = dataIn[0];
                int16_t  dutycycle;
                dutycycle = ((int16_t)dataIn[2]<<8 |(int16_t)dataIn[1]);
                if ((motornum == 0) || (motornum == 1))
                {
                    dcmotors[motornum].setDuty(dutycycle);
                    debugPrint(MSG_MC_WRITE_DUTYCYCLE_DC_MOTOR,motornum,dutycycle); 
                }
                else
                {
                    dcmotorsd21[motornum-2].setDuty(dutycycle);
                    debugPrint(MSG_MC_WRITE_DUTYCYCLE_DC_MOTOR,motornum-2,dutycycle);               
                }
                
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            //Servo
            case CREATE_SERVO_MOTOR:{
                byte servonum = dataIn[0];
                int pwmfreq = (int)dataIn[1];
                servos[servonum].setFrequency(pwmfreq);
                debugPrint(MSG_MC_SERVO_ATTACH,servonum,pwmfreq);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            case CLEAR_SERVO_MOTOR:{
                byte servonum = dataIn[0];
                debugPrint(MSG_MC_SERVO_DETACH, servonum);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            case WRITE_SERVO_POSITION:{
                byte servonum = dataIn[0];
                byte angle = dataIn[1];
                servos[servonum].setAngle(angle);
                debugPrint(MSG_MC_SERVO_WRITE,servonum,angle);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            //Encoder
            case CREATE_ENCODER:{
                byte encodernum = dataIn[0];
                attachInterrupt(IRQ_PIN, getDataIrq, FALLING);
                debugPrint(MSG_MC_CREATE_ENCODER,encodernum);
                resetEncoderCount(encodernum,0);
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            case RESET_ENCODER_COUNT:{
                byte encodernum = dataIn[0];
                int32_t count = ((int32_t)(dataIn[1]))|
                        (((int32_t)dataIn[2])<<8)|
                        (((int32_t)dataIn[3])<<16)|
                        (((int32_t)dataIn[4])<<24);
                resetEncoderCount(encodernum,count);
                sendResponseMsg(cmdID, 0, 0);
                break;
            }
            case READ_ENCODER_COUNT:{
                byte encodernum = dataIn[0];
                bool resetCount = dataIn[1];
                byte result[6];
                int32_t count = getEncoderCount(encodernum);
                result[0] = (count & 0x000000ff);
                result[1] = (count & 0x0000ff00) >> 8;
                result[2] = (count & 0x00ff0000) >> 16;
                result[3] = (count & 0xff000000) >> 24;
                int16_t overflowunderflowStatus = encoders[encodernum].getOverflowUnderflow();
                result[4] = (overflowunderflowStatus & 0x00ff); //overflow status
                result[5] = (overflowunderflowStatus & 0xff00) >> 8;   // underflow status
                if(resetCount)
                    resetEncoderCount(encodernum,0);
                sendResponseMsg(cmdID, result, 6);
                break;
            }
            case READ_ENCODER_SPEED:{
                byte encodernum = dataIn[0];
                byte result[4];
                int32_t count = encoders[encodernum].getCountPerSecond();
                result[0] = (count & 0x000000ff);
                result[1] = (count & 0x0000ff00) >> 8;
                result[2] = (count & 0x00ff0000) >> 16;
                result[3] = (count & 0xff000000) >> 24;
                debugPrint(MSG_MC_READ_ENCODER_SPEED,encodernum,count);
                sendResponseMsg(cmdID, result, 4);
                break;
            }
            case DELETE_ENCODER:{
                byte encodernum = dataIn[0];
                detachInterrupt(digitalPinToInterrupt(IRQ_PIN));
                debugPrint(MSG_MC_DELETE_ENCODER,encodernum);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            //PID Control
            case SET_DCM_VELOCITY:{
                byte motornum = dataIn[0];
                int16_t targetvelocity;
                targetvelocity = ((int16_t)dataIn[2]<<8 |(int16_t)dataIn[1]);
                dcmotors[motornum].setDuty(0);
                pid[motornum].setControlMode(CL_VELOCITY);
                debugPrint(MSG_MC_CREATE_DC_MOTOR_MODE,motornum,"speed");
                //PIDGains and MaxAcceleration need configuration after setting control mode
                configurePIDGains(motornum,Kp[motornum], Ki[motornum], Kd[motornum]);
                setMaxAcceleration(motornum, MaxAcceleration[motornum]);
                pid[motornum].setSetpoint(TARGET_VELOCITY, targetvelocity);
                debugPrint(MSG_MC_WRITE_VELOCITY_DC_MOTOR,motornum,targetvelocity);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            case SET_DCM_POSITION:{
                byte motornum = dataIn[0];
                bool relativePC = dataIn[1];
            #if defined(ARDUINO_SAMD_NANO_33_IOT)
                // Firmware on Nano motor carrier allows a 23-bit targetposition
                int32_t targetposition;
                targetposition = ( (int32_t)dataIn[5]<<24 |(int32_t)dataIn[4]<<16 |(int32_t)dataIn[3]<<8 |(int32_t)dataIn[2]);
                if(relativePC)// relative position control
                {
                    int32_t currentcount = getEncoderCount(motornum);
                    targetposition = (int32_t)(currentcount + (int32_t)targetposition);
                }
            #else
                // Firmware on MKR motor carrier allows a 16-bit targetposition
                int16_t targetposition;
                targetposition = ((int16_t)dataIn[3]<<8 |(int16_t)dataIn[2]);
                if(relativePC)// relative position control
                {
                    int32_t currentcount = getEncoderCount(motornum);
                    targetposition = (int16_t)(currentcount + (int32_t)targetposition);
                }
            #endif
                dcmotors[motornum].setDuty(0);
                pid[motornum].setControlMode(CL_POSITION);
                debugPrint(MSG_MC_CREATE_DC_MOTOR_MODE,motornum,"position");
                //PIDGains and MaxAcceleration need configuration after setting control mode
                configurePIDGains(motornum, Kp[motornum], Ki[motornum], Kd[motornum]);
                setMaxAcceleration(motornum, MaxAcceleration[motornum]);
                pid[motornum].setSetpoint(TARGET_POSITION, targetposition);
                debugPrint(MSG_MC_WRITE_POSITION_DC_MOTOR,motornum, targetposition);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            case SET_PIDGAINS:{
                byte motornum = dataIn[0];
            #if defined(ARDUINO_SAMD_NANO_33_IOT)
                union Gains{
                    uint8_t gainBytes[13];
                    float K[3];
                } PIDGains;
                for(int i = 0; i < 13 ; i++)
                    PIDGains.gainBytes[i] = dataIn[i + 1];
                Kp[motornum] = PIDGains.K[0];
                Ki[motornum] = PIDGains.K[1];
                Kd[motornum] = PIDGains.K[2];
            #else
                int16_t kp,ki,kd;
                kp = ((int16_t)dataIn[2]<<8 |(int16_t)dataIn[1]);
                ki = ((int16_t)dataIn[4]<<8 |(int16_t)dataIn[3]);
                kd = ((int16_t)dataIn[6]<<8 |(int16_t)dataIn[5]);
                Kp[motornum] = kp;
                Kd[motornum] = kd;
                Ki[motornum] = ki;
             #endif
                sendResponseMsg(cmdID,0,0);
                break;
            }
            case SET_MAX_ACCELERATION:{
                byte motornum = dataIn[0];
                int16_t maxAcceleration = ((int16_t)dataIn[2]<<8 |(int16_t)dataIn[1]);
                MaxAcceleration[motornum] = maxAcceleration;
                sendResponseMsg(cmdID,0,0);
                break;
            }
            case SET_MAX_VELOCITY:{
                byte motornum = dataIn[0];
                int16_t maxvelocity = ((int16_t)dataIn[2]<<8 |(int16_t)dataIn[1]);
                setMaxSpeed(motornum,maxvelocity);
                sendResponseMsg(cmdID,0,0);
                break;
            }
            default:
                break;
        }
    }
};