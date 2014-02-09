The major changes from tinyos-main are:

- x2xxx and x5xxx cross-internal flash implementations
- x2xxx and x5xxx USCI module implementations
- Internal pull-up and pull-down resistor support (at least, on the
  CC430)
- CC430 radio drivers (originally from Osian/People Power)
- Add 32-bit microsecond timer and 32khz virtualized timer.

Active Code
----------
x2xxx: internal flash support, targeted to the msp430f235.
usci_gen1: Support for "generation 1" usci modules (again, targeted to
  msp430f235)
tlvStorage: Cross-platform support for TI's Tag-Length-Value
  configuration structures. 
msp430xv2: Support for clock, timer, internal flash, and low-power
  mode entry, targeted to the cc430.
rf1a: CC1101 radio core support for CC430
timer: added 32-bit microsecond timer and 32khz virtualized timer,
  backwards compatibility for chips lacking BSCTL3 (used for setting
  internal capacitors for 32K oscillator). 
