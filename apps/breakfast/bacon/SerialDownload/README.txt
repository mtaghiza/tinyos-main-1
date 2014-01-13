This is a rough draft of a serial-only download application.

If you configure PYTHONPATH to point to the main CX/breakfast python
module root (apps/breakfast/tools/Life), then dump.py will request
data in 50K blocks from the connected node and load them into
database0.sqlite.

It uses the standard RecordPushRequestC component, but wires it to the
Serial AM stack instead of the radio AM stack. 

The python application requests 50K from address 0, then issues a new
request every 2 seconds starting at the last-retrieved nextCookie
value.  RecordPushRequestP ignores new requests while it's busy, so
this shouldn't hurt anything. When it sees no change in the nextCookie
value, it assumes it has reached the end of the log and stops.
