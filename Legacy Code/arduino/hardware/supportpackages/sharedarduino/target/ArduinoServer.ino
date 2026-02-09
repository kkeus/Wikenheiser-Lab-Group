
/* Copyright 2017-2021 The MathWorks, Inc. */
#if defined ARDUINO_ARCH_AVR || defined ARDUINO_ARCH_SAM || defined ARDUINO_ARCH_SAMD
    #include <avr/pgmspace.h>
#endif
#include "boardInit.h"
extern "C"{
#include "IO_include.h"
#include "IO_server.h"
#include "IO_packet.h"
#include "scheduler_configuration.h"
#include "rt_OneStep.h"
/*To get the ADD_ON marco definition*/
#include "peripheralIncludes.h"
#if ADD_ON
#include "hardware.h"
#include "MWArduinoClass.h"
extern MWArduinoClass hwObject;
#endif


// Used for soft Real Time implementation
unsigned long oldtime = 0L;
unsigned long actualtime;

/*IO Server End*/


}

uint8_T PayloadBufferRxBackground[PAYLOAD_SIZE];
uint8_T PayloadBufferTxBackground[PAYLOAD_SIZE];

void setup()
{
    boardInit();
    ioServerInit();

/* Execute setup function for all the add-on libraries*/
#if ADD_ON
    LibraryBase* tempLib = NULL;
    for(int count = 0; count < hwObject.noOfLibraries; count++)    
    {
        tempLib = hwObject.arrayOfLibraries[count];
        tempLib->setup();
    }
#endif  
}

void loop()
{
/* Execute loop function for all the add-on libraries*/
#if ADD_ON
    LibraryBase* tempLib = NULL;
    for(int count = 0; count < hwObject.noOfLibraries; count++)    
    {
        tempLib = hwObject.arrayOfLibraries[count];
        tempLib->loop();
    }
#endif
      if(StreamingModeFlag)
      {
          actualtime = micros();
          if((actualtime - oldtime) >= deltaT)
          {	             
              oldtime = actualtime;
              rt_OneStep();
          }
      }
// Run background server also to respond to on-demand requests
    server((uint8_T*)&PayloadBufferRxBackground,(uint8_T*)&PayloadBufferTxBackground,(uint8_T)1);
}

