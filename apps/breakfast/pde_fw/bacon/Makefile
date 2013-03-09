SOURCES=dco_div.c LPM4_bacon2.c LPM4.c LPM4_switched_flash_on.c LPM4_photo_bacon2.c busy.c cc430x513x_UCS_4.c busy_bacon2.c LPM4_flash_active_bacon2.c LPM4_flash_on_bacon2.c LPM4_LED.c
CC=msp430-gcc
CCFLAGS=-mmcu=cc430x5137
OBJCOPY=msp430-objcopy
ODIR=bin
EXES=$(SOURCES:.c=.bin)
EXES_=$(patsubst %,$(ODIR)/%,$(EXES))
HEXES=$(SOURCES:.c=.hex)
HEXES_=$(patsubst %,$(ODIR)/%,$(HEXES))

all: $(ODIR) $(HEXES_) $(EXES_)

$(ODIR):
	mkdir -p $(ODIR)

$(ODIR)/%.hex: $(ODIR)/%.bin
	$(OBJCOPY) -I elf32-msp430 -O ihex $< $@

$(ODIR)/%.bin: %.c 
	$(CC) $(CCFLAGS) $(CFLAGS) $< -o $@ 

clean:
	rm -rf $(ODIR)

