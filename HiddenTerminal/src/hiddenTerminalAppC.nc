#include "hiddenTerminal.h"
#include "printf.h"




configuration hiddenTerminalAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, hiddenTerminalC as App;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  
  components new TimerMilliC() as TimerSend;
  components new TimerMilliC() as TimerWait;
  
  components ActiveMessageC;
  components RandomC;
  
  components SerialPrintfC;
  components SerialStartC;

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;  
    
  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  
  
  //Timer interface
  App.timerSend -> TimerSend;
  App.timerWait -> TimerWait;
    
  //Interfaces to access package fields
  App.AMControl -> ActiveMessageC;
  App.PacketAcknowledgements -> AMSenderC.Acks;
  App.PacketAcknowledgements -> ActiveMessageC;
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.Random -> RandomC.Random;
  
}

