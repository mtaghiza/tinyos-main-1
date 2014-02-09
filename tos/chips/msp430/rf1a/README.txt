This directory contains the drivers for the RF1A radio module on the
CC430.

See the fec and physical subdirectories for more detailed
implementation notes on these elements.

Non-CX notes
-------------
Your platform's ActiveMessageC should wire through the relevant
interfaces provided by Rf1aActiveMessageC. 

Note that the DelayedSend interface is provided by Rf1ActiveMessageC component,
and DelayedAMSenderC's expose this to your application. This enables
precision-timed packet transmissions.

Rf1aPhysicalC checks RF1A_FEC_ENABLED to optionally wire in a
forward-error-correction layer above the actual radio driver.

CX Notes
--------
The CX stack more-or-less ignores everything other than the fec and
physical directories in here. 
