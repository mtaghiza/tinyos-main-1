#ifndef INTERNAL_FLASH_H
#define INTERNAL_FLASH_H

#warning "using cc430 internal flash"

//Values taken from CC430F5137 datasheet, Table 3
#define IFLASH_A_START (void*)0x1980
#define IFLASH_A_END   (void*)0x19ff
#define IFLASH_B_START (void*)0x1900
#define IFLASH_B_END   (void*)0x197f
#define IFLASH_C_START (void*)0x1880
#define IFLASH_C_END   (void*)0x18ff
#define IFLASH_D_START (void*)0x1800
#define IFLASH_D_END   (void*)0x187f

#define IFLASH_SEGMENT_SIZE   128

#endif

