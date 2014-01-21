Active code
----------
bacon2.target: build target for latest revision of bacon mote + USB
  adapter hardware. Uses the bin/flexible-tos-storage-stm25p tool to
  define the log storage volumes.
baconxl.extra: build target that uses a linker script specifying a
  (fake) larger ROM space. Used in conjunction with the
  bin/module_memory_usage and bin/mem_vis scripts for looking at where
  ROM is being used.
toast.target: build target for toast board. This includes the
  additional steps necessary for linking in the BSLSKEY protection
  (which prevents accidental erasure when BSL password check fails).
wpt.extra: build target for loading a binary onto the testbed. If you
  opt to build your testbed in such a way (see
  TOSROOT/apps/breakfast/Sensorbed), then you will need to replace
  sensorbed.hinrg.cs.jhu.edu with the name of the central testbed
  server.

Obsolete/test code
--------
bacon.target: build targets for original revision of bacon mote. This
  was written for the original USB adapter design (did not include
  ADG715 switch and was less reliable).

em430.target: target for TI's cc430 evaluation module. I don't believe
  that the physical connection from the FT232 to the em board is
  documented anywhere, so this is kind of useless without it.
