/* Copyright 2021-22 The MathWorks, Inc. */
#ifndef VL53L0X_MAIN
#define VL53L0X_MAIN
#if !( defined(MATLAB_MEX_FILE) || defined(RSIM_PARAMETER_LOADING) ||  defined(RSIM_WITH_SL_SOLVER))
#include "vl53l0x_api.h"
#include "vl53l0x_platform.h"
#ifdef __cplusplus
extern "C" {
    #endif
    void initializeVL53L0X(uint8_t,uint32_t,char *rangingMode);
    uint16_t calculateRange();
    VL53L0X_Error setNewI2CAddress(uint8_t newAddress);
    void rangingModeConfigure(char *inputString);
    #ifdef __cplusplus
}
#endif
#else
#define initializeVL53L0X(...) (0)
#define calculateRange() (0)
#endif
#endif



