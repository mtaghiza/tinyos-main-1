usage: ./bin/logic-cli <timeout> <output file>

This samples at 4 MHz for a fixed period, logging the output to file.

Each line in the output is formatted like:
ticks value

where ticks is the number of 4MHz ticks since the first sample was
recorded, and value is the 8-bit value in hex (input 0 is the LSB). 

The python script convert.py will take one of these output files and
produce a file in the same format as an export from the Logic GUI
(converts ticks to seconds and outputs pin 0..pin 7), writing to
stdout.  You run it as:

python convert.py inputFile

If no inputFile is provided, it reads from stdin.


Build notes

- This uses the C++ standard library thread/mutex from C++11, so you
  need to have g++ reasonably up-to-date.
- If you're building on a 32-bit system, you need to modify the
  Makefile to link against Saleae's 32-bit lib (not the 64-bit one).
- When running the logic-cli binary, Saleae's lib needs to be in the
  normal shared object lookup paths (/usr/lib, etc) or the binary and
  the lib and bin directories need to move with each other so it can
  be found at runtime.
- You will need libSaleaeDevice.so or libSaleaDevice64.so (depending
  on your architecture), which can be obtained from Saleae's web site
  under the developer tools section. This was last tested with the
  1.1.14 SDK
