/**
 * @file scheduler_configuration.h
 *
 * @Copyright 2017-2020 The MathWorks, Inc.
 *
 */
#include "rtwtypes.h"
#define TimeScaleConversion 1000000    // Convert second into microsecond

extern volatile uint16_T TimerCounter;

void configureScheduler(float);   // For soft-real time

void enableSchedulerInterrupt(void);

void disableSchedulerInterrupt(void);

void enableGlobalInterrupt(void);

void disableGlobalInterrupt(void);

void stopScheduler(void);
