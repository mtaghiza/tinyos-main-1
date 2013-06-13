#ifndef __STORAGE_VOLUME_H__
#define __STORAGE_VOLUME_H__

#include "Stm25p.h"

#define VOLUME_TEST 0

static const stm25p_volume_info_t STM25P_VMAP[ 1 ] = {
    {
		base : 0, // starting sector number
		size : 2  // number of sectors in volume
	},
};

#define NUM_VOLUMES 1

#endif
