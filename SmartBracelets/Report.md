# Smart Bracelet Report

Description of the software for Smart Bracelet, based on TinyOS.

### ASSUMPTIONS

We considered all the specifications written in the projectDescription file. The random-keys are pre-loaded at the start from the [SmartBracelet.h](./src/SmartBracelet.h).
Two bracelet can be paired if keyP and keyC are the same for both. Since the division in NescC rounds to the smaller integer number, we used the division by 2 in order to choose the right key for each couple (parent, child): the nodes with even id represent the parents, the nodes with odd id represent the children. Just two pre-loaded keys were added just to spawn two couples of motes, but adding more keys it is possible to add more couple of motes.

### DATA STRUCTURES (DATAGRAMS)

We used two data structures:
- **sb_msg**:
    it is the data structure used to define the structure of a message sent by motes (as req/resp). Noteworthy are the fields data, which carries the pairing-key, and msg_type.\
    The msg_type will be :
    - 0 for a pairing message
    - 1 for a paring-confirmation message
    - 2 for an INFO message \
    Then the fields status, X and Y are filled with the value returned by a read of the fake sensor.
- **sensorStatus**:
    used to return the FakeSensor read, if completed. The status field can be (STANDING | WALKING | RUNNING | FALLING)


### ALARMS

By requirements, we have to types of alarms:
- "ALARM: MISSING", thrown when the TimerMissing fires since no message has been exchanged among a couple of motes. The timer has an expiring time of MAX_MISSING_TIME = 60000[ms]
- "ALARM: FALLING!", sent by the child bracelet to the parent one when the fake sensor returns that state. The fake sensor is sensed every SENSING_TIME = 10000[ms] \

Notice: The constants MAX_MISSING_TIME and SENSING_TIME are defined in the file [SmartBracelet.h](./src/SmartBracelet.h).

### SIMULATION: TOSSIM-LOGS-NODERED

The TOSSIM simulation runs for 12000 steps (see the [RunSimulation.py](src/RunSimulation.py) script), writing all the logs on the [simulation.txt](src/simulation.txt) file.
At the end of the simulation, using the pyserial library, the logs containing "ALARM" are sent to node-red. The messages, when received, are then accessible in the debug session of the web gui.
