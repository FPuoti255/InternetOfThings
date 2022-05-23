# Smart Bracelet Report

Description of the software for Smart Bracelet, based on TinyOS.

### ASSUMPTIONS

We considered all the specifications written in the projectDescription file. The random-keys are pre-loaded at the start from the [SmartBracelet.h](./src/SmartBracelet.h).
Two bracelet can be paired if keyP and keyC are the same for both. Since the division in NescC rounds to the smaller integer number, we used the division by 2 in order to choose the right key for each couple (parent, child): the nodes with even id represent the parents, the nodes with odd id represent the children. Just two pre-loaded keys were added just to spawn two couples of motes, but adding more keys it is possible to add more couple of motes.

### DATA STRUCTURES (DATAGRAMS)

We used two data structures:
- sb_msg:
    it is the data structure used to define the structure of a message. Noteworthy are the fields data, which carries the pairing-key, and msg_type.\
    The msg_type will be :
    - 0 for a pairing message
    - 1 for a paring-confirmation message
    - 2 for an INFO message
- sensor status:
    used to return the FakeSensor read, if completed. The status field can be (STANDING | WALKING | RUNNING | FALLING)
------------------------------------------------------------------





We assume 3 types of datagram with a relative code:
BROADCAST (0), UNICAST (1), INFO (2).
The INFO datagram sent by the child, can have 4 different status:
STANDING (10), WALKING (20), RUNNING (30), FALLING (40).
The datagram for pairing (sent in broadcast) has the following structure:
type key address identifier
The acknoledgment datagram (sent after pairing datagram reception) has the following
structure:
type acknowledgment
The information datagram has the following structure:

### CONSTANTS

We designed our code making all the following constants to be scalable
· C_MAX : max number of bracelet supported couples [set to 4 couples]
· K_LEN : key length [set to 20 byte]
· T_1: pairing interval [set to 15000 ms]
· T_2: info transmission interval [set to 10000 ms]
· T_3: alert interval [set to 60000 ms]

### ALARMS

Every alarm message has a format as follow:
!MISSING ALARM! received from child | Address: 2 | PosX: 43847 / PosY: 49971
!FALLING ALARM! received from child | Address: 4 | PosX: 42989 / PosY: 58694
We implemented a LED notification mechanism that informs the owner of a bracelet on the
system situation.
[led interface] 0 => RED : FALLING MESSAGE RECEIVED
[led interface] 1 => GREEN : INFO MESSAGE RECEIVED
[led interface] 2 => BLUE : BRACELET IS PAIRED WITH ITS ASSOCIATE
[led interface] 0 1 2 => R G B : MISSING ALARM RECEIVED
This could happen only in a parent’s bracelet, to notify the effective missing status of a child.

### PAIRING

Here we can see the pairing process in a Cooja simulation; in this phase all the messages
are in broadcast, and every couple of bracelets is waiting for a correct partner message.
In the center we can see the LED status (BLUE + BLUE stand for ‘PAIRED’):

# SIMULATION

By running the python file, the user can choose if

1. run and display the simulation on the terminal
2. run and save the simulation in a log file
3. run the simulation with a serial forwarder for Node-Red

### LOG (from TOSSIM)

Every simulation with TOSSIM creates a file named simulation.txt

### NODE RED

If is used the serial port forwarder, every message is sent via socket to Node Red.
Node Red is configured to filter and show messages only of a specific type (alarms).
The message, when received, is shown on the debug section of node-red web gui.

### SOURCE CODE

All the file generated for the project can be found at the following github repository:
[https://github.com/FPuoti255/InternetOfThings](https://github.com/FPuoti255/InternetOfThings)

### Are attached

● The source code \
● The logs \
● Some screenshots \
● A simulation video 