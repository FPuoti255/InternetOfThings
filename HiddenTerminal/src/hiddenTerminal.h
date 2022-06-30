#ifndef HIDDENTERMINAL_H
#define HIDDENTERMINAL_H

#define NEW_PRINTF_SEMANTICS

#define BASE_STATION 2
#define RTS 0
#define CTS 1 
#define DATA 2
#define X 1000 // milliseconds == 1 sec 
#define LAMBDA 3 //this is the expected value of the poisson distribution 3 packets/secons



typedef nx_struct my_msg {
	nx_uint8_t type;
	nx_uint16_t data;
} my_msg_t;

enum{
AM_MY_MSG = 6,
};

#endif
