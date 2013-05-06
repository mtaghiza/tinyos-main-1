

 #include "SkewCorrection.h"
configuration SkewCorrectionC {
  provides interface SkewCorrection;
} implementation {
  #if CX_USE_FP_SKEW_CORRECTION == 0
  components SimpleSkewCorrectionP as SkewCorrectionP;
  #else
  components FPSkewCorrectionP as SkewCorrectionP;
  #endif

  SkewCorrection = SkewCorrectionP;

  components CXAMAddressC;
  SkewCorrectionP.ActiveMessageAddress -> CXAMAddressC;
}
