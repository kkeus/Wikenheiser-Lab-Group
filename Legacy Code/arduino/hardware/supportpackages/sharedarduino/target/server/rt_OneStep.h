// Imported from scheduler_configuration.c
extern unsigned long deltaT;
extern uint8_T StreamingModeFlag;

// This is executed every time interrupt is called or every time soft real time loop is executed
void rt_OneStep(void)
{
	serverScheduler();
}