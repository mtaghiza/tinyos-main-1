#ifndef CX_LINK_H
#define CX_LINK_H

//32k = 2**15
#define FRAMELEN_32K 1024
//6.5M = 2**5 * 5**16 * 13
#define FRAMELEN_6_5M 203125
//divide both by 2**5, this is what you get.
//1024 32k ticks = 0.03125 s
//n.b. it seems like mspgcc is smart enough to see /1024 and translate
//it to >> 10. so, it's fine to divide by this defined constant.


#endif
