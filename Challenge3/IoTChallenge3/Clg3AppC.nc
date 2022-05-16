#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration Clg3AppC{
}
implementation {
  components MainC, Clg3C, LedsC;
  components new TimerMilliC();
  components SerialPrintfC;
  components SerialStartC;

  Clg3C.Boot -> MainC;
  Clg3C.Timer -> TimerMilliC;
  Clg3C.Leds -> LedsC;
}
