Active Code (changes from tinyos-main)
----------
- mcp9700  : Platform-independent wiring for MCP9700 Thermistor
- apds9007 : Platform-independent code for APDS 9007 photodiode
- cc430    : CRC and watchdog module drivers
- msp430
  - adc12: Bug fixes for REF module and ADC12 module (for
    MSP430F235), merges from Osian repo for CC430 support.
  - msp430xv2: MSP430x5xx drivers, mainly focused on CC430
    support. The USCI module is significantly different from the f1611
    (telos) driver structure, and the clock system configuration is also
    pretty different.
  - pins: Add support for pull-up/pull-down enabled pins.
  - rf1a: Support for CC430's radio core.
  - usci_gen1: Support for x2xxx USCI modules. This follows the same
    structure as the x5xx drivers as much as possible.
  - x2xxx: Internal flash support (targeted to the f235 chip).
- stm25p: optimizations for the case where there is a single flash
  volume, parameterize automatic power-down timeout.

Unused/Obsolete code
-----------
- Ds1825 : Drivers for DS-1825 thermistor (using Onewire
  communication)
- cc1190   : Platform-independent code for CC1190 PA/LNA.  This
  structure has been replaced by the AmpControlC component under
  msp430/rf1a/physical.
  Rf1aC puts an AmpControlC instance on top of the HplMsp430Rf1aC
  instance that provides Rf1aPhysical.  The default version of
  AmpControlC provides pass-through wiring and is optimized out by the
  compiler. Under apps/breakfast/bacon/Router, AmpControlC is
  overridden with a version that turns on and off the CC1190 as needed
  and sets it into RX and TX mode when appropriate. 
