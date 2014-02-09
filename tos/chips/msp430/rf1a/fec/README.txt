The FEC layer sits above Rf1aPhysical and hides the details of
encoding/decoding packets from upper layers.

Rf1aFECC: wiring for FEC layer. Define RF1A_FEC_ENABLED to 1 in order
to use Hamming(7,4) forward error correction. If you wish to implement
a different form of forward error correction, you would modify this
component to wire to that, rather than to Hamming74FECC.

Rf1aFECP: Decode packets as they are received, and encode them as they
  are transmitted. Implement a secondary CRC check to supercede the
  hardware-provided CRC. 

Hamming74FECC: lookup-table implementation of Hamming(7,4) forward
error correction scheme.  Encoding and decoding tables can be found in
hamming74.h . These tables occupy 272 const bytes.

A few items to note:
- The hardware CRC module operates on 16-bit units. A padding byte
  of 0x00 will automatically be inserted at the end of the end of the
  unencoded data if an odd number of bytes are provided.
- This fully supports the Rf1aTransmitFragment interface. Providers of
  the Rf1aTransmitFragment interface will indicate how much data is
  currently available for transmission and provide a pointer to the
  buffer containing the tx data.
