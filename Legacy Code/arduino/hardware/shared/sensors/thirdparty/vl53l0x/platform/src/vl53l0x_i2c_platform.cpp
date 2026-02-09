/* Copyright 2021-22 The MathWorks, Inc. */
#include "vl53l0x_def.h"
#include "vl53l0x_i2c_platform.h"
#if !( defined(MATLAB_MEX_FILE) || defined(RSIM_PARAMETER_LOADING) ||  defined(RSIM_WITH_SL_SOLVER))
#include "MW_I2C.h"


MW_Handle_Type handletype;

int VL53L0X_i2c_init(uint32_t i2cModule) {
    handletype = MW_I2C_Open(i2cModule, MW_I2C_MASTER );
    return VL53L0X_ERROR_NONE;
}

int32_t VL53L0X_write_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata, uint32_t  count) {
    uint8_T fdata[count+1];
    fdata[0] = index;
    int32_t i = 0;
    for (i=0;i<count;i++){
        fdata[i+1] = pdata[i];
    }
    return MW_I2C_MasterWrite(handletype, deviceAddress,  &fdata[0], count+1, false, false);
}

int32_t VL53L0X_read_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata,
                           uint32_t  count) {
    MW_I2C_MasterWrite(handletype, deviceAddress, &index, 1, true, false);
    MW_I2C_MasterRead(handletype, deviceAddress, &pdata[0], count, false, true);
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
