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
		
		printf("NODE%d is sending RTS to NODE%d\n", TOS_NODE_ID, BASE_STATION);
		
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
		
		printf("NODE%d is sending CTS to NODE%d\n", TOS_NODE_ID, current_sender);
		
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
		
		printf("NODE%d is sending DATA to NODE%d\n", TOS_NODE_ID, BASE_STATION);
		
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
	  		if(to_send == 0) { //no packet have to be send, thus generate a new sample from the poiss
	  			to_send = samplePoisson(); //return number of packet sent in X milliseconds
	  			
	  			call timerWait.startOneShot(X); //wait X milliseconds before retry
	  			
	  			printf("NODE%d sendingProcedure - no messagge to sent\n", TOS_NODE_ID);
	  		} else {
	  			time_to_send = X / to_send; //time after that is sent the first packet
	  			
	  			call timerSend.startPeriodic(time_to_send);
	  			
	  			printf("NODE%d sendingProcedure - message will be sent..\n", TOS_NODE_ID);
	  		}		
	  }
	  
	//starting timer
	event void AMControl.startDone(error_t error){
		if(error == SUCCESS) {
	  	 	printf("NODE%d Antenna succesfully started!\n\n", TOS_NODE_ID);  
			if(TOS_NODE_ID != BASE_STATION){
				sendingProcedure();		
			
			}else{
				printf("A BASE_STATION EXISTS\n\n");
			}
		
		}else {
	  	  	printf("NODE%d Failed to start antenna, retrying\n", TOS_NODE_ID);
		  	call AMControl.start();	  
		}
	}
	
	
	//timer send event
	event void timerSend.fired(){
		if (to_send != 0){
	  			post sendRTS();
	  				  	
	  	}else{
	  		sequential_data = 0;
	  		call timerSend.stop();
	  		sendingProcedure();	
	  	}
	}
	//timer wait event
	event void timerWait.fired(){
		sendingProcedure();
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
						printf("ack recived \n");
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
		
		//case 1: the incoming packet is a RST
		if (msg->type == RTS) {

			//log
			printf("Incoming transmission RTS \n");
			
			if(TOS_NODE_ID == BASE_STATION){
				
				// if the BS is available 
				if (phase == RTS) {
					printf("BS has received RTS \n");
					current_sender = call AMPacket.source( bufPtr );
					
					printf("BS is going in CTS mode \n");
					phase = CTS;
					
					printf("NODE%d has won the CTS \n", current_sender);
					post sendCTS();
				
				}else{
					printf("BS is BUSY \n");
				}
				
								
			}else{
				printf("NODE%d has received RTS and go in WAIT\n", TOS_NODE_ID);
				call timerWait.startOneShot(X);
			}
		}
		
		//case 2: the incoming packet is a CTS
		if(msg->type == CTS){
		
			printf("Incoming transmission CTS \n");
			
			if(TOS_NODE_ID == call AMPacket.destination( bufPtr )){
				printf("has received CTS from %d \n", call AMPacket.source( bufPtr ));
				printf("sending seq_data %d to %d \n", sequential_data, call AMPacket.source( bufPtr ));
				printf("passing to DATA mode\n");
				phase = DATA;
				post sendDATA();
				
			}else{
				printf("has received CTS and go in WAIT\n");
				call timerWait.startOneShot(X);
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
				printf("NODE%d has received DATA and go in WAIT\n", TOS_NODE_ID);
				call timerWait.startOneShot(X);
			}
		}
		


		return bufPtr;
	}
}


