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
		uint8_t phase = RTS; //describes what message is expected to be sent/recived
		
		uint8_t current_sender = 0; //node that is currently allowed to send data due to RTS/CTS procedure
  
		uint8_t sequential_data = 0; 
		
		uint8_t to_send = 0; //how many packet have to be sent
		
		uint32_t time_to_send = 0;

		message_t packet;

		bool locked;
		
		//***************** Poisson ********************//		
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
	 	
	 	
	  //***************** Boot interface ********************//
	  event void Boot.booted() {
			dbg("boot","Application booted.\n\n");
			// Starting the Antenna
			call AMControl.start();	
	  }
	  
		//***************** SplitControl interface ********************//
	  event void AMControl.startDone(error_t err){
			if (err == SUCCESS) {
	  	 	   printf("NODE%d Antenna succesfully started!\n\n", TOS_NODE_ID);  
				if(TOS_NODE_ID != BASE_STATION){
					sendingProcedure();		
				}else{
					printf("A BASE_STATION EXISTS\n\n");
				}     
			}else {
	  	  		printf("NODE%d Failed to start antenna, retrying\n\n", TOS_NODE_ID);
		  		call AMControl.start();	  
		 	}
	  }
	  
	  event void AMControl.stopDone(error_t err){
	  }
	  
	  //***************** MilliTimer interface ********************//
	  event void timerSend.fired() {
	  		if (to_send != 0){
	  			to_send = to_send - 1;
	  			sendRTS();
	  		}else{
	  			call timerSend.stop();
	  			sendingProcedure();
	  		}
	  }
	  
	  event void timerWait.fired() {
	  		sendingProcedure();
	  }
		
	
	  void sendingProcedure(){
	  		if(to_send == 0) { //no packet have to be send, thus generate a new sample from the poiss
	  			to_send = samplePoisson(); //return number of packet sent in X milliseconds
	  			call timerWait.startOneShot(X); //wait X milliseconds before retry
	  			printf("NODE%d sendingProcedure - no messagge to sent\n\n", TOS_NODE_ID);
	  		} else {
	  			time_to_send = X / to_send; //time after that is sent the first packet
	  			call timerSend.startPeriodic(time_to_send);
	  			printf("NODE%d sendingProcedure - message will be sent..\n\n", TOS_NODE_ID);
	  		}		
	  }
	  
	  
	  //***************** Send request function ********************//
	  void sendRTS(){
	  		if(locked){
	  			printf("NODE%d sendRTS - Locked antenna. exiting..\n\n", TOS_NODE_ID);
	  			return;
	  		} else {
	  			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
  				
  				if (msg == NULL) {
					return;
				}
				
				msg->type = RTS;
	  			
	  			if(call PacketAcknowledgements.requestAck(&packet) != SUCCESS){
	  	    		printf("NODE%d sendRTS - Cannot request acks for packet. exiting..\n\n", TOS_NODE_ID);
	  				return;
	  			}
	  			
	  			if (call AMSend.send(BASE_STATION, &packet, sizeof(my_msg_t)) == SUCCESS) {
					printf("NODE%d Sending RTS\n\n", TOS_NODE_ID);
					locked = TRUE;
				}
			}
	  	}
	  	
	  	void sendCTS(){
	  		if(locked){
	  			printf("NODE%d sendCTS - Locked antenna. exiting..\n\n", TOS_NODE_ID);
	  			return;
	  		} else {
	  			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
  				
  				if (msg == NULL) {
					return;
				}
				
				msg->type = CTS;
	  			
	  			if(call PacketAcknowledgements.requestAck(&packet) != SUCCESS){
	  	    		printf("NODE%d sendCTS - Cannot request acks for packet. exiting..\n\n", TOS_NODE_ID);
	  	    		phase = RTS;
	  				return;
	  			}
	  			
	  			if (call AMSend.send(current_sender, &packet, sizeof(my_msg_t)) == SUCCESS) {
					printf("NODE%d Sending CTS to node: %d\n\n", TOS_NODE_ID, current_sender);
					locked = TRUE;
				}
			}
	  	}
	  	
	  	void sendData(){
	  		if(locked){
	  			printf("NODE%d sendData - Locked antenna. exiting..\n\n", TOS_NODE_ID);
	  			return;
	  		} else {
	  			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
  				
  				if (msg == NULL) {
					return;
				}
				
				msg->type = DATA;
				msg->data = sequential_data;
	  			
	  			if(call PacketAcknowledgements.requestAck(&packet) != SUCCESS){
	  	    		printf("NODE%d sendData - Cannot request acks for packet. exiting..\n\n", TOS_NODE_ID);
	  				return;
	  			}
	  			
	  			if (call AMSend.send(BASE_STATION, &packet, sizeof(my_msg_t)) == SUCCESS) {
					printf("NODE%d Sending Data to node: %d\n\n", TOS_NODE_ID, current_sender);
					locked = TRUE;
				}
			}
	  	}
	  	
	  	//********************* AMSend interface ****************//
	  event void AMSend.sendDone(message_t* bufPtr,error_t err) {	
		if (&packet == bufPtr) {
		  printf("packet_sent\n\n");	  
		  locked = FALSE;	  
		}else{	
	  	   printf("NODE%d Error. Request not sent\n\n", TOS_NODE_ID);
			return;
		}
		
		if( ! (call PacketAcknowledgements.wasAcked(&packet)) ){
			printf("NODE%d Error, packet not acked. retrying..!\n\n", TOS_NODE_ID);

			//Retry to send all the packets if they was not acked
			if(phase == CTS && TOS_NODE_ID == current_sender){
				sendData();
			}else if(phase == CTS && TOS_NODE_ID == BASE_STATION){
				phase = RTS;
				printf("Returning to RTS phase\n\n");
			}
		
			
		  }
	  }
	  	
	  	//***************************** Receive interface *****************//
	  	event message_t* Receive.receive(message_t* bufPtr,void* payload, uint8_t len) {
	  		if (len != sizeof(my_msg_t)) {
	 			printf("NODE%d received packet of wrong length. exiting..\n", TOS_NODE_ID);
	    		return bufPtr;
	 		} else {
	 			my_msg_t* msg = (my_msg_t*)payload;
	 			
	 			if(TOS_NODE_ID == BASE_STATION){
	 				if(msg->type == RTS && phase == RTS){
	 					printf("NODE%d BS has received RTS during RTS phase\n", TOS_NODE_ID);
	 					current_sender =  call AMPacket.source( bufPtr );
						phase = CTS;
						sendCTS();
	 				}else if (msg -> type == DATA && call AMPacket.source(bufPtr) == current_sender){
	 					phase = RTS;
						printf("BASE_STATION has recived DATA, exit from CTS\n\n");
						current_sender = 0;
						sequential_data++;						
	 				}
	 				
	 			}else{ // im not the BS
	 				if(msg->type == CTS && call AMPacket.destination( bufPtr ) == TOS_NODE_ID){ //my cts
	 					printf("NODE%d received CTS\n\n", TOS_NODE_ID);
	 					sendData();	
	 				}else{ //wait X milliseconds
	 					call timerWait.startOneShot(X);	 						
	 				}
	 			}
	 		}
	  	}
	  	
		  
}
