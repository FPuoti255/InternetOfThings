#include <stdio.h>
generic module FakeSensorP() {

	provides interface Read<sensor_status>;
	uses interface Random;

}

implementation 
{

	task void readDone();

	//***************** Read interface ********************//
	command error_t Read.read(){
		post readDone();
		return SUCCESS;
	}

	//******************** Read Done **********************//
	task void readDone() {
	  
	  sensor_status status;

	  int random_number = (call Random.rand16() % 10);
		
		if (random_number <= 2){
		  strcpy(status.status, "STANDING");
		} else if (random_number <= 5){
		  strcpy(status.status, "WALKING");
		} else if (random_number <= 8){
		  strcpy(status.status, "RUNNING");
		} else {
		  strcpy(status.status, "FALLING");
		}
		
		signal Read.readDone( SUCCESS, status);
	  status.X = call Random.rand16();
	  status.Y = call Random.rand16();

	}
}  
