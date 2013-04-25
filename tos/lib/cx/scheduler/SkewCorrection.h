#ifndef SKEW_CORRECTION_H
#define SKEW_CORRECTION_H

#ifndef TPF_DECIMAL_PLACES 
#define TPF_DECIMAL_PLACES 16L
#endif

//alpha is also fixed point.
#define FP_1 (1L << TPF_DECIMAL_PLACES)

#ifndef SKEW_EWMA_ALPHA_INVERSE
#define SKEW_EWMA_ALPHA_INVERSE 2
#endif

#define sfpMult(a, b) fpMult(a, b, TPF_DECIMAL_PLACES)
#define stoFP(a) toFP(a, TPF_DECIMAL_PLACES)
#define stoInt(a) toInt(a, TPF_DECIMAL_PLACES)

//50 ppm error over a 1024-tick frame ~= 0.05 ticks per frame
//MAX_VALID_TPF is ~0.0507
#define MAX_VALID_TPF ((FP_1 >> 5) + (FP_1 >> 6) + (FP_1 >> 8))

#endif
