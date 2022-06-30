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
		
		printf("Sending RTS to the Base Station(%d)\n", BASE_STATION);
		
		ackListener = TRUE;

		//request an explicit ack for this transmission
		call PacketAcknowledgements.requestAck(&packet);

		//transmit
		if (call AMSend.send(BASE_STATION, &packet, sizeof(my_msg_t)) == SUCCESS) {
		
			//transmission done
			printf("RTS - Transmission OK \n");
			//printf("RTS - Type: %u \n", msg->type);
			
		}else{
			//transmission error
			//do nothing  
			;
		}
	}
	
	task void sendCTS() {

		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		

		msg->type = CTS;
		
		printf("Sending CTS to NODE%d\n", current_sender);
		
		ackListener = TRUE;

		//request an explicit ack for this transmission
		call PacketAcknowledgements.requestAck(&packet);

		//transmit
		if (call AMSend.send(current_sender, &packet, sizeof(my_msg_t)) == SUCCESS) {
		
			//transmission done
			printf("CTS - Transmission OK \n");
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
	  		if(to_send == 0) { //no packet have to be sent, thus generate a new sample from the poiss
	  			to_send = samplePoisson();
  			} //return number of packet sent in X milliseconds
	  		
	  		if(to_send != 0){
	  			time_to_send = X / to_send; //time after that is sent the first packet
	  			
	  			call timerSend.startPeriodic(time_to_send);
	  			
	  			printf("SendingProcedure - %d messages to send\n", to_send);
	  		} else {
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
		if (phase == RTS){
			printf("TimerWait elapsed. Re-starting the sending procedure.\n");
			phase = RTS;
			sendingProcedure();		
		}else{
			printf("An error occurred. TimerWait elapsed while in phase: %d.\n", phase);
		}
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
						printf("ack received \n");
					}				

					//deactivate ack listener
					ackListener = FALSE;

				}else{
				
					printf("ack was not received \n");
					
					if(TOS_NODE_ID != BASE_STATION){
						if(phase == DATA){
							printf("RETRY to send DATA \n");
							post sendDATA();
						
						}else{
							printf("RETRY to send RTS \n");
							post sendRTS();
						}
					}else{
						//if i'm the BS
						if(phase == CTS){
							printf("NOT ACK CTS back to RTS \n"); 
							phase = RTS;
						}else{
							//ramain in RTS	
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
		
		//case 1: the incoming packet is a RTS
		if (msg->type == RTS) {
			
			if(TOS_NODE_ID == BASE_STATION){
				printf("Incoming transmission RTS \n");
				
				// if the BS is available 
				if (phase == RTS) {
					printf("BS has received RTS \n");
					current_sender = call AMPacket.source( bufPtr );
					
					printf("BS is going in CTS mode \n");
					phase = CTS;
					
					printf("NODE%d has won the CTS \n", current_sender);
					post sendCTS();
				
				}else{
					printf("Base Station BUSY \n");
				}
				
								
			}else{
				if(phase == RTS){
					printf("RTS detected: WAIT_PHASE\n");
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
		
			
			if(TOS_NODE_ID == call AMPacket.destination( bufPtr )){
				printf("CTS from base station (%d) received \n", call AMPacket.source( bufPtr ));
				printf("passing to DATA mode\n");
				phase = DATA;
				post sendDATA();
				
			}else{
				if(phase == RTS){
					printf("CTS for another node detected: WAIT_PHASE\n");
					phase = WAIT_PHASE;
					call timerSend.stop();
					call timerWait.startOneShot(X);				
				}else{
					printf("Some error at the BS occured. It's impossible to have two CTS recipient simoultaneously\n");
				}		
			}
			
		}
		
		//case 3: the incoming packet is a DATA
		if (msg->type == DATA) {

			printf("Incoming transmission DATA \n");
			
			if(TOS_NODE_ID == BASE_STATION){
				printf("BS has received DATA from %d \n", call AMPacket.source( bufPtr ));
				printf("Incoming seq_data = %d \n", msg-> data);
				
				printf("BS is coming back to RTS mode \n");
				phase = RTS;
								
			}else{
				if(phase == RTS){
					printf("DATA packet of another node detected: WAIT_PHASE\n");
					phase = WAIT_PHASE;
					call timerSend.stop();
					call timerWait.startOneShot(X);				
				}else{
					printf("Some error at the BS occured. It's impossible to have DATA of another mote if I'm in CTS\n");
				}
				//printf("NODE%d has received DATA and go in WAIT_PHASE\n", TOS_NODE_ID);
				//call timerWait.startOneShot(X);
			}
		}

		return bufPtr;
	}
}


