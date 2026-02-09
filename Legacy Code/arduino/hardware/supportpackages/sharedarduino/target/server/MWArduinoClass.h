/**
 * @file MWArduinoClass.h
 *
 * Class definition for Hardware Interface between IOServer and Add-on Libraires.
 *
 * @copyright Copyright 2018 The MathWorks, Inc.
 *
 */

#ifndef MWArduino_Class_h
#define MWArduino_Class_h
class MWArduinoClass : public Hardware{
    public:
        MWArduinoClass()
        {
          noOfLibraries = 0;
        }
};
#endif