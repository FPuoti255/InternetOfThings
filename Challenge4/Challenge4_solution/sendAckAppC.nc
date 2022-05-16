#include "sendAck.h"

configuration sendAckAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, sendAckC as App;
  components new FakeSensorC();
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components new TimerMilliC();
  components ActiveMessageC;


/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;  
    
  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  
  //Timer interface
  App.MilliTimer -> TimerMilliC;
    
  //Interfaces to access package fields
  App.AMControl -> ActiveMessageC;
  App.PacketAcknowledgements -> AMSenderC.Acks;
  App.Packet -> AMSenderC;
  
  //Fake Sensor read
  App.Read -> FakeSensorC;

}

