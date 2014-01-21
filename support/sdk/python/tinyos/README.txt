This contains a python-only implementation of the serial AM
communication protocol. It begain with Geoffrey Mainland's
implementation, which has been significantly modified in a few ways.

1. Fixes/completion: properly escape CRC's, handle acknowledgements,
   block on source __init__ until the source is ready to be used, etc.
2. Threading and queuing support: packet receptions are handled by a
   thread which continuously reads bytes off the serial port and puts
   packets into a queue as they are assembled. This prevents (some)
   issues related to packet drops when a system is heavily loaded.

This works *pretty* well, but it appears that one can still drop
packets due to the way that python handles threading support. An
experimental serial-mp branch is present in Doug's tinyos-main github
repository (github.com/carlsondc/tinyos-main) which uses python's
multiprocessing module (rather than threading) to mitigate this
problem somewhat, though it is not mature yet.
