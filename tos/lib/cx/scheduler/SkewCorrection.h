#ifndef SKEW_CORRECTION_H
#define SKEW_CORRECTION_H

#ifndef TPF_DECIMAL_PLACES 
#define TPF_DECIMAL_PLACES 16
#endif

//alpha is also fixed point.
#define FP_1 (1L << TPF_DECIMAL_PLACES)

#ifndef SKEW_EWMA_ALPHA_INVERSE
#define SKEW_EWMA_ALPHA_INVERSE 2
#endif

#define sfpMult(a, b) fpMult(a, b, TPF_DECIMAL_PLACES)
#define stoFP(a) toFP(a, TPF_DECIMAL_PLACES)
#define stoInt(a) toInt(a, TPF_DECIMAL_PLACES)

#endif
