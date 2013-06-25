This directory includes the mote-side base station code and python
hooks for interacting with the network.

The lpp package contains LppMoteIF, which extends the stock MoteIF
class. It adds functionality to wakeup/sleep the network and provides
a blocking readFrom(node) function.  

The autopush package contains hooks for log data packets and inserts
them into a local sqlite database.

CXoalaDB.py (and basestation.sh) use Lpp + autoPush to periodically
wake up the network, download outstanding data, and recover missing
packets.
