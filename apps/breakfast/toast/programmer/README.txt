Software download:
http://cs.jhu.edu/~carlson/download/programmer.zip

Tested/verified on Ubuntu linux 10/11.

Requires Python 2.6 or 2.7.

Usage:

1. Plug programmer board into PC via USB cable
2. Press cable down firmly onto programming contacts on Toast board
   (J2)
3. Run this command:
   ./programAll.sh

4. Watch the output:
  - If you see this error, please DO NOT PROGRAM ANY MORE BOARDS until
    you've checked with JHU about how to proceed:

      Detected python 2.7
      Using password file: bin/password.ihex
      Programming with binary: bin/asb.ihex
      Programming device at /dev/ttyUSB0
      MSP430 Bootstrap Loader Version: 2.0
      Number of mass erase cycles set to 1.
      Invoking BSL...
      Transmit password ...
  
      An error occoured:
      NAK received (wrong password?)
      FAILED: Please check connections and retry.
    
    This indicates that the factory-standard reprogramming password
    was not accepted. It's possible that providing an invalid password
    can erase the calibration memory of the board, and this should be
    avoided! 

   - If it worked correctly, you should see red/yellow LEDS flash on
     the programmer board, and output like this:

       Detected python 2.7
       Using password file: bin/password.ihex
       Programming with binary: bin/asb.ihex
       Programming device at /dev/ttyUSB0
       MSP430 Bootstrap Loader Version: 2.0
       Number of mass erase cycles set to 1.
       Invoking BSL...
       Transmit password ...
       Autodetect failed! Unknown ID: f249. Trying to continue anyway.
       Current bootstrap loader version: 2.2 (Device ID: f249)
       Program ...
       11980 bytes programmed.
       Reset device ...
       OK!

    The process takes about 20 seconds per Toast board. If multiple
    devices are plugged in it will program them one at a time.


  - This output indicates a possible conenction error: 

      Detected python 2.7
      Using password file: bin/password.ihex
      Programming with binary: bin/asb.ihex
      Programming device at /dev/ttyUSB0
      MSP430 Bootstrap Loader Version: 2.0
      Number of mass erase cycles set to 1.
      Invoking BSL...
      Transmit password ...
    
      An error occoured:
      Bootstrap loader synchronization error
      FAILED: Please check connections and retry.
   
    Check the connections and retry.


Wiring notes:
Socket numbering on TAG-Connect cable:

+---------^----------+
|1  3  5  7  9  11 13|
|2  4  6  8  10 12 14|
+--------------------+

FTDI Pin   TAG-Connect Socket
TXD        6
DTR        11
RTS        7
VCCIO      2
RXD        8
RI         NC
GND        9
DSR        NC
DCD        NC
