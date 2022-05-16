#include "sendAck.h"
#include "Timer.h"

#define X 6 // 5+1

module sendAckC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 

    interface Receive;
    interface AMSend;
    
    interface Timer<TMilli> as MilliTimer;
    
    interface SplitControl as AMControl;
    interface PacketAcknowledgements;
    interface Packet;

	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t>;
  }

} implementation {

  uint8_t counter = 0;
  uint8_t req_id = 0; //ack counter. If == X stop timer
  
  message_t packet;
  
  bool locked;
  
  void sendReq();
  void sendResp();
  
  
  //***************** Send request function ********************//
  void sendReq() {
	/* This function is called when we want to send a request
	 *
	 * STEPS:
	 * 1. Prepare the msg
	 * 2. Set the ACK flag for the message using the PacketAcknowledgements interface
	 *     (read the docs)
	 * 3. Send an UNICAST message to the correct node
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
  	counter++;
  	if(locked){
  		dbg("Mote1", "Locked antenna. exiting.. %hu.\n", counter);
  		return;
  	} else {
  		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
  		if (msg == NULL) {
			return;
	  	}
	  	msg->type = REQ;
	  	msg->counter = counter;
	  	
	  	if(call PacketAcknowledgements.requestAck(&packet) != SUCCESS){
	  		dbg("Mote1", "Cannot request acks for packet. exiting..%hu.\n", counter);
	  		return;
	  	}
	  	
		if (call AMSend.send(2, &packet, sizeof(my_msg_t)) == SUCCESS) {
			locked = TRUE;
		}
	}
 }        

  //****************** Task send response *****************//
  void sendResp() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raise the event read one.
  	 */
	call Read.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	// Starting the Antenna
	call AMControl.start();	
  }

  //***************** SplitControl interface ********************//
  event void AMControl.startDone(error_t err){
    if (err == SUCCESS) {
		dbg("Common", "Antenna succesfully started!\n");	  
		if(TOS_NODE_ID == 1){ //MOTE2 does not need the timer
			call MilliTimer.startPeriodic(1000);
		}      
	}else {
	  dbg("Common", "Failed to start the antenna, retrying..\n");
	  call AMControl.start();
	}
  }
  
  event void AMControl.stopDone(error_t err){
    /* Fill it ... */
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
  	sendReq();
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* bufPtr,error_t err) {
	/* This event is triggered when a message is sent 
	 *:186: syntax error at end of input
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer. The program is done
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	
	if (&packet == bufPtr) {
	  locked = FALSE;
	  
	  if(TOS_NODE_ID == 1){
	  	dbg("Mote1", "REQ sent, counter: %hu.\n", counter);
	  }else{
	  	dbg("Mote2", "RESP sent, counter: %hu.\n", counter);

	  }  
	  
	}else{
		dbg("Common", "Mote%d Error, request not sent. retrying..!", TOS_NODE_ID);
		return;
	}

	if(call PacketAcknowledgements.wasAcked(&packet)){
	
		if(TOS_NODE_ID == 1){
		  	req_id++;
			dbg("Mote1", "Ack number %hu received.\n", req_id);
		
			if(req_id == X){
				call MilliTimer.stop();				
				dbg("Mote1", "Timer stopped\n");
			}
		}else{
	  		dbg("Mote2", "RESP acked.\n");
	  	}  

	}
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* bufPtr,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	  
	 
	 if (len != sizeof(my_msg_t)) {
	 	dbg("Common", "Mote%d received packet of wrong length. exiting..\n", TOS_NODE_ID);
	    return bufPtr;
	 }else{	 
		my_msg_t* msg = (my_msg_t*)payload;
		
	 	if(TOS_NODE_ID == 1){
	 		dbg("Mote1", "Received  RESP for packet with counter %hu: value = %hu\n", msg->counter, msg->value);
	 		return bufPtr;	
	 		
	 	}else{
	 	
		 if (msg->type == REQ){
		 	dbg("Mote2", "Sending the response to request with counter = %hu.\n", msg->counter);
		 	counter = msg -> counter;
		 	sendResp(); 
		 	return bufPtr;
		 }	 	
	 	}
	 }	 

  }
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	/* This event is triggered when the fake sensor finish to read (after a Read.read()) 
	 *
	 * STEPS:
	 * 1. Prepare the response (RESP)
	 * 2. Send back (with a unicast message) the response
	 * X. Use debug statement showing what's happening (i.e. message fields)
	 */
	 
	my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
	if (msg == NULL) {
		return;
  	}
  	msg->type = RESP;
  	msg->counter = counter;
  	msg->value = data; 
  	
  	if(call PacketAcknowledgements.requestAck(&packet) != SUCCESS){
  		dbg("Mote2", "Cannot request acks for packet. exiting..\n");
  		return;
  	}
  	
	if (call AMSend.send(1, &packet, sizeof(my_msg_t)) == SUCCESS) {
		locked = TRUE;
	}	
	
   }

}


