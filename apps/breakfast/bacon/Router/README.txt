RouterAppC wires the send interface of a RecordPushRequestC instance
to a RouterAMSender instance (rather than a SubNetworkAMSender
instance). 

RouterP wraps log record packets it receives (e.g. from leaf nodes) in
a tunneled message log entry and appends them to its log storage.
The existing recovery logic described in the Auto-push documentation
is applied to forward this on to the base station.

Immediately following a basestation download, it starts a download
from its subnetwork.

AmpControl* and CC1190PinsC.nc override the default (pass-through)
wiring in the radio stack (under tos/chips/msp430/rf1a/physical) in
order to turn the radio amplifier on and off and set it into the
correct (rx or tx) mode as needed.
