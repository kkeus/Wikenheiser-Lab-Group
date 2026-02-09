/* Copyright 2024 The MathWorks, Inc. */
#include "vl53l0x_def.h"
#include "vl53l0x_i2c_platform.h"
#if !( defined(MATLAB_MEX_FILE) || defined(RSIM_PARAMETER_LOADING) ||  defined(RSIM_WITH_SL_SOLVER))
#include "mw_stm32_i2c_ll.h"
#include <stdint.h>
#include <cstring>




STM32_I2C_Struct_T i2cBlockStruct;
STM32_I2C_Struct_T* i2cBlockStruct2;
STM32_I2C_Struct_T* i2cBlockStruct_loc;
STM32_I2C_Struct_T * MW_I2C_HANDLE;

int VL53L0X_i2c_init(uint32_t i2cModule) {
    STM32_I2C_ModuleStruct_T c;

    if (i2cModule == 1) {
        #if defined(I2C1)
        c.instance = I2C1;
        #endif
    } else if (i2cModule == 2) {
        #if defined(I2C2)
        c.instance = I2C2;
        #endif
    } else if (i2cModule == 3) {
        #if defined(I2C3)
        c.instance = I2C3;
        #endif
    } else if (i2cModule == 4) {
        #if defined(I2C4)
        c.instance = I2C4;
        #endif
    } else if (i2cModule == 5) {
        #if defined(I2C5)
        c.instance = I2C5;
        #endif
    }

    c.txCommunicationMode = MW_I2C_COMMUNICATION_POLLING;
    c.rxCommunicationMode = MW_I2C_COMMUNICATION_POLLING;
    // Initialize the I2C module
    i2cBlockStruct.h_i2c = NULL;
    i2cBlockStruct.rxBufferStructPtr = NULL;
    i2cBlockStruct.txBufferStructPtr = NULL;
    i2cBlockStruct_loc = &i2cBlockStruct;
    MW_I2C_HANDLE = I2C_Init(&c,i2cBlockStruct_loc);

    return VL53L0X_ERROR_NONE;
}

int32_t VL53L0X_write_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata, uint32_t  count) {
    uint8_t fdata[count + 1];
    fdata[0] = index;
    uint32_t i = 0;
    for (i=0;i<count;i++){
        fdata[i+1] = pdata[i];
    }
    return I2C_Controller_TransmitData_Polling(MW_I2C_HANDLE, 41, &fdata[0], count + 1, false,false, 1U);
}

int32_t VL53L0X_read_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata,
                           uint32_t  count) {
    // Write the index to the device
    I2C_Controller_TransmitData_Polling(MW_I2C_HANDLE, 41, &index, 1U, true, true, 1U);
    // Read the data from the device
    I2C_Controller_ReceiveData_Polling(MW_I2C_HANDLE, 41, pdata, count, false, false, 1U);
    return VL53L0X_ERROR_NONE;
}

int32_t VL53L0X_write_byte(uint8_t deviceAddress, uint8_t index, uint8_t data) {
    return VL53L0X_write_multi(deviceAddress, index, &data, 1);
}
#else
int VL53L0X_i2c_init(uint32_t i2cModule) {
    return 0;
}

int32_t VL53L0X_write_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata, uint32_t  count) {
    return VL53L0X_ERROR_NONE;
}

int32_t VL53L0X_read_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata,
                           uint32_t  count) {
    return VL53L0X_ERROR_NONE;
}

int32_t VL53L0X_write_byte(uint8_t deviceAddress, uint8_t index, uint8_t data) {
    return VL53L0X_write_multi(deviceAddress, index, &data, 1);
}
#endif

int32_t VL53L0X_write_word(uint8_t deviceAddress, uint8_t index, uint16_t data) {
    uint8_t buff[2];
    buff[1] = data & 0xFF;
    buff[0] = data >> 8;
    return VL53L0X_write_multi(deviceAddress, index, buff, 2);
}

int32_t VL53L0X_write_dword(uint8_t deviceAddress, uint8_t index, uint32_t data) {
    uint8_t buff[4];

    buff[3] = data & 0xFF;
    buff[2] = data >> 8;
    buff[1] = data >> 16;
    buff[0] = data >> 24;

    return VL53L0X_write_multi(deviceAddress, index, buff, 4);
}

int32_t VL53L0X_read_byte(uint8_t deviceAddress, uint8_t index, uint8_t *data) {
    return VL53L0X_read_multi(deviceAddress, index, data, 1);
}

int32_t VL53L0X_read_word(uint8_t deviceAddress, uint8_t index, uint16_t *data) {
    uint8_t buff[2];
    int32_t r = VL53L0X_read_multi(deviceAddress, index, buff, 2);

    uint16_t tmp;
    tmp = buff[0];
    tmp <<= 8;
    tmp |= buff[1];
    *data = tmp;

    return r;
}

int32_t VL53L0X_read_dword(uint8_t deviceAddress, uint8_t index, uint32_t *data) {
    uint8_t buff[4];
    int32_t r = VL53L0X_read_multi(deviceAddress, index, buff, 4);

    uint32_t tmp;
    tmp = buff[0];
    tmp <<= 8;
    tmp |= buff[1];
    tmp <<= 8;
    tmp |= buff[2];
    tmp <<= 8;
    tmp |= buff[3];

    *data = tmp;

    return r;
}
