/* Copyright 2021 The MathWorks, Inc. */

int VL53L0X_i2c_init(uint32_t i2cModule);

int32_t VL53L0X_write_byte(uint8_t deviceAddress, uint8_t index, uint8_t data);

int32_t VL53L0X_write_word(uint8_t deviceAddress, uint8_t index, uint16_t data);

int32_t VL53L0X_write_dword(uint8_t deviceAddress, uint8_t index, uint32_t data);

int32_t VL53L0X_read_byte(uint8_t deviceAddress, uint8_t index, uint8_t *data);

int32_t VL53L0X_read_word(uint8_t deviceAddress, uint8_t index, uint16_t *data);

int32_t VL53L0X_read_dword(uint8_t deviceAddress, uint8_t index, uint32_t *data);

int32_t VL53L0X_write_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata, uint32_t count);

int32_t VL53L0X_read_multi(uint8_t deviceAddress, uint8_t index, uint8_t *pdata, uint32_t count);
