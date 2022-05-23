#include "Timer.h"
#include "SmartBracelet.h"
#include <stdio.h>

module SmartBraceletC @safe() {
  uses {
    interface Boot;
    
    interface AMSend;
    interface Receive;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements;
    
    interface Timer<TMilli> as TimerPairing;
    interface Timer<TMilli> as TimerSensing;
    interface Timer<TMilli> as TimerMissing;
    
    interface Read<sensor_status> as FakeSensor;
  
  }
}

implementation {
  
  // Radio control
  bool busy = FALSE;
  uint16_t counter = 0;
  
  message_t packet;
  am_addr_t address_coupled_device;
  
  uint8_t attempt = 0;
  
  // Current phase
  uint8_t phase = 0;
  
  // Sensors
  bool sensors_read_completed = FALSE;
  
  sensor_status status;
  sensor_status last_status;
  
  




  void send_confirmation();
  void send_info_message();
  
  // Program start
  event void Boot.booted() {
    call AMControl.start();
  }

  // called when radio is ready
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg("Radio", "Radio device ready\n");
      dbg("Pairing", "Pairing phase started\n");
      
      // Start pairing phase
      call TimerPairing.startPeriodic(250);
    } else {
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) {}
  
 




  event void TimerPairing.fired() {
    counter++;
    dbg("TimerPairing", "TimerPairing: timer fired at time %s\n", sim_time_string());
    if (!busy) {
      sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = 0; // 0 for pairing phase
      sb_pairing_message->msg_id = counter;
      //The node ID is divided by 2 so every 2 nodes will be the same number (0/2=0 and 1/2=0)
      //we get the same key for every 2 nodes: parent and child
      strcpy(sb_pairing_message->data, RANDOM_KEY[TOS_NODE_ID/2]);
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sb_msg_t)) == SUCCESS) {
	      dbg("Radio", "Radio: sending pairing packet, key=%s\n", RANDOM_KEY[TOS_NODE_ID/2]);	
	      busy = TRUE;
      }
    }
  }
  
  event void TimerSensing.fired() {
    dbg("TimerSensing", "Sensing: timer fired at time %s\n", sim_time_string());
    call FakeSensor.read();
  }

  event void TimerMissing.fired() {
    dbg("TimerMissing", "TimerMissing: timer fired at time %s\n", sim_time_string());
    dbg("Info", "ALERT: MISSING\n");
    dbg("Info","Last known location: %hhu, Y: %hhu\n", last_status.X, last_status.Y);
  }


  
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr && error == SUCCESS) {
      dbg("Radio_sent", "Packet sent\n");
      busy = FALSE;
      
      if (phase == 1 && call PacketAcknowledgements.wasAcked(bufPtr) ){
        // Phase == 1 and ack received
        phase = 2; // Pairing phase 1 completed
        dbg("Radio_ack", "Pairing ack received at time %s\n", sim_time_string());
        dbg("Pairing","Pairing phase 1 completed for node: %hhu\n\n", address_coupled_device);
        
        // Start operational phase
        if (TOS_NODE_ID % 2 == 0){
          // Parent bracelet 
          dbg("OperationalMode","Parent bracelet\n");
          call TimerMissing.startOneShot(60000);
        } else {
          // Child bracelet
          dbg("OperationalMode","Child bracelet\n");
          call TimerSensing.startPeriodic(10000);
        }
      
      } else if (phase == 1){
        // Phase == 1 but ack not received
        dbg("Radio_ack", "Pairing ack not received at time %s\n", sim_time_string());
        send_confirmation(); // Send confirmation again
      
      } else if (phase == 2 && call PacketAcknowledgements.wasAcked(bufPtr)){
        // Phase == 2 and ack received
        dbg("Radio_ack", "INFO ack received at time %s\n", sim_time_string());
        attempt = 0;
        
      } else if (phase == 2){
        // Phase == 2 and ack not received
        dbg("Radio_ack", "INFO ack not received at time %s\n", sim_time_string());
        send_info_message();
      }
        
    }
  }
  

   
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    sb_msg_t* mess = (sb_msg_t*)payload;
    // Print data of the received packet
	  dbg("Radio_rec","Message received from node %hhu at time %s\n", call AMPacket.source( bufPtr ), sim_time_string());
	  dbg("Radio_pack","Payload: type: %hu, msg_id: %hhu, data: %s\n", mess->msg_type, mess->msg_id, mess->data);
    
    if (call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR && phase == 0 && strcmp(mess->data, RANDOM_KEY[TOS_NODE_ID/2]) == 0){
      // controlla che sia un broadcast e che siamo nella fase di pairing phase == 0
      // e che la chiave corrisponda a quella di questo dispositivo
      
      address_coupled_device = call AMPacket.source( bufPtr );
      phase = 1; // 1 for confirmation of pairing phase
      dbg("Radio_pack","Message for pairing phase 0 received. Address: %hhu\n", address_coupled_device);
      send_confirmation();
    
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == 1) {
      // Enters if the packet is for this destination and if the msg_type == 1
      dbg("Radio_pack","Message for pairing phase 1 received\n");
      call TimerPairing.stop();
      
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == 2) {
      // Enters if the packet is for this destination and if msg_type == 2
      dbg("Radio_pack","INFO message received\n");
      dbg("Info", "Position X: %hhu, Y: %hhu\n", mess->X, mess->Y);
      dbg("Info", "Sensor status: %s\n", mess->data);
      last_status.X = mess->X;
      last_status.Y = mess->Y;
      call TimerMissing.startOneShot(60000);
     
      if (strcmp(mess->data, "FALLING") == 0){
        dbg("Info", "ALARM: FALLING!\n");
      }
    }
    return bufPtr;
  }


  event void FakeSensor.readDone(error_t result, sensor_status status_local) {
    status = status_local;
    dbg("Sensors", "Sensor status: %s\n", status.status);
    // Controlla che entrambe le letture siano state fatte
    if (sensors_read_completed == FALSE){
      
      sensors_read_completed = TRUE;
    } else {
      sensors_read_completed = FALSE;
      send_info_message();
    }

	dbg("Sensors", "Position X: %hhu, Y: %hhu\n", status_local.X, status_local.Y);
    // Controlla che entrambe le letture siano state fatte
    if (sensors_read_completed == FALSE){
      // Solo una lettura è stata fatta
      sensors_read_completed = TRUE;
    } else {
      // Entrambe le letture sono state fatte quindi possiamo inviare l'INFO packet
      sensors_read_completed = FALSE;
      send_info_message();
    }
  }







  // Send confirmation in phase 1
  void send_confirmation(){
    counter++;
    if (!busy) {
      sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = 1; // 1 for confirmation of pairing phase
      sb_pairing_message->msg_id = counter;
      
      strcpy(sb_pairing_message->data, RANDOM_KEY[TOS_NODE_ID/2]);
      
      // Require ack
      call PacketAcknowledgements.requestAck( &packet );
      
      if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
        dbg("Radio", "Radio: sanding pairing confirmation to node %hhu\n", address_coupled_device);	
        busy = TRUE;
      }
    }
  }
  
  // Send INFO message from child's bracelet
  void send_info_message(){
    
 
    if (attempt < 3){
      counter++;
      if (!busy) {
        sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
        
        // Fill payload
        sb_pairing_message->msg_type = 2; // 2 for INFO packet
        sb_pairing_message->msg_id = counter;
        
        sb_pairing_message->X = status.X;
        sb_pairing_message->Y = status.Y;
        strcpy(sb_pairing_message->data, status.status);
        
        // Require ack
        attempt++;
        call PacketAcknowledgements.requestAck( &packet );
        
        if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
          dbg("Radio", "Radio: sanding INFO packet to node %hhu, attempt: %d\n", address_coupled_device, attempt);	
          busy = TRUE;
        }
      }
    } else {
      attempt = 0;
    }
  }
  
}




