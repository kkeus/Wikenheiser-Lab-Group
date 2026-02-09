/* Copyright 2021-22 The MathWorks, Inc. */
#include "vl53l0x_api_core.h"
#define VL53L0X_I2C_ADDR 0x29
#ifndef VL53L0X_MAIN
#include "vl53l0x_main.h"
#endif
#include "vl53l0x_api.h"
VL53L0X_RangingMeasurementData_t RangingMeasurementDataSample= {(uint32_t)0,(uint32_t)0,(uint16_t)0,(uint16_t)0,(FixPoint1616_t)0,(FixPoint1616_t)0,(uint16_t)0,(uint8_t)0,(uint8_t)0,(uint8_t)0};
#ifdef __cplusplus
extern "C" {
    #endif
    #if !( defined(MATLAB_MEX_FILE) || defined(RSIM_PARAMETER_LOADING) ||  defined(RSIM_WITH_SL_SOLVER))
    VL53L0X_Dev_t MyDevice;
    VL53L0X_Dev_t *pMyDevice = &MyDevice;
    VL53L0X_DeviceInfo_t DeviceInfo;
    void initializeVL53L0X(uint8_t deviceAddress,uint32_t i2cModule,char *rangingMode)
    {
        uint32_t refSpadCount;
        uint8_t isApertureSpads;
        uint8_t VhvSettings;
        uint8_t PhaseCal;
        VL53L0X_Error Status;
        pMyDevice->I2cDevAddr = VL53L0X_I2C_ADDR;
        pMyDevice->comms_type = 1;
        pMyDevice->comms_speed_khz = 400;
        VL53L0X_i2c_init(i2cModule);
        Status = setNewI2CAddress(deviceAddress);
        if (Status == VL53L0X_ERROR_NONE) {
        Status = VL53L0X_DataInit(&MyDevice);
        Status = VL53L0X_StaticInit(pMyDevice);
        VL53L0X_PerformRefSpadManagement(pMyDevice, &refSpadCount, &isApertureSpads);
        VL53L0X_PerformRefCalibration(pMyDevice, &VhvSettings,&PhaseCal);
        VL53L0X_SetDeviceMode(pMyDevice,VL53L0X_DEVICEMODE_SINGLE_RANGING);
        rangingModeConfigure(rangingMode);
        }
    }

    void rangingModeConfigure(char *inputString){
        VL53L0X_SetLimitCheckEnable(pMyDevice, VL53L0X_CHECKENABLE_SIGMA_FINAL_RANGE, 1);
        VL53L0X_SetLimitCheckEnable(pMyDevice, VL53L0X_CHECKENABLE_SIGNAL_RATE_FINAL_RANGE, 1);
        if (strcmp(inputString,"Default")==0){
            VL53L0X_SetLimitCheckEnable(pMyDevice,VL53L0X_CHECKENABLE_RANGE_IGNORE_THRESHOLD,1);
            VL53L0X_SetLimitCheckValue(pMyDevice, VL53L0X_CHECKENABLE_RANGE_IGNORE_THRESHOLD,(FixPoint1616_t)(1.5 * 0.023 * 65536));
        }else if (strcmp(inputString,"High accuracy")==0){
            VL53L0X_SetLimitCheckValue(pMyDevice,VL53L0X_CHECKENABLE_SIGNAL_RATE_FINAL_RANGE,(FixPoint1616_t)(0.25 * 65536));
            VL53L0X_SetLimitCheckValue(pMyDevice,VL53L0X_CHECKENABLE_SIGMA_FINAL_RANGE,(FixPoint1616_t)(18 * 65536));
            VL53L0X_SetMeasurementTimingBudgetMicroSeconds(pMyDevice,200000);
            VL53L0X_SetLimitCheckEnable(pMyDevice, VL53L0X_CHECKENABLE_RANGE_IGNORE_THRESHOLD, 0);
        }else if (strcmp(inputString,"Long range")==0){
            VL53L0X_SetLimitCheckValue(pMyDevice, VL53L0X_CHECKENABLE_SIGNAL_RATE_FINAL_RANGE,(FixPoint1616_t)(0.1 * 65536));
            VL53L0X_SetLimitCheckValue(pMyDevice,VL53L0X_CHECKENABLE_SIGMA_FINAL_RANGE,(FixPoint1616_t)(60 * 65536));
            VL53L0X_SetMeasurementTimingBudgetMicroSeconds(pMyDevice, 33000);
            VL53L0X_SetVcselPulsePeriod(pMyDevice,VL53L0X_VCSEL_PERIOD_PRE_RANGE, 18);
            VL53L0X_SetVcselPulsePeriod(pMyDevice, VL53L0X_VCSEL_PERIOD_FINAL_RANGE, 14);
        }else if (strcmp(inputString,"High speed")==0){
            VL53L0X_SetLimitCheckValue(pMyDevice, VL53L0X_CHECKENABLE_SIGNAL_RATE_FINAL_RANGE,(FixPoint1616_t)(0.25 * 65536));
            VL53L0X_SetLimitCheckValue(pMyDevice,VL53L0X_CHECKENABLE_SIGMA_FINAL_RANGE,(FixPoint1616_t)(32 * 65536));
            VL53L0X_SetMeasurementTimingBudgetMicroSeconds(pMyDevice, 20000);
        }
    }

    uint16_t calculateRange(){
        VL53L0X_RangingMeasurementData_t *RangingMeasurementData = &RangingMeasurementDataSample;
        VL53L0X_PerformSingleRangingMeasurement(pMyDevice,
                                                RangingMeasurementData);
        return uint16_t(RangingMeasurementData->RangeMilliMeter);
    }

    VL53L0X_Error setNewI2CAddress(uint8_t newAddress){
        VL53L0X_Error Status;
        newAddress &= 0x7F;
        Status = VL53L0X_SetDeviceAddress(pMyDevice, newAddress * 2);
        pMyDevice->I2cDevAddr = newAddress;
        return Status;
    }
    #endif
    #ifdef __cplusplus
}
#endif