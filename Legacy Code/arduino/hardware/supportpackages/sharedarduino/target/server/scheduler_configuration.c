#include "scheduler_configuration.h"
unsigned long deltaT = 1000;

uint8_T StreamingModeFlag = 0;

// Use this configureScheduler function when using Soft Real-Time. The SchedulerBaseRate is the actual sample time in float.
void configureScheduler(float SchedulerBaseRate)
{
	deltaT = (unsigned long)(SchedulerBaseRate*TimeScaleConversion); // SchedulerBaseRate is in second. Convert it into millisecond/microsecond
	
	// This flag will trigger the streaming mode operation
    StreamingModeFlag=1;
}
//Hook to enable the scheduler interrupt
void enableSchedulerInterrupt(void)
{

}
//Hook to disable the scheduler interrupt
void disableSchedulerInterrupt(void)
{

}
//Hook to enable the global interrupt on the target
void enableGlobalInterrupt(void)
{

}
//Hook to disable the global interrupt on the target
void disableGlobalInterrupt(void)
{

}
//Hook to stop the scheduler
void stopScheduler(void)
{
	StreamingModeFlag = 0;
}

