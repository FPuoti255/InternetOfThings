#include "SmartBracelet.h"

configuration SmartBraceletAppC {}

implementation {
  components MainC, SmartBraceletC as App;
  
  components new AMSenderC(AM_RADIO_TYPE);
  components new AMReceiverC(AM_RADIO_TYPE);
  components ActiveMessageC as RadioAM;
  
  components new TimerMilliC() as TimerPairing;
  components new TimerMilliC() as TimerSensing;
  components new TimerMilliC() as TimerMissing;

  components new FakeSensorC();
 
  
  // Boot interface
  App.Boot -> MainC.Boot;
  
  // Radio interface
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.AMControl -> RadioAM;
  
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.PacketAcknowledgements -> RadioAM;

  // Timers
  App.TimerPairing -> TimerPairing;
  App.TimerSensing -> TimerSensing;
  App.TimerMissing -> TimerMissing;
  

  App.FakeSensor -> FakeSensorC;
  
  
}


