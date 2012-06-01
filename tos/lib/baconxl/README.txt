Replacement linker scripts to fake a larger ROM size. 

Include these by building with the baconxl extra (e.g. make bacon2 baconxl).

Note that binaries built with these scripts *will not* work: the ROM
section's start address is invalid. This is because the interrupt
vectors are at a higher address than ROM, so we can't increase the
size of the ROM section without overrunning into vectors. 
