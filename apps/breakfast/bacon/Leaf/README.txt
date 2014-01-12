This is the main Leaf application for the bacon mote. It wires the
sub-applications for periodic toast and bacon sampling, phoenix
measurements, and handling data transmission/recovery.

The ENABLE_XXX flags in Makefile can be used to turn on and off
specific features. The default settings are field-deployable.

ENABLE_SETTINGS_CONFIG_FULL defaults to 0: this only enables the Set
command receiver (as it is the only one we use in the field). Defining
this to 1 also enables Get and Clear.

ENABLE_SETTINGS_LOGGING is used to control whether or not the mote
logs its settings to external flash at every reboot and settings
change. Settings storage is otherwise not affected by this option.

MAX_POWER is used to define the radio output power from the mote: see the
Makefile for settings.

In order to save space, we use one of the CC430's USCI modules for SPI
communication and the other for I2C: this is accomplished by 
including versions of the USCI drivers under the platform directory.
If you wish to use printf, then you need to build with Makefile.printf
(which does allow USCI module sharing by the different protocols).
