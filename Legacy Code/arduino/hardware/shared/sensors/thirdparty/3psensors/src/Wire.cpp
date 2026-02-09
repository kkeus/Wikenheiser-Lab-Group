// Copyright 2022 The MathWorks, Inc.
#include "MW_I2C.h"
#include <inttypes.h>
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include "Wire.h"
#include "Arduino.h"

MW_Handle_Type handletype;
uint8_T slaveAddress;
uint8_T dataTx[128];
size_t length;
size_t rxLength;
int counter=0;
uint8_T *data;
uint8_T sendStp;
TwoWire::TwoWire() {}
uint8_T pdata[30];
uint8_T i2cModule;

size_t   txBufferIndex = 0;
size_t  txBufferLength = 0;

uint8_t transmitting = 0;

void TwoWire::setI2cModule(uint8_T moduleValue)
{
    i2cModule = moduleValue;
}
void TwoWire::begin(void)
{
    handletype = MW_I2C_Open(i2cModule, MW_I2C_MASTER );
    //     handletype = MW_I2C_Open(0, MW_I2C_MASTER );
}

void TwoWire::begin(uint8_T address)
{
    txBufferIndex = 0;
    txBufferLength = 0;
    begin();

}

void TwoWire::begin(int address)
{
    begin((uint8_T)address);
}

void TwoWire::setClock(uint32_t frequency)
{
    MW_I2C_SetBusSpeed(handletype,frequency);
}

size_t TwoWire::requestFrom(uint8_T address, size_t size, bool sendStop)
{
    slaveAddress=address;
    rxLength = size;
    sendStp=sendStop;
    return size;
}

uint8_T TwoWire::requestFrom(uint8_T address, uint8_T quantity, uint8_T sendStop)
{
    return requestFrom(address, static_cast<size_t>(quantity), static_cast<bool>(sendStop));
}

uint8_T TwoWire::requestFrom(uint8_T address, uint8_T quantity)
{
    return requestFrom(address, static_cast<size_t>(quantity), true);
}

uint8_T TwoWire::requestFrom(int address, int quantity)
{
    return requestFrom(static_cast<uint8_T>(address), static_cast<size_t>(quantity), true);
}

uint8_T TwoWire::requestFrom(int address, int quantity, int sendStop)
{
    return requestFrom(static_cast<uint8_T>(address), static_cast<size_t>(quantity), static_cast<bool>(sendStop));
}

void TwoWire::beginTransmission(uint8_T address)
{
    slaveAddress=address;
    txBufferIndex = 0;
    txBufferLength = 0;
}

void TwoWire::beginTransmission(int address)
{
    beginTransmission((uint8_T)address);
}

uint8_T TwoWire::endTransmission(uint8_T sendStop)
{
    uint8_t c= MW_I2C_MasterWrite(handletype, slaveAddress,  &dataTx[0], txBufferLength, sendStop, false);
    txBufferIndex = 0;
    txBufferLength = 0;
    transmitting = 0;
    return c;
}

uint8_T TwoWire::endTransmission(void)
{

    return endTransmission(true);
}

size_t TwoWire::write(uint8_T data)
{
    if (txBufferLength >= 128)
    {
        return 0;
    }
    dataTx[txBufferIndex] = data;
    ++txBufferIndex;
    txBufferLength = txBufferIndex;
    return 1;
}

size_t TwoWire::write(const uint8_T *data, size_t quantity)
{
    for(size_t i = 0; i < quantity; ++i){
        write(data[i]);
    }
    return quantity;
}

int TwoWire::available(void)
{
    return 1;
}

uint8_T * TwoWire::actualRead()
{
    MW_I2C_MasterRead(handletype, slaveAddress, &pdata[0], rxLength, sendStp, true);
    return pdata;
}

int TwoWire::read(void)
{
    if(counter==0){
        data = actualRead();
    }
    int value=data[counter];
    counter++;
    if(counter>=rxLength){
        counter=0;
    }
    return value;
}


#if !defined(NO_GLOBAL_INSTANCES) && !defined(NO_GLOBAL_TwoWire)
TwoWire Wire;
#endif