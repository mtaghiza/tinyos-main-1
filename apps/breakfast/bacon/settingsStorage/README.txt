Interfaces and components for use with internal flash key-value pair.
This uses the TLV standard defined by TI and implemented in
tos/chips/msp430/tlvStorage. 

SettingsStorageP will write a copy of the TLV out to the external
flash when the node boots and every time that the TLV is modified. The
TLV is 128 bytes long, so this is broken into two segments (so that
each record fits into a single packet). 

The included Makefile here will generate the python bindings for the
messages used by SettingsStorageConfigurator*. They should be copied
into the tools.cx.messages package under apps/breakfast/tools/Life. 

Including the dummy directory in the build path will give you a
SettingsStorageC that returns EINVAL to every get command and acts as
if every set/clear is taking place (but does nothing).
