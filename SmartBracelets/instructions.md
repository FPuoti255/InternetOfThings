In order to properly run the simulation, execute the following steps in order:
- if you want to recompile our code, run `make micaz sim`
- check if the program `socat` is installed
- check if the library `pyserial` is installed in your python environment
- deploy the node-red export, using `sudo`, in order to set up the connections. It is important to deploy first the node-red server before of running the simulation.
- you can finally run `sudo python RunSimulation.py` in the src folder.

Notice that `sudo` is needed in order to work with serial sockets. It may happen to have some errors during socket configuration, just run the script a couple of times.