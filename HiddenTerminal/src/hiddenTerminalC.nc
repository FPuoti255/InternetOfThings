#include "hiddenTerminal.h"
#include "Timer.h"
#include "math.h"
#include "printf.h"

module hiddenTerminalC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 

   interface Receive;
   interface AMSend;
   interface Packet;
   interface AMPacket;
    
   interface Timer<TMilli> as timerSend;
   interface Timer<TMilli> as timerWait;
   interface Timer<TMilli> as timeoutCTS;
    
   interface SplitControl as AMControl;
   interface PacketAcknowledgements;
    
   interface Random;
  }

} implementation {
	
	uint8_t phase = RTS;

	bool ackListener = FALSE;

	uint8_t current_sender = 0; // node that is currently allowed to send data due to RTS/CTS procedure

	uint8_t sequential_data = 0;
	uint8_t to_send = 0;
	uint32_t time_to_send = 0;
		
	message_t packet;

	bool locked;
	
	//used for statistical stuff
	int total[NODES] = {0};	
	int success[NODES] = {0};
	int s;


  
  //***************** POISSON ********************//		
	uint8_t samplePoisson() {
  
		double L = exp(-LAMBDA);
		double p = 1.0;
		uint8_t k = 0;
		  	
		do{
		  	k = k+1;
		  	p = p * (call Random.rand16() / (pow(2,16) - 1));  	
		}while(p > L);
		  	
		return k - 1;
	 }
	 	
	/************************ BOOT **********************/
	
	event void Boot.booted(){
		dbg("boot","Application booted.\n\n");
		//starting radio
		call AMControl.start();
	}
	
	/************************ TASK ***********************************/
	
	task void sendRTS() {

		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		
		msg->type = RTS;
		msg->dst = BASE_STATION;
		
		printf("Sending RTS\n");
		

		//transmit
		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
		
			//transmission done
			printf("RTS - Transmission OK \n");
			
		}else{
			//transmission error
			//do nothing  
			;
		}
	}
	
	task void sendCTS() {

		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		

		msg->type = CTS;
		msg->dst = current_sender;
		
		printf("Sending CTS to NODE%d\n", current_sender);

		//transmit
		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
		
			//transmission done
			printf("CTS - Transmission OK \n");
			call timeoutCTS.startOneShot(3*X);
			//printf("CTS - Type: %u \n", msg->type);
			
		}else{
			//transmission error
			//do nothing
			;
		}
	}
	
	task void sendDATA() {

		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		
		msg->type = DATA;
		msg->data = sequential_data;
		
		printf("Sending DATA = %d to the Base Station(%d)\n", sequential_data, BASE_STATION);
		
		ackListener = TRUE;

		//request an explicit ack for this transmission
		call PacketAcknowledgements.requestAck(&packet);

		//transmit
		if (call AMSend.send(BASE_STATION, &packet, sizeof(my_msg_t)) == SUCCESS) {
		
			//transmission done
			printf("DATA - Transmission OK \n");
			//printf("DATA - Type: %u \n", msg->type);
			
		}else{
			//transmission error
			//do nothing  
			;
		}
	}
	
	/****************************** TIMERS *******************************/
	void sendingProcedure(){
	  		if(to_send == 0) { 
	  			to_send = samplePoisson();
  			} //return number of packet sent in X milliseconds
	  		
	  		if(to_send != 0){
	  			time_to_send = X / to_send; //time after that is sent the first packet
	  			
	  			call timerSend.startPeriodic(time_to_send);
	  			
	  			printf("SendingProcedure - %d messages to send\n", to_send);
	  		} else {
	  			phase = WAIT_PHASE;
	  			call timerWait.startOneShot(X); //wait X milliseconds before retry	  			
	  			printf("SendingProcedure - no message to send\n");	  			
	  		}		
	  }
	  
	//starting timer
	event void AMControl.startDone(error_t error){
		if(error == SUCCESS) {
	  	 	printf("Antenna succesfully started!\n");  
			if(TOS_NODE_ID != BASE_STATION){
				sendingProcedure();		
			
			}else{
				printf("BASE_STATION STARTED. ID = %d \n", BASE_STATION);
			}
		
		}else {
	  	  	printf("Failed to start antenna, retrying\n");
		  	call AMControl.start();	  
		}
	}
	
	
	//timer send event
	event void timerSend.fired(){
		if(phase != WAIT_PHASE){
			if (to_send != 0){
		  		post sendRTS();
		  				  	
		  	}else{
		  		sequential_data = 0;
		  		call timerSend.stop();
		  		sendingProcedure();	
		  	}		
		}else{
			printf("An error occurred. TimerSend elapsed while in WAIT_PHASE.\n");
		}
	}
	//timer wait event
	event void timerWait.fired(){
		if (phase == WAIT_PHASE){
			printf("TimerWait elapsed. Re-starting the sending procedure.\n");
			phase = RTS;
			sendingProcedure();		
		}else{
			printf("An error occurred. TimerWait elapsed while in phase: %d.\n", phase);
		}
	}
	
	//timer timeoutCTS event
	event void timeoutCTS.fired(){
		uint8_t lost = 0;
		float per = 0.0;
		//char fractional_part[10];
		uint16_t fractional = 0;
		
		printf("Data not received by the CTS node. Returning to RTS\n");
		phase = RTS;
		
		//update statistics
		s = current_sender - 2 ;
	
		total[s] = total[s] + 2;
		success[s] = success[s] + 1;
		
		lost = total[s] - success[s];
		
		per = (float)((float)lost / (float)total[s]);
		
		fractional = (int) ( (per - (int) per) * 1000);
		printf("node: %d tot: %d succ: %d PER: %d.%u %\n", s+2, total[s], success[s], (int)per, fractional);
		
	}
	
	
	
	/************************** EVENTS *******************************/
	

	event void AMControl.stopDone(error_t error){
		;
	}
	
	event void AMSend.sendDone(message_t *msg, error_t error){
		if(&packet == msg && error == SUCCESS) {
	
			if(ackListener){

				//acknowledgement received
				if(call PacketAcknowledgements.wasAcked(msg)) {
					
					if(phase == DATA){
						printf("data acked \n");
						
						sequential_data++;
						printf("next data: %d \n", sequential_data);
						
						to_send--;
						printf("remaing packets: %d \n", to_send);						
						
						printf("return to RTS mode \n");
						phase = RTS;
					
					}else{
						printf("Error: ack received and not in Data phase!\n"); //do nothing, impossible situation
					}				

					//deactivate ack listener
					ackListener = FALSE;

				}else{
								
					if(TOS_NODE_ID != BASE_STATION){
						if(phase == DATA){
							printf("Ack for DATA packet not received. RETRY to send DATA \n");
							post sendDATA();
						}						
					}
				}
			}
		}
	}
	
	//transmission incoming event
	event message_t * Receive.receive(message_t* bufPtr, void* payload, uint8_t len){
	
		
		//pairing ack - datagram instantiation
		my_msg_t* msg = (my_msg_t*)payload;
		
		uint8_t destination = msg->dst;
		
		
		//case 1: the incoming packet is a RTS
		if (msg->type == RTS) {
			
			if(TOS_NODE_ID == BASE_STATION && destination == BASE_STATION){
				
				
				printf("Incoming transmission RTS \n");
				
				//RTS recived successful +1 and total +1
				s = call AMPacket.source( bufPtr ) - 2;
				
				total[s]++;
				success[s]++;
				
				// if the BS is available 
				if (phase == RTS) {
					current_sender = call AMPacket.source( bufPtr );
					printf("BS has received RTS from NODE%d. Going in CTS mode.\n", current_sender);
					phase = CTS;					
					post sendCTS();				
				}else{
					printf("Base Station BUSY. Phase == %d\n", phase);
				}
				
								
			}else{
				if(phase == RTS){
					printf("RTS detected (sender:%d) WAIT_PHASE\n", call AMPacket.source( bufPtr ));
					phase = WAIT_PHASE;
					call timerSend.stop();
					call timerWait.startOneShot(X);				
				}else{
					;
				}
			}
		}
		
		//case 2: the incoming packet is a CTS
		if(msg->type == CTS){
		
			
			if(TOS_NODE_ID == destination){
				printf("CTS from base station (%d) received \n", call AMPacket.source( bufPtr ));
				printf("passing to DATA mode\n");
				call timerWait.stop(); //it is possible that the CTS has been granted even if I entered the WAIT_PHASE (according to packets concurrency to the Base station) thus I need to stop the timer wait because the transmission can start
				phase = DATA;
				post sendDATA();
				
			}else{
				if(phase == RTS){
					printf("CTS for another node detected (true destination:%d) WAIT_PHASE\n", destination);
					phase = WAIT_PHASE;
					call timerSend.stop();
					call timerWait.startOneShot(X);				
				}else if (phase == CTS || phase == DATA){
					printf("Some error at the BS occured. It's impossible to have two CTS recipient simoultaneously\n");
				}else{
					; //do nothing, already in wait phase
				}		
			}
			
		}
		
		//case 3: the incoming packet is a DATA
		if (msg->type == DATA) {

			
			if(TOS_NODE_ID == BASE_STATION){
			
			
				if( call AMPacket.source( bufPtr ) == current_sender){				
					printf("BS has received DATA from %d \n", call AMPacket.source( bufPtr ));
					printf("Incoming seq_data = %d \n", msg-> data);
					printf("BS is coming back to RTS mode \n");
					call timeoutCTS.stop();
					phase = RTS;
					
					//update statistics
					s = current_sender -2 ;
					
					total[s] = total[s] + 2;
					success[s] = success[s] + 2;
				
				}else{
					printf("Error: data packet from a non-CTS node arrived\n");
				}
								
			}
		}

		return bufPtr;
	}
}


