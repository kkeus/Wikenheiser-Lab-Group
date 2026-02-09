/*
HardwareSerial.cpp - Hardware serial library for Wiring
Copyright (c) 2006 Nicholas Zambetti.  All right reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

Modified 23 November 2006 by David A. Mellis
Modified 28 September 2010 by Mark Sproul
Modified 14 August 2012 by Alarus
Modified 3 December 2013 by Matthijs Kooijman
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

// #include <util/atomic.h>
#include "Arduino.h"

void serialEventRun(void)
{


    unsigned long millis(void){return 0;};
    unsigned long micros(void){return 0;};
    void delay(unsigned long ms){};
    void delayMicroseconds(unsigned int us){};
    void yield(void){};

    void HardwareSerial::_tx_udr_empty_irq(void)
    {

    }

    // Public Methods //////////////////////////////////////////////////////////////
    HardwareSerial::HardwareSerial() {}
    void HardwareSerial::begin(unsigned long baud, byte config)
    {
    }

    void HardwareSerial::end()
    {
    }

    int HardwareSerial::available(void)
    {
    }

    int HardwareSerial::peek(void)
    {
    }

    int HardwareSerial::read(void)
    {
    }

    int HardwareSerial::availableForWrite(void)
    {
        return 1;
    }

    void HardwareSerial::flush()
    {

    }

    size_t HardwareSerial::write(uint8_t c)
    {
        return 1;
    }

    size_t HardwareSerial::write(const uint8_t *buffer, size_t size)
    {
        return 1;
    }

    size_t HardwareSerial::print(const char str[])
    {
        return 1;
    }

    size_t HardwareSerial::print(char c)
    {
        return 1;
    }

    size_t HardwareSerial::print(unsigned char b, int base)
    {
        return 1;
    }

    size_t HardwareSerial::print(int n, int base)
    {
        return 1;
    }

    size_t HardwareSerial::print(unsigned int n, int base)
    {
        return 1;
    }

    size_t HardwareSerial::print(long n, int base)
    {
        return 1;
    }

    size_t HardwareSerial::print(unsigned long n, int base)
    {
        return 1;
    }

    size_t HardwareSerial::print(double n, int digits)
    {
        return 1;
    }

    size_t HardwareSerial::println(void)
    {
        return 1;
    }

    size_t HardwareSerial::println(const char c[])
    {
        return 1;
    }

    size_t HardwareSerial::println(char c)
    {
        return 1;
    }

    size_t HardwareSerial::println(unsigned char b, int base)
    {
        return 1;
    }

    size_t HardwareSerial::println(int num, int base)
    {
        return 1;
    }

    size_t HardwareSerial::println(unsigned int num, int base)
    {
        return 1;
    }

    size_t HardwareSerial::println(long num, int base)
    {
        return 1;
    }

    size_t HardwareSerial::println(unsigned long num, int base)
    {
        return 1;
    }

    size_t HardwareSerial::println(double num, int digits)
    {
        return 1;
    }
    // Private Methods /////////////////////////////////////////////////////////////

    size_t HardwareSerial::printNumber(unsigned long n, uint8_t base)
    {
        return 1;
    }

    size_t HardwareSerial::printFloat(double number, uint8_t digits)
    {
        return 1;
    }



    #define SPI_PINS_HSPI			0 // Normal HSPI mode (MISO = GPIO12, MOSI = GPIO13, SCLK = GPIO14);
    #define SPI_PINS_HSPI_OVERLAP	1 // HSPI Overllaped in spi0 pins (MISO = SD0, MOSI = SDD1, SCLK = CLK);

    #define SPI_OVERLAP_SS 0


    typedef union {
        uint32_t regValue;
        struct {
            unsigned regL :6;
            unsigned regH :6;
            unsigned regN :6;
            unsigned regPre :13;
            unsigned regEQU :1;
        };
    } spiClk_t;

    SPIClass::SPIClass() {

    }

    bool SPIClass::pins(int8_t sck, int8_t miso, int8_t mosi, int8_t ss)
    {

        return true;
    }

    void SPIClass::begin() {

    }

    void SPIClass::end() {

    }

    void SPIClass::setHwCs(bool use) {

    }

    void SPIClass::beginTransaction(SPISettings settings) {

    }

    void SPIClass::endTransaction() {
    }

    void SPIClass::setDataMode(uint8_t dataMode) {
    }

    void SPIClass::setBitOrder(uint8_t bitOrder) {

    }


    static uint32_t ClkRegToFreq(spiClk_t * reg) {

    }

    void SPIClass::setFrequency(uint32_t freq) {

    }

    void SPIClass::setClockDivider(uint32_t clockDiv) {

    }

    inline void SPIClass::setDataBits(uint16_t bits) {

    }

    uint8_t SPIClass::transfer(uint8_t data) {

    }

    uint16_t SPIClass::transfer16(uint16_t data) {

    }

    void SPIClass::transfer(void *buf, uint16_t count) {

    }

    void SPIClass::write(uint8_t data) {

    }

    void SPIClass::write16(uint16_t data) {

    }

    void SPIClass::write16(uint16_t data, bool msb) {

    }

    void SPIClass::writePattern(const uint8_t * data, uint8_t size, uint32_t repeat) {

    }

    void SPIClass::transferBytes(const uint8_t * out, uint8_t * in, uint32_t size) {

    }


    void SPIClass::transferBytesAligned_(const uint8_t * out, uint8_t * in, uint8_t size) {

    }


    void SPIClass::transferBytes_(const uint8_t * out, uint8_t * in, uint8_t size) {

    }


    #if !defined(NO_GLOBAL_INSTANCES) && !defined(NO_GLOBAL_SPI)
    extern SPIClass SPI;
    #endif

    #if !defined(NO_GLOBAL_INSTANCES) && !defined(NO_GLOBAL_Serial)
    extern HardwareSerial Serial;
    #endif