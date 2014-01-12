README for Blink
Author/Contact: tinyos-help@millennium.berkeley.edu

Description:

Blink is a simple application that blinks the 3 mote LEDs. It tests
that the boot sequence and millisecond timers are working properly.
The three LEDs blink at 1Hz, 2Hz, and 4Hz. Because each is driven by
an independent timer, visual inspection can determine whether there are
bugs in the timer system that are causing drift. Note that this 
method is different than RadioCountToLeds, which fires a single timer
at a steady rate and uses the bottom three bits of a counter to display
on the LEDs.

Tools:

Known bugs/limitations:

None.


$Id: README.txt,v 1.4 2006-12-12 18:22:48 vlahan Exp $

Breakfast notes:
----------------
* burn shows how to use the wpt (testbed) install target for a batch
  of nodes. See support/make/wpt.extra
* reset shows how to use direct access to the MIB.py testbed server script to 
  reset nodes on the testbed. See apps/breakfast/Sensorbed/version2
  for the server script.
* The map files show the format which burn and reset expect: basically
  just the second column matters.
