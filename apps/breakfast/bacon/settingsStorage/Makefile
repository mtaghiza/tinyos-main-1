#Would be really nice if I could figure out how to *just* do the mig
# files...
COMPONENT = DummyC

MIGDIR=mig
MIGCLASSFILES = $(MIGDIR)/SetSettingsStorageMsg.py \
$(MIGDIR)/GetSettingsStorageCmdMsg.py \
$(MIGDIR)/GetSettingsStorageResponseMsg.py \
$(MIGDIR)/ClearSettingsStorageMsg.py

$(MIGDIR):
	mkdir -p $(MIGDIR)

$(MIGDIR)/%.py: $(MIGDIR) SettingsStorage.h
	genMig.sh $(PLATFORM) SettingsStorage.h $@ $(CFLAGS)

migClassFiles: $(MIGCLASSFILES) 

include $(MAKERULES)
