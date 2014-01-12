This application is used to read/write to bacon and toast TLV storage
through the Labeler utility (apps/breakfast/tools/Life/Labeler*.py). 

The different types of control messages sent back and forth are
defined in ctrl_messages.h

genStubs.sh, genExternalWiring.sh, and genUsedInterfaces.sh are used
to read ctrl_messages.h and generate boilerplate code for adding new
commands and responses.  This can be pasted into the relevant handler
configuration (for wiring) and module (for stubs and used interfaces).

The mig classes (generated with a make bacon2 migClasses) should be
placed under the tools.mig package of apps/breakfast/tools/Life. 

Generally speaking, the different message handlers have been grouped
by function under the handlers directory.

If you add or change any control messages, please update
breakfast/README.txt accordingly.
