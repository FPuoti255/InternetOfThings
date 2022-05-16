#include "printf.h"

#define PCODE 10638165

module Clg3C{
	uses interface Leds;
	uses interface Boot;
	uses interface Timer<TMilli>;
}
implementation{
    uint32_t quotient = PCODE;   
	uint8_t ledStatus[3] = {0, 0, 0};
    
	event void Boot.booted(){
		call Timer.startPeriodic(60000);
	}
	event void Timer.fired(){
		uint8_t remainder = 0;
		
		remainder = quotient % 3;
		quotient = quotient / 3;
		
					
		switch(remainder){
			case 0 :
				call Leds.led0Toggle();
				break;
			case 1 :
				call Leds.led1Toggle();
				break;
			case 2 :
				call Leds.led2Toggle();
				break; 
			default :
				break;		
		}
		
		ledStatus[remainder] = (ledStatus[remainder] == 0 ? 1 : 0); 
		printf("Ledmask: %d%d%d\n", ledStatus[0], ledStatus[1], ledStatus[2]);
		
		printfflush();
		
				
		if(quotient == 0){
			call Timer.stop();
		}
	}
}
