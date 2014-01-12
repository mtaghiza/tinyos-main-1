Directory Contents
------------------
ToastSampler.h : define record types and default settings for toast
  sampler.
ToastSamplerC/P : main logic for sampling flow (described below)
DummyToastSampler : replacement code which overrides the ToastSamplerC
  definition and provides something that will periodically log samples
  to the flash. Useful for testing logic when no Toast boards are
  available or to save ROM space.

- Similar timing structure to BaconSampler: sample shortly after boot, then every SS_KEY_TOAST_SAMPLE_INTERVAL (taking care to re-read this at each sample)
- The Bacon maintains a list of attached toast boards, consisting of
  - Toast barcode ID
  - Toast I2C address
  - List of attached sensors
- Each sample interval:
  - Mark any previously-discovered toast boards as UNKNOWN (indicating that they were there in the past, but might have been disconnected since the last sample)
  - Power on the bus
  - Use I2CDiscovery.startDiscovery to identify the toast boards
  - Mark any UNKNOWN toasts as having been re-discovered (PRESENT)
- When I2CDiscovery finishes (discoveryDone event), we iterate through our list of toast boards.
  - If a board is NEW, then we use I2CTLVStorageMaster to read its configuration memory
    - We write this to the log as a toast_connection and scan through it to extract the list of attached sensors, then mark it PRESENT.
  - If a board is still marked UNKNOWN, then it has recently been disconnected. 
    - We mark it ABSENT and we record a toast_disconnection to the log.
  - If a board is PRESENT, then we use I2CADCReaderMaster to send it a command to read its sensors.
    - The logic in nextSampleSensors assembles some conservative settings for reading the toast’s analog sensors.
    - When we get a sampleDone response back from the I2CADCReaderMaster, we compute an approximate timestamp for the sample and record it to the log.
- Once we’ve finished iterating through the toast boards, we turn the bus off.

