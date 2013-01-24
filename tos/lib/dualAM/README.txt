This library provides an AM stack which allows applications to read/write
both radio and serial active messages through single calls. This can
be used, for instance, when developing applications that can either be
run on a mote directly connected to a PC (communication over serial AM
stack) or on remote devices (communication from PC to radio via
standard TinyOS BaseStation, which forwards to/from remote device).

This uses the tos/lib/serial library, which relies on the existence of
a PlatformSerialC.
